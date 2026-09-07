import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/constants/game_constants.dart';
import '../data/best_score_store.dart';
import '../domain/models/block_cell.dart';
import '../domain/models/block_piece.dart';
import '../domain/models/game_board.dart';
import '../domain/models/game_effect.dart';
import '../domain/models/line_clear_result.dart';
import '../domain/models/placement_result.dart';
import '../domain/models/turn_result.dart';
import 'drag_session.dart';
import 'piece_generator.dart';
import 'score_system.dart';

/// Owns the state of a single game session and every mutation of it.
///
/// The widget layer never touches [GameBoard] directly: it reports pointer
/// activity through [startDrag] / [updateDrag] / [endDrag] and renders
/// whatever comes back. Scoring, line clearing and the combo streak are all
/// resolved here, in [endDrag].
class GameController extends ChangeNotifier {
  GameController({
    BestScoreStore? bestScoreStore,
    PieceGenerator? generator,
    int bestScore = 0,
  }) : _store = bestScoreStore ?? InMemoryBestScoreStore(bestScore),
       _generator = generator ?? PieceGenerator(),
       _board = GameBoard.empty(),
       _tray = const <BlockPiece?>[],
       _score = 0,
       _bestScore = bestScore,
       _combo = 0 {
    _tray = _generator.generateTray(_board, _score);
  }

  /// Builds a controller around a prepared board and tray.
  ///
  /// Production code always uses the default constructor; this exists so
  /// tests can set up a board position without having to play towards it.
  @visibleForTesting
  GameController.withState({
    required GameBoard board,
    required List<BlockPiece?> tray,
    BestScoreStore? bestScoreStore,
    PieceGenerator? generator,
    int bestScore = 0,
    int score = 0,
    int combo = 0,
    bool isGameOver = false,
  }) : _store = bestScoreStore ?? InMemoryBestScoreStore(bestScore),
       _generator = generator ?? PieceGenerator(),
       _board = board,
       _tray = List<BlockPiece?>.of(tray),
       _score = score,
       _bestScore = bestScore,
       _combo = combo,
       _isGameOver = isGameOver;

  final BestScoreStore _store;
  final PieceGenerator _generator;

  GameBoard _board;
  List<BlockPiece?> _tray;
  int _score;
  int _bestScore;
  int _combo;
  DragSession? _drag;
  TurnResult? _lastTurn;
  bool _isGameOver = false;

  final StreamController<GameEffect> _effects =
      StreamController<GameEffect>.broadcast();
  int _nextEffectId = 1;

