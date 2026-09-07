import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/haptics/game_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/best_score_store.dart';
import '../../domain/models/block_cell.dart';
import '../../domain/models/block_piece.dart';
import '../../domain/models/game_effect.dart';
import '../../logic/board_geometry.dart';
import '../../logic/drag_session.dart';
import '../../logic/effect_dispatcher.dart';
import '../../logic/game_controller.dart';
import '../../logic/game_settings.dart';
import '../widgets/block_tray.dart';
import '../widgets/combo_badge.dart';
import '../widgets/drag_ghost.dart';
import '../widgets/effects/clear_burst.dart';
import '../widgets/effects/place_pulse.dart';
import '../widgets/effects/return_ghost.dart';
import '../widgets/effects/score_pop.dart';
import '../widgets/game_board_view.dart';
import '../widgets/game_header.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/settings_button.dart';
import '../widgets/settings_sheet.dart';

/// The main screen of Hi Hi Block.
///
/// Two responsibilities live here and nowhere else: translating pointer
/// positions into board anchors (only this layer knows where the board sits on
/// screen), and turning the controller's one-shot [GameEffect]s into sound,
/// haptics and short-lived overlays.
///
/// Presentation never feeds back into the game: the controller has already
/// finished the turn by the time an effect arrives, so a dropped frame or a
/// disposed animation cannot corrupt the board, the score or the streak.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.controller,
    this.settings,
    this.audio,
    this.haptics,
  });

  /// Injected session state. When `null` the screen owns a fresh
  /// [GameController] backed by shared preferences; an injected one is owned
  /// by the caller and is not disposed here.
  final GameController? controller;

  /// Injected settings. When `null` the screen owns its own.
  final GameSettings? settings;

  /// Sound output; defaults to silence so tests make no noise.
  final GameAudio? audio;

  /// Haptic output; defaults to silence so tests do not buzz.
  final GameHaptics? haptics;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller =
      widget.controller ??
      GameController(bestScoreStore: const SharedPreferencesBestScoreStore());

  late final GameSettings _settings = widget.settings ?? GameSettings();

  late final EffectDispatcher _dispatcher = EffectDispatcher(
    audio: widget.audio ?? const SilentGameAudio(),
    haptics: widget.haptics ?? const SilentGameHaptics(),
    settings: _settings,
  );

  /// Subscribed once, in [initState] — a rebuild can never replay an effect.
  StreamSubscription<GameEffect>? _effectSubscription;

  /// Attached to the square board container, for global -> board mapping.
  final GlobalKey _boardKey = GlobalKey();

  /// Attached to the drag layer, for global -> overlay mapping.
  final GlobalKey _stackKey = GlobalKey();

  /// Attached to the tray, so a rejected block knows where to fly back to.
  final GlobalKey _trayKey = GlobalKey();

  /// Transient overlays, each of which takes itself away when it finishes.
  final List<_ActiveEffect> _overlays = <_ActiveEffect>[];

  @override
  void initState() {
    super.initState();
    // Best score and settings are restored asynchronously; the UI updates
    // when they land.
    _controller.loadBestScore();
    if (widget.settings == null) _settings.load();
    _effectSubscription = _controller.effects.listen(_onEffect);
  }

  @override
  void dispose() {
    _effectSubscription?.cancel();
    if (widget.settings == null) _settings.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  // --- Geometry -----------------------------------------------------------

  RenderBox? _boxOf(GlobalKey key) {
    final RenderObject? object = key.currentContext?.findRenderObject();
    return object is RenderBox && object.hasSize ? object : null;
  }

  RenderBox? get _boardBox => _boxOf(_boardKey);
  RenderBox? get _stackBox => _boxOf(_stackKey);

  /// Board geometry derived from the board's real on-screen size, so the
  /// mapping stays correct at any screen width.
  BoardGeometry? get _geometry {
    final RenderBox? box = _boardBox;
    return box == null ? null : BoardGeometry(side: box.size.width);
  }

  /// Top-left of the board, in overlay coordinates.
  Offset? get _boardOrigin {
    final RenderBox? board = _boardBox;
    final RenderBox? stack = _stackBox;
    if (board == null || stack == null) return null;
    return stack.globalToLocal(board.localToGlobal(Offset.zero));
  }

  /// Global position of the dragged block's top-left corner.
  ///
  /// The block is centred on a point [GameConstants.dragLift] above the
  /// pointer, so a finger never covers the preview it is meant to reveal.
  Offset _ghostTopLeft(BlockPiece piece, Offset pointer, BoardGeometry geo) {
    final Size span = geo.sizeOfSpan(piece.rowCount, piece.columnCount);
    return pointer -
        Offset(span.width / 2, span.height / 2 + GameConstants.dragLift);
  }

  /// Board anchor for the current pointer, or `null` when the block is not
  /// over the board at all.
  BlockCell? _anchorFor(BlockPiece piece, Offset pointer) {
    final RenderBox? box = _boardBox;
    final BoardGeometry? geo = _geometry;
    if (box == null || geo == null) return null;

    final Size span = geo.sizeOfSpan(piece.rowCount, piece.columnCount);
    final Offset localTopLeft = box.globalToLocal(
      _ghostTopLeft(piece, pointer, geo),
    );

    // No preview at all until the block actually overlaps the grid.
    final Rect grid = Rect.fromLTWH(
      geo.padding,
      geo.padding,
      box.size.width - 2 * geo.padding,
      box.size.height - 2 * geo.padding,
    );
    if (!(localTopLeft & span).overlaps(grid)) return null;

    return geo.anchorFor(localTopLeft);
  }

  /// Centre of tray slot [slotIndex], in overlay coordinates.
  Offset? _traySlotCentre(int slotIndex) {
    final RenderBox? tray = _boxOf(_trayKey);
    final RenderBox? stack = _stackBox;
    if (tray == null || stack == null) return null;

    final Offset topLeft = stack.globalToLocal(tray.localToGlobal(Offset.zero));
    // The tray lays its slots out as equal shares inside a fixed padding.
    const double padding = 8;
    final double slotWidth =
        (tray.size.width - 2 * padding) / GameConstants.traySlotCount;
    return topLeft +
        Offset(padding + slotWidth * (slotIndex + 0.5), tray.size.height / 2);
  }

  // --- Pointer handling ---------------------------------------------------

  void _onSlotDragStart(int slotIndex, Offset globalPosition) {
    if (!_controller.startDrag(slotIndex, globalPosition)) return;
    final BlockPiece? piece = _controller.drag?.piece;
    if (piece == null) return;
    _controller.updateDrag(
      globalPosition,
      anchor: _anchorFor(piece, globalPosition),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final DragSession? drag = _controller.drag;
    if (drag == null) return;
    _controller.updateDrag(
      event.position,
      anchor: _anchorFor(drag.piece, event.position),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    // Capture where the block was before the controller drops the session, so
    // a rejected block can fly home from exactly where it was let go.
    final DragSession? drag = _controller.drag;
    final BoardGeometry? geo = _geometry;
    final RenderBox? stack = _stackBox;
    Offset? releasedAt;
    if (drag != null && geo != null && stack != null) {
      releasedAt = stack.globalToLocal(
        _ghostTopLeft(drag.piece, drag.pointer, geo),
      );
    }

    // An invalid release simply ends the drag: the board is untouched and the
    // piece stays in its tray slot.
    final bool placed = _controller.endDrag();
    if (!placed && drag != null && releasedAt != null && geo != null) {
      _startReturnGhost(drag, releasedAt, geo);
    }
  }

  // --- Effects ------------------------------------------------------------

  void _onEffect(GameEffect effect) {
    _dispatcher.dispatch(effect);
    if (!mounted) return;

    switch (effect.type) {
      case GameEffectType.placed:
        _startPlacePulse(effect);
        _startScorePop(effect);
      case GameEffectType.cleared:
        _startClearBurst(effect);
      case GameEffectType.dragStarted:
      case GameEffectType.invalid:
      case GameEffectType.combo:
      case GameEffectType.gameOver:
        // Sound, haptics, the combo badge and the overlay cover these; the
        // rejected block is animated from the pointer handler, the only place
        // that knows where it was let go.
        break;
    }
  }

  void _add(_ActiveEffect overlay) => setState(() => _overlays.add(overlay));

  /// Takes a finished overlay away, so no animation widget outlives its
  /// effect.
  void _remove(Object token) {
    if (!mounted) return;
    setState(
      () => _overlays.removeWhere((_ActiveEffect e) => e.token == token),
    );
  }

  void _startPlacePulse(GameEffect effect) {
    final BoardGeometry? geo = _geometry;
    final Offset? origin = _boardOrigin;
    if (geo == null || origin == null) return;

    final Object token = Object();
    _add(
      _ActiveEffect(
        token: token,
        child: Positioned(
          left: origin.dx,
          top: origin.dy,
          width: geo.side,
          height: geo.side,
          child: PlacePulse(
            key: ValueKey<int>(effect.id),
            cells: effect.cells,
            geometry: geo,
            color: effect.color ?? AppColors.accent,
            onDone: () => _remove(token),
          ),
        ),
      ),
    );
  }

  void _startClearBurst(GameEffect effect) {
    final BoardGeometry? geo = _geometry;
    final Offset? origin = _boardOrigin;
    if (geo == null || origin == null) return;

    final Object token = Object();
    _add(
      _ActiveEffect(
        token: token,
        child: Positioned(
          left: origin.dx,
          top: origin.dy,
          width: geo.side,
          height: geo.side,
          child: ClearBurst(
            key: ValueKey<int>(effect.id),
            cells: effect.cells,
            geometry: geo,
            color: effect.color ?? AppColors.accent,
            lineCount: effect.lineCount,
            seed: effect.id,
            onDone: () => _remove(token),
          ),
        ),
      ),
    );
  }

  void _startScorePop(GameEffect effect) {
    final BoardGeometry? geo = _geometry;
    final Offset? origin = _boardOrigin;
    if (geo == null || origin == null || effect.scoreGained <= 0) return;

    final Object token = Object();
    _add(
      _ActiveEffect(
        token: token,
        child: Positioned(
          left: origin.dx,
          top: origin.dy + geo.side * 0.62,
          width: geo.side,
          child: Center(
            child: ScorePop(
              key: ValueKey<int>(effect.id),
              amount: effect.scoreGained,
              emphasised: effect.lineCount > 0 || effect.combo >= 2,
              onDone: () => _remove(token),
            ),
          ),
        ),
      ),
    );
  }

  void _startReturnGhost(
    DragSession drag,
    Offset releasedAt,
    BoardGeometry geo,
  ) {
    final Offset? slot = _traySlotCentre(drag.slotIndex);
    if (slot == null) return;

    final double ghostCell = geo.cellSize * GameConstants.dragGhostScale;
    final Size span = geo.sizeOfSpan(
      drag.piece.rowCount,
      drag.piece.columnCount,
    );
    final Object token = Object();

    _add(
      _ActiveEffect(
        token: token,
        child: Positioned(
          left: 0,
          top: 0,
          child: ReturnGhost(
            piece: drag.piece,
            cellSize: ghostCell,
            pitch: geo.pitch,
            from: releasedAt,
            // Aim the block's centre at the slot's centre.
            to: slot - Offset(span.width / 2, span.height / 2),
            onDone: () => _remove(token),
          ),
        ),
      ),
    );
  }

  Future<void> _onSettingsPressed() => SettingsSheet.show(context, _settings);

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.1,
            colors: <Color>[
              AppColors.backgroundTop,
              AppColors.backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Listener(
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (PointerCancelEvent _) => _controller.cancelDrag(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: GameConstants.maxContentWidth,
                ),
                child: Stack(
                  key: _stackKey,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GameConstants.screenHorizontalPadding,
                        vertical: GameConstants.screenVerticalPadding,
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, _) =>
                            _buildContent(context),
                      ),
                    ),
                    // Effect overlays sit above the board but below the drag
                    // layer, and each repaints only its own bounds.
                    ..._overlays.map((_ActiveEffect e) => e.child),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, _) => Stack(
                        children: <Widget>[
                          ..._buildDragLayer(),
                          if (_controller.isGameOver)
                            GameOverOverlay(
                              score: _controller.score,
                              bestScore: _controller.bestScore,
                              onPlayAgain: _controller.reset,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final DragSession? drag = _controller.drag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GameHeader(score: _controller.score, bestScore: _controller.bestScore),
        // The board is vertically centred in whatever space is left between
        // the header and the tray, and never taller than it is wide.
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: RepaintBoundary(
                child: GameBoardView(
                  board: _controller.board,
                  boardKey: _boardKey,
                  previewCells: _controller.previewCells,
                  previewIsValid: _controller.previewIsValid,
                  previewColor: drag?.piece.color,
                ),
              ),
            ),
          ),
        ),
        ComboBadge(combo: _controller.combo),
        const SizedBox(height: GameConstants.stackSpacing),
        RepaintBoundary(
          child: BlockTray(
            key: _trayKey,
            pieces: _controller.tray,
            onSlotDragStart: _onSlotDragStart,
            draggingSlotIndex: drag?.slotIndex,
          ),
        ),
        const SizedBox(height: GameConstants.stackSpacing),
        Align(
          alignment: Alignment.centerRight,
          child: SettingsButton(onPressed: _onSettingsPressed),
        ),
      ],
    );
  }

  List<Widget> _buildDragLayer() {
    final DragSession? drag = _controller.drag;
    final BoardGeometry? geo = _geometry;
    final RenderBox? stack = _stackBox;
    if (drag == null || geo == null || stack == null) return const <Widget>[];

    // The ghost squares are inset inside their cells, so nudge the whole
    // block by half the inset to keep it centred on the preview.
    final double ghostCell = geo.cellSize * GameConstants.dragGhostScale;
    final double inset = (geo.cellSize - ghostCell) / 2;
    final Offset position = stack.globalToLocal(
      _ghostTopLeft(drag.piece, drag.pointer, geo),
    );
    return <Widget>[
      Positioned(
        left: position.dx + inset,
        top: position.dy + inset,
        child: DragGhost(
          piece: drag.piece,
          cellSize: ghostCell,
          pitch: geo.pitch,
          isOverBoard: drag.isOverBoard,
          isValid: drag.canDrop,
        ),
      ),
    ];
  }
}

/// A transient overlay plus the token used to take it away again.
class _ActiveEffect {
  const _ActiveEffect({required this.token, required this.child});

  final Object token;
  final Widget child;
}
