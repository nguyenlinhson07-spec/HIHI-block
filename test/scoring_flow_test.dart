import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/data/best_score_store.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/domain/models/turn_result.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _size = GameConstants.boardSize;

BlockPiece _unit(String id) => BlockPiece(
  id: id,
  cells: const <BlockCell>[BlockCell(0, 0)],
  color: Colors.cyan,
);

BlockPiece _domino(String id) => BlockPiece(
  id: id,
  cells: const <BlockCell>[BlockCell(0, 0), BlockCell(0, 1)],
  color: Colors.pinkAccent,
);

/// A board pre-filled with every listed cell.
GameBoard _boardWith(Iterable<BlockCell> cells) {
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(_unit('seed'), c.row, c.column);
  }
  return board;
}

Iterable<BlockCell> _row(int row, {Set<int> gaps = const <int>{}}) sync* {
  for (int c = 0; c < _size; c++) {
    if (!gaps.contains(c)) yield BlockCell(row, c);
  }
}

Iterable<BlockCell> _column(int column, {Set<int> gaps = const <int>{}}) sync* {
  for (int r = 0; r < _size; r++) {
    if (!gaps.contains(r)) yield BlockCell(r, column);
  }
}

/// A controller on an empty board with the predictable Phase-1 trio:
/// a 2-cell domino, a 3-cell L and a 2x2 square.
GameController _fixedTray({BestScoreStore? store}) =>
    GameController.withState(
      board: GameBoard.empty(),
      tray: BlockShapes.sampleTray(),
      bestScoreStore: store,
    );

/// Plays the piece in [slot] at ([row], [column]) through the real drag API.
bool _drop(GameController c, int slot, int row, int column) {
  c.startDrag(slot, Offset.zero);
  c.updateDrag(Offset.zero, anchor: BlockCell(row, column));
  return c.endDrag();
}