  // Drag updates arrive at the display's refresh rate. Broadcasting all of
  // them through notifyListeners() would rebuild the header, the tray and all
  // 64 board cells on every frame, so the two things that actually change
  // during a drag get their own fine-grained notifiers and the general
  // listener is left alone.
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);
  final ValueNotifier<int> _previewRevision = ValueNotifier<int>(0);

  GameBoard get board => _board;

  /// Tray slots; a `null` entry is a slot whose piece has been played.
  ///
  /// The list always has [GameConstants.traySlotCount] entries so the tray
  /// layout never shifts.
  List<BlockPiece?> get tray => List<BlockPiece?>.unmodifiable(_tray);

  int get score => _score;
  int get bestScore => _bestScore;

  /// Current clear streak; `0` when the last placement cleared nothing.
  int get combo => _combo;

  /// What the most recent successful placement was worth, or `null` before
  /// the first one.
  TurnResult? get lastTurn => _lastTurn;

  DragSession? get drag => _drag;
  bool get isDragging => _drag != null;

  /// One-shot presentation events: sounds, particles, pops.
  ///
  /// A broadcast stream rather than state, so a rebuild cannot replay an
  /// effect. Every event carries a unique increasing id.
  Stream<GameEffect> get effects => _effects.stream;

  /// The live pointer position while a block is being dragged, `null`
  /// otherwise.
  ///
  /// Fires on every pointer move. Only the floating block listens to it, so a
  /// move repaints one layer instead of rebuilding the screen.
  ValueListenable<Offset?> get pointerPosition => _pointer;

  /// Bumped whenever the previewed cells or their validity change — which is
  /// far rarer than pointer movement, since a finger crosses many pixels per
  /// cell. The board listens to this instead of to every move.
  ValueListenable<int> get previewRevision => _previewRevision;

  /// No piece left in the tray fits anywhere on the board.
  bool get isGameOver => _isGameOver;

  /// Whether any piece still in the tray has somewhere to go.
  bool hasAnyMove() => _board.hasAnyMove(_tray);

  /// Cells the drag preview should highlight, empty when nothing is previewed.
  List<BlockCell> get previewCells => _drag?.placement?.cells ?? const [];

  /// Whether the current preview is a legal drop.
  bool get previewIsValid => _drag?.canDrop ?? false;

  // --- Persistence --------------------------------------------------------

  /// Restores the stored best score. A stored value never lowers the score
  /// already reached this session.
  Future<void> loadBestScore() async {
    final int stored = await _store.load();
    if (stored > _bestScore) {
      _bestScore = stored;
      notifyListeners();
    }
  }

  // --- Drag lifecycle -----------------------------------------------------

  /// Lifts the piece in [slotIndex] out of the tray. Returns `false` if the
  /// slot is empty or a drag is already running.
  bool startDrag(int slotIndex, Offset pointer) {
    if (_isGameOver) return false;
    if (_drag != null) return false;
    if (slotIndex < 0 || slotIndex >= _tray.length) return false;
    final BlockPiece? piece = _tray[slotIndex];
    if (piece == null) return false;

    _drag = DragSession(slotIndex: slotIndex, piece: piece, pointer: pointer);
    _pointer.value = pointer;
    _previewRevision.value++;
    _emit(GameEffectType.dragStarted, color: piece.color);
    notifyListeners();
    return true;
  }

  /// Moves the dragged piece. [anchor] is the board cell the piece's top-left
  /// currently snaps to, or `null` when the piece is not over the board — the
  /// widget layer computes it from the live board geometry.
  void updateDrag(Offset pointer, {BlockCell? anchor}) {
    final DragSession? current = _drag;
    if (current == null) return;

    final bool anchorChanged = anchor != current.anchor;
    if (!anchorChanged && pointer == current.pointer) return;

    if (anchorChanged) {
      // Placement is only re-evaluated when the block actually snaps to a
      // different cell. Sliding a finger within one cell — most frames of a
      // real drag — costs nothing but an offset update.
      final PlacementResult? placement = anchor == null
          ? null
          : _board.evaluate(current.piece, anchor.row, anchor.column);

      _drag = anchor == null
          ? current.copyWith(pointer: pointer, clearAnchor: true)
          : current.copyWith(
              pointer: pointer,
              anchor: anchor,
              placement: placement,
            );
      _previewRevision.value++;
    } else {
      _drag = current.copyWith(pointer: pointer);
    }

    // Deliberately not notifyListeners(): the block follows [pointerPosition]
    // and the board follows [previewRevision], so nothing else has to wake up.
    _pointer.value = pointer;
  }

  /// Releases the piece. Commits it to the board when the preview is valid,
  /// otherwise leaves the board untouched and returns the piece to its slot.
  ///
  /// Returns `true` when the piece was placed.
  bool endDrag() {
    final DragSession? current = _drag;
    if (current == null) return false;

    final BlockCell? anchor = current.anchor;
    if (!current.canDrop || anchor == null) {
      // Invalid release: nothing changes, not even the combo streak.
      _drag = null;
      _endDragNotifiers();
      _emit(GameEffectType.invalid, color: current.piece.color);
      notifyListeners();
      return false;
    }

    _resolveTurn(current.piece, anchor);
    _tray = List<BlockPiece?>.of(_tray)..[current.slotIndex] = null;
    _drag = null;
    _endDragNotifiers();

    // Refill only once the whole tray is spent, then judge the new tray
    // against the board the placement left behind.
    _refillTrayIfSpent();
    final bool wasGameOver = _isGameOver;
    _isGameOver = !hasAnyMove();

    _emitTurnEffects(current.piece, wasGameOver: wasGameOver);

    notifyListeners();
    return true;
  }

  /// Announces what the just-resolved turn should look and sound like.
  ///
  /// Ordering is fixed — placed, then cleared, then combo, then game over —
  /// so presentation never has to guess, and every event fires at most once
  /// per placement.
  void _emitTurnEffects(BlockPiece piece, {required bool wasGameOver}) {
    final TurnResult turn = _lastTurn!;

    _emit(
      GameEffectType.placed,
      cells: turn.placedCells,
      scoreGained: turn.scoreGained,
      combo: turn.combo,
      color: piece.color,
    );

    if (turn.clearedLineCount > 0) {
      _emit(
        GameEffectType.cleared,
        cells: turn.clearedCells.toList(growable: false),
        lineCount: turn.clearedLineCount,
        combo: turn.combo,
        scoreGained: turn.scoreGained,
        color: piece.color,
      );
      if (turn.combo >= 2) {
        _emit(
          GameEffectType.combo,
          lineCount: turn.clearedLineCount,
          combo: turn.combo,
          scoreGained: turn.scoreGained,
          color: piece.color,
        );
      }
    }

    // Only on the transition, so a repeated evaluation cannot fire it twice.
    if (_isGameOver && !wasGameOver) {
      _emit(GameEffectType.gameOver, combo: turn.combo);
    }
  }

  /// Deals a fresh trio when — and only when — all three slots are empty.
  ///
  /// Dealing is not a turn: it never touches the board, the score, BEST or
  /// the combo streak.
  void _refillTrayIfSpent() {
    if (_tray.any((BlockPiece? piece) => piece != null)) return;
    _tray = _generator.generateTray(_board, _score);
  }

  /// Writes the block in, clears whatever it completed, and scores the turn.
  void _resolveTurn(BlockPiece piece, BlockCell anchor) {
    final List<BlockCell> placed = _board.cellsFor(
      piece,
      anchor.row,
      anchor.column,
    );

    // Detect on the board *with* the block already in it, then clear every
    // completed line in one pass so intersections are only emptied once.
    final GameBoard filled = _board.placePiece(
      piece,
      anchor.row,
      anchor.column,
    );
    final LineClearResult clear = filled.findFullLines();
    _board = filled.clearLines(clear);

    _combo = ScoreSystem.nextCombo(_combo, clear.lineCount);
    final TurnResult turn = TurnResult(
      placedCells: placed,
      clear: clear,
      placementScore: ScoreSystem.placementScore(placed.length),
      lineClearBonus: ScoreSystem.lineClearBonus(clear.lineCount),
      comboBonus: ScoreSystem.comboBonus(_combo),
      combo: _combo,
    );

    _lastTurn = turn;
    _score += turn.scoreGained;
    _updateBestScore();
  }

  void _updateBestScore() {
    if (_score <= _bestScore) return;
    _bestScore = _score;
    // Fire and forget: a failed write must never break the game loop.
    _store.save(_bestScore);
  }

  void _emit(
    GameEffectType type, {
    List<BlockCell> cells = const <BlockCell>[],
    int lineCount = 0,
    int combo = 0,
    int scoreGained = 0,
    Color? color,
  }) {
    if (_effects.isClosed) return;
    _effects.add(
      GameEffect(
        id: _nextEffectId++,
        type: type,
        cells: cells,
        lineCount: lineCount,
        combo: combo,
        scoreGained: scoreGained,
        color: color,
      ),
    );
  }

  @override
  void dispose() {
    _effects.close();
    _pointer.dispose();
    _previewRevision.dispose();
    super.dispose();
  }

  /// Aborts the drag without touching the board (pointer cancelled).
  void cancelDrag() {
    if (_drag == null) return;
    _drag = null;
    _endDragNotifiers();
    notifyListeners();
  }

  /// Puts the drag notifiers back to rest so the block layer clears itself and
  /// the board drops its preview.
  void _endDragNotifiers() {
    _pointer.value = null;
    _previewRevision.value++;
  }

  // --- Session ------------------------------------------------------------

  /// Starts a new round: empty board, fresh tray, score and combo back to
  /// zero. The best score — in memory and on disk — survives.
  void reset() {
    _board = GameBoard.empty();
    _score = 0;
    _combo = 0;
    _drag = null;
    _endDragNotifiers();
    _lastTurn = null;
    _isGameOver = false;
    _tray = _generator.generateTray(_board, _score);
    notifyListeners();
  }
}