void main() {
  group('scoring a turn', () {
    test('8./18. a placement without a clear scores 10 per cell', () {
      final GameController c = _fixedTray();
      // The domino: 2 cells, nothing completed.
      expect(_drop(c, 0, 0, 0), isTrue);
      expect(c.lastTurn!.placementScore, 20);
      expect(c.lastTurn!.lineClearBonus, 0);
      expect(c.lastTurn!.comboBonus, 0);
      expect(c.lastTurn!.scoreGained, 20);
      expect(c.score, 20);

      // The L shape: 3 cells.
      expect(_drop(c, 1, 4, 4), isTrue);
      expect(c.lastTurn!.scoreGained, 30);
      expect(c.score, 50);

      // The 2x2 square: 4 cells.
      expect(_drop(c, 2, 6, 0), isTrue);
      expect(c.lastTurn!.scoreGained, 40);
      expect(c.score, 90);
      c.dispose();
    });

    test('9./18. completing one row pays 10/cell + 100', () {
      final GameController c = GameController.withState(
        board: _boardWith(_row(3, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit('a')],
      );
      expect(_drop(c, 0, 3, 7), isTrue);

      final TurnResult turn = c.lastTurn!;
      expect(turn.clearedRows, <int>[3]);
      expect(turn.clearedColumns, isEmpty);
      expect(turn.clearedCells.length, _size);
      expect(turn.placedCells, <BlockCell>[const BlockCell(3, 7)]);
      expect(turn.placementScore, 10);
      expect(turn.lineClearBonus, 100);
      expect(turn.scoreGained, 110);
      expect(c.score, 110);
      expect(c.board.occupiedCount, 0);
      c.dispose();
    });

    test('2./9. completing one column pays 10 + 100', () {
      final GameController c = GameController.withState(
        board: _boardWith(_column(5, gaps: <int>{0})),
        tray: <BlockPiece?>[_unit('a')],
      );
      expect(_drop(c, 0, 0, 5), isTrue);

      expect(c.lastTurn!.clearedColumns, <int>[5]);
      expect(c.lastTurn!.scoreGained, 110);
      expect(c.board.occupiedCount, 0);
      c.dispose();
    });

    test('3./4./10. a row and a column at once pay 300, sharing one cell', () {
      // Row 3 needs (3,5); column 5 needs (3,5) too — one drop finishes both.
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(3, gaps: <int>{5}),
          ..._column(5, gaps: <int>{3}),
        }),
        tray: <BlockPiece?>[_unit('a')],
      );
      expect(_drop(c, 0, 3, 5), isTrue);

      final TurnResult turn = c.lastTurn!;
      expect(turn.clearedRows, <int>[3]);
      expect(turn.clearedColumns, <int>[5]);
      expect(turn.clearedLineCount, 2);
      expect(turn.clearedCells.length, _size + _size - 1);
      expect(turn.lineClearBonus, 300);
      expect(turn.scoreGained, 10 + 300);
      expect(c.board.occupiedCount, 0);
      c.dispose();
    });

    test('5./10. two rows finished by one domino pay 300', () {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{4}),
          ..._row(1, gaps: <int>{4}),
        }),
        // A vertical domino filling (0,4) and (1,4).
        tray: <BlockPiece?>[
          BlockPiece(
            id: 'v',
            cells: const <BlockCell>[BlockCell(0, 0), BlockCell(1, 0)],
            color: Colors.green,
          ),
        ],
      );
      expect(_drop(c, 0, 0, 4), isTrue);

      expect(c.lastTurn!.clearedRows, <int>[0, 1]);
      expect(c.lastTurn!.lineClearBonus, 300);
      expect(c.lastTurn!.scoreGained, 20 + 300);
      c.dispose();
    });

    test('11. three lines at once pay 600', () {
      // Rows 0 and 1 each miss column 4; column 4 misses only those two.
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{4}),
          ..._row(1, gaps: <int>{4}),
          ..._column(4, gaps: <int>{0, 1}),
        }),
        tray: <BlockPiece?>[
          BlockPiece(
            id: 'v',
            cells: const <BlockCell>[BlockCell(0, 0), BlockCell(1, 0)],
            color: Colors.green,
          ),
        ],
      );
      expect(_drop(c, 0, 0, 4), isTrue);

      final TurnResult turn = c.lastTurn!;
      expect(turn.clearedRows, <int>[0, 1]);
      expect(turn.clearedColumns, <int>[4]);
      expect(turn.clearedLineCount, 3);
      expect(turn.lineClearBonus, 600);
      expect(turn.scoreGained, 20 + 600);
      c.dispose();
    });

    test('12. four lines at once pay 1000', () {
      // Rows 0-3 each miss column 4; the square cannot fill four rows, so use
      // a 4-tall vertical bar.
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          for (int r = 0; r < 4; r++) ..._row(r, gaps: <int>{4}),
        }),
        tray: <BlockPiece?>[
          BlockPiece(
            id: 'bar4',
            cells: const <BlockCell>[
              BlockCell(0, 0),
              BlockCell(1, 0),
              BlockCell(2, 0),
              BlockCell(3, 0),
            ],
            color: Colors.amber,
          ),
        ],
      );
      expect(_drop(c, 0, 0, 4), isTrue);

      expect(c.lastTurn!.clearedRows, <int>[0, 1, 2, 3]);
      expect(c.lastTurn!.lineClearBonus, 1000);
      expect(c.lastTurn!.scoreGained, 40 + 1000);
      c.dispose();
    });

    test('13. five lines at once pay 1500', () {
      // Rows 0-3 miss column 4, and column 4 misses only those four rows.
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          for (int r = 0; r < 4; r++) ..._row(r, gaps: <int>{4}),
          ..._column(4, gaps: <int>{0, 1, 2, 3}),
        }),
        tray: <BlockPiece?>[
          BlockPiece(
            id: 'bar4',
            cells: const <BlockCell>[
              BlockCell(0, 0),
              BlockCell(1, 0),
              BlockCell(2, 0),
              BlockCell(3, 0),
            ],
            color: Colors.amber,
          ),
        ],
      );
      expect(_drop(c, 0, 0, 4), isTrue);

      final TurnResult turn = c.lastTurn!;
      expect(turn.clearedLineCount, 5);
      expect(turn.lineClearBonus, 1500);
      expect(turn.scoreGained, 40 + 1500);
      c.dispose();
    });

    test('6. cells outside the cleared lines survive the turn', () {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(3, gaps: <int>{7}),
          const BlockCell(6, 1),
          const BlockCell(6, 2),
        }),
        tray: <BlockPiece?>[_unit('a')],
      );
      expect(_drop(c, 0, 3, 7), isTrue);

      expect(c.board.occupiedCount, 2);
      expect(c.board.cellAt(6, 1).occupied, isTrue);
      expect(c.board.cellAt(6, 2).occupied, isTrue);
      c.dispose();
    });

    test('7. a placement that clears nothing keeps the block on the board', () {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: <BlockPiece?>[_domino('d')],
      );
      expect(_drop(c, 0, 2, 2), isTrue);

      expect(c.lastTurn!.clearedLineCount, 0);
      expect(c.board.occupiedCount, 2);
      expect(c.board.cellAt(2, 2).occupied, isTrue);
      expect(c.board.cellAt(2, 3).occupied, isTrue);
      c.dispose();
    });
  });

  group('combo', () {
    test('14. the first clear puts the streak at 1 and pays no combo bonus', () {
      final GameController c = GameController.withState(
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit('a')],
      );
      expect(c.combo, 0);
      _drop(c, 0, 0, 7);

      expect(c.combo, 1);
      expect(c.lastTurn!.comboBonus, 0);
      expect(c.lastTurn!.scoreGained, 10 + 100);
      c.dispose();
    });

    test('15./17. consecutive clears raise the streak and its bonus', () {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{7}),
          ..._row(2, gaps: <int>{7}),
          ..._row(4, gaps: <int>{7}),
        }),
        tray: <BlockPiece?>[_unit('a'), _unit('b'), _unit('c')],
      );

      _drop(c, 0, 0, 7);
      expect(c.combo, 1);
      expect(c.lastTurn!.comboBonus, 0);
      expect(c.score, 110);

      _drop(c, 1, 2, 7);
      expect(c.combo, 2);
      expect(c.lastTurn!.comboBonus, 50);
      expect(c.lastTurn!.scoreGained, 10 + 100 + 50);
      expect(c.score, 110 + 160);

      _drop(c, 2, 4, 7);
      expect(c.combo, 3);
      expect(c.lastTurn!.comboBonus, 100);
      expect(c.lastTurn!.scoreGained, 10 + 100 + 100);
      expect(c.score, 110 + 160 + 210);
      c.dispose();
    });

    test('16. a placement without a clear resets the streak to 0', () {
      final GameController c = GameController.withState(
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit('a'), _unit('b')],
      );

      _drop(c, 0, 0, 7);
      expect(c.combo, 1);

      // A drop in open space clears nothing.
      _drop(c, 1, 5, 5);
      expect(c.combo, 0);
      expect(c.lastTurn!.comboBonus, 0);
      expect(c.lastTurn!.scoreGained, 10);
      c.dispose();
    });

    test('an invalid release does not break the streak', () {
      final GameController c = GameController.withState(
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit('a'), _unit('b')],
      );
      _drop(c, 0, 0, 7);
      expect(c.combo, 1);

      // Released off the board: no placement, so no turn happened.
      c.startDrag(1, Offset.zero);
      c.updateDrag(const Offset(10, 10));
      expect(c.endDrag(), isFalse);

      expect(c.combo, 1);
      expect(c.score, 110);
      c.dispose();
    });
  });

  group('best score', () {
    test('19. rises as soon as the score passes it', () {
      final InMemoryBestScoreStore store = InMemoryBestScoreStore();
      final GameController c = _fixedTray(store: store);
      expect(c.bestScore, 0);

      _drop(c, 0, 0, 0); // +20
      expect(c.score, 20);
      expect(c.bestScore, 20);
      expect(store.value, 20);
      c.dispose();
    });

    test('20. never drops, not even after a reset', () {
      final InMemoryBestScoreStore store = InMemoryBestScoreStore();
      final GameController c = _fixedTray(store: store);

      _drop(c, 0, 0, 0); // +20
      _drop(c, 1, 4, 4); // +30
      expect(c.score, 50);
      expect(c.bestScore, 50);

      c.reset();
      expect(c.score, 0);
      expect(c.bestScore, 50);
      expect(store.value, 50);

      // The second run starts from scratch but BEST — in memory and on disk —
      // still remembers the first one.
      final int cells = c.tray[0]!.cells.length;
      _drop(c, 0, 0, 0);
      expect(c.score, cells * 10);
      expect(c.bestScore, greaterThanOrEqualTo(50));
      expect(store.value, greaterThanOrEqualTo(50));
      c.dispose();
    });

    test('20. a lower score never overwrites the stored value', () async {
      final InMemoryBestScoreStore store = InMemoryBestScoreStore(9999);
      final GameController c = _fixedTray(store: store);
      await c.loadBestScore();
      expect(c.bestScore, 9999);

      _drop(c, 0, 0, 0);
      expect(c.score, 20);
      expect(c.bestScore, 9999);
      expect(store.value, 9999);
      c.dispose();
    });

    test('21. is restored from shared preferences under the branded key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesBestScoreStore.key: 1234,
      });

      final GameController c = _fixedTray(
        store: const SharedPreferencesBestScoreStore(),
      );
      expect(c.bestScore, 0);
      await c.loadBestScore();
      expect(c.bestScore, 1234);
      c.dispose();
    });

    test('21. a new score is written back to shared preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const SharedPreferencesBestScoreStore store =
          SharedPreferencesBestScoreStore();

      final GameController c = _fixedTray(store: store);
      await c.loadBestScore();
      expect(c.bestScore, 0);

      _drop(c, 0, 0, 0); // +20
      await Future<void>.delayed(Duration.zero);

      expect(await store.load(), 20);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SharedPreferencesBestScoreStore.key), 20);
      // The old BlockJoy key is not used.
      expect(prefs.getInt('blockjoy_best_score'), isNull);
      c.dispose();
    });

    test('21. an empty store leaves BEST at 0', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final GameController c = _fixedTray(
        store: const SharedPreferencesBestScoreStore(),
      );
      await c.loadBestScore();
      expect(c.bestScore, 0);
      c.dispose();
    });
  });
}
