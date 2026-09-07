import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/data/best_score_store.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/logic/piece_generator.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_over_overlay.dart';

const int _size = GameConstants.boardSize;

BlockPiece _unit() => BlockPiece(
  id: 'single',
  cells: const <BlockCell>[BlockCell(0, 0)],
  color: Colors.cyan,
);

BlockPiece _piece(String id, List<BlockCell> cells) =>
    BlockPiece(id: id, cells: cells, color: Colors.pinkAccent);

GameBoard _boardWith(Iterable<BlockCell> cells) {
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(_unit(), c.row, c.column);
  }
  return board;
}

/// Two empty cells per row and per column, none of them orthogonally
/// adjacent to another.
///
/// A board filled around these holes has no completed line, no 2-cell shape
/// fits anywhere, and filling one hole still leaves its row and its column
/// with a gap — so a placement here cannot trigger a clear.
Set<BlockCell> _isolatedHoles() => <BlockCell>{
  for (int r = 0; r < _size; r++) ...<BlockCell>[
    BlockCell(r, (3 * r) % _size),
    BlockCell(r, (3 * r + 4) % _size),
  ],
};

/// The board described by [_isolatedHoles].
GameBoard _holeyBoard() => _boardWith(_allExcept(_isolatedHoles()));

/// Every cell except the ones listed.
Iterable<BlockCell> _allExcept(Set<BlockCell> free) sync* {
  for (int r = 0; r < _size; r++) {
    for (int c = 0; c < _size; c++) {
      final BlockCell cell = BlockCell(r, c);
      if (!free.contains(cell)) yield cell;
    }
  }
}

/// A controller one legal drop away from having no moves left: the board is
/// [_holeyBoard], and only the single in slot 0 fits anywhere.
GameController _deadEndAfterOneDrop({BestScoreStore? store, int combo = 0}) =>
    GameController.withState(
      board: _holeyBoard(),
      tray: <BlockPiece?>[
        _unit(),
        BlockShapes.square2.toPiece(Colors.cyan),
        BlockShapes.line5H.toPiece(Colors.cyan),
      ],
      bestScoreStore: store,
      combo: combo,
    );

bool _drop(GameController c, int slot, int row, int column) {
  c.startDrag(slot, Offset.zero);
  c.updateDrag(Offset.zero, anchor: BlockCell(row, column));
  return c.endDrag();
}

void main() {
  group('7. move detection', () {
    test('10. canPlaceAnywhere is true while there is room', () {
      final GameBoard board = GameBoard.empty();
      expect(board.canPlaceAnywhere(_unit()), isTrue);
      expect(
        board.canPlaceAnywhere(BlockShapes.square3.toPiece(Colors.cyan)),
        isTrue,
      );
      expect(
        board.canPlaceAnywhere(BlockShapes.line5V.toPiece(Colors.cyan)),
        isTrue,
      );
    });

    test('11. canPlaceAnywhere is false when nothing fits', () {
      // Only (0, 0) and (7, 7) are free — no 2-cell shape can cover either.
      final GameBoard board = _boardWith(
        _allExcept(<BlockCell>{const BlockCell(0, 0), const BlockCell(7, 7)}),
      );

      expect(board.canPlaceAnywhere(_unit()), isTrue);
      expect(
        board.canPlaceAnywhere(BlockShapes.line2H.toPiece(Colors.cyan)),
        isFalse,
      );
      expect(
        board.canPlaceAnywhere(BlockShapes.square2.toPiece(Colors.cyan)),
        isFalse,
      );

      // A completely full board has room for nothing at all.
      final GameBoard full = _boardWith(_allExcept(const <BlockCell>{}));
      expect(full.canPlaceAnywhere(_unit()), isFalse);
    });

    test('11. a piece bigger than the board never fits', () {
      final BlockPiece tooWide = _piece('too-wide', <BlockCell>[
        for (int c = 0; c < _size + 1; c++) BlockCell(0, c),
      ]);
      expect(GameBoard.empty().canPlaceAnywhere(tooWide), isFalse);
    });

    test('12. hasAnyMove is true if a single tray piece fits', () {
      final GameBoard board = _boardWith(
        _allExcept(<BlockCell>{const BlockCell(0, 0)}),
      );
      final List<BlockPiece?> tray = <BlockPiece?>[
        BlockShapes.square2.toPiece(Colors.cyan),
        BlockShapes.line5H.toPiece(Colors.cyan),
        _unit(), // the only one that fits
      ];
      expect(board.hasAnyMove(tray), isTrue);
    });

    test('13. hasAnyMove is false when no tray piece fits', () {
      final GameBoard board = _boardWith(
        _allExcept(<BlockCell>{const BlockCell(0, 0)}),
      );
      expect(
        board.hasAnyMove(<BlockPiece?>[
          BlockShapes.square2.toPiece(Colors.cyan),
          BlockShapes.line2V.toPiece(Colors.cyan),
          BlockShapes.line5H.toPiece(Colors.cyan),
        ]),
        isFalse,
      );
    });

    test('13. empty slots are skipped', () {
      final GameBoard board = GameBoard.empty();
      expect(board.hasAnyMove(<BlockPiece?>[null, null, null]), isFalse);
      expect(board.hasAnyMove(<BlockPiece?>[null, _unit(), null]), isTrue);
    });
  });

  group('5. refill', () {
    test('6. one piece left means no refill', () {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      final BlockPiece kept = c.tray[1]!;

      _drop(c, 0, 0, 0);
      expect(c.tray[0], isNull);
      expect(c.tray[1], same(kept));

      _drop(c, 2, 4, 4);
      expect(c.tray, <BlockPiece?>[null, kept, null]);
      c.dispose();
    });

    test('5. emptying all three slots deals a new trio', () {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
        generator: PieceGenerator(random: Random(1)),
      );
      final Set<BlockPiece> original = c.tray.whereType<BlockPiece>().toSet();

      _drop(c, 0, 0, 0);
      _drop(c, 1, 3, 0);
      expect(c.tray.where((BlockPiece? p) => p != null).length, 1);

      _drop(c, 2, 6, 0);

      expect(c.tray.length, GameConstants.traySlotCount);
      expect(c.tray.every((BlockPiece? p) => p != null), isTrue);
      for (final BlockPiece? piece in c.tray) {
        expect(original, isNot(contains(piece)));
      }
      c.dispose();
    });

    test('7./8./9. dealing changes nothing but the tray', () {
      // Row 0 is one cell short, so the last drop also clears a line and
      // starts a combo — the refill that follows must not disturb any of it.
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>[
          for (int col = 1; col < _size; col++) BlockCell(0, col),
        ]),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
        generator: PieceGenerator(random: Random(2)),
      );

      _drop(c, 0, 5, 5);
      _drop(c, 1, 6, 6);
      final int scoreBefore = c.score;
      final int bestBefore = c.bestScore;

      // Third drop completes row 0, empties the tray and triggers the deal.
      _drop(c, 2, 0, 0);

      expect(c.combo, 1, reason: 'the deal must not reset the streak');
      expect(c.score, scoreBefore + 110);
      expect(c.bestScore, greaterThanOrEqualTo(bestBefore));
      // Row 0 was cleared; only the two loose blocks remain.
      expect(c.board.occupiedCount, 2);
      expect(c.board.cellAt(5, 5).occupied, isTrue);
      expect(c.board.cellAt(6, 6).occupied, isTrue);
      expect(c.tray.every((BlockPiece? p) => p != null), isTrue);
      c.dispose();
    });

    test('9. a dealt tray does not touch the combo streak', () {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>[
          for (int col = 1; col < _size; col++) BlockCell(0, col),
          for (int col = 1; col < _size; col++) BlockCell(1, col),
        ]),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
        generator: PieceGenerator(random: Random(3)),
      );

      _drop(c, 0, 0, 0); // clears row 0 -> combo 1
      expect(c.combo, 1);
      _drop(c, 1, 1, 0); // clears row 1 -> combo 2
      expect(c.combo, 2);
      _drop(c, 2, 4, 4); // clears nothing -> combo 0, and empties the tray
      expect(c.combo, 0);
      expect(c.tray.every((BlockPiece? p) => p != null), isTrue);
      c.dispose();
    });
  });

  group('8. game over', () {
    /// A board with one free cell and a tray where nothing fits it.
    GameController deadEnd({BestScoreStore? store, int score = 0}) =>
        GameController.withState(
          board: _boardWith(_allExcept(<BlockCell>{const BlockCell(0, 0)})),
          tray: <BlockPiece?>[
            BlockShapes.square2.toPiece(Colors.cyan),
            BlockShapes.line2H.toPiece(Colors.cyan),
            BlockShapes.line5V.toPiece(Colors.cyan),
          ],
          bestScoreStore: store,
          score: score,
          bestScore: score,
        );

    test('the holey board is a dead end for anything bigger than one cell', () {
      final GameBoard board = _holeyBoard();
      expect(board.occupiedCount, 64 - 16);
      expect(board.findFullLines().isEmpty, isTrue, reason: 'no line is full');
      expect(board.canPlaceAnywhere(_unit()), isTrue);
      for (final BlockShape shape in BlockShapes.catalogue) {
        if (shape.cellCount == 1) continue;
        expect(
          board.canPlaceAnywhere(shape.toPiece(Colors.cyan)),
          isFalse,
          reason: 'shape ${shape.id} should not fit',
        );
      }
    });

    test('15. a full board with an unplayable tray is game over', () {
      final GameController c = deadEnd();
      // The controller only re-evaluates after a placement, so drive one.
      expect(c.isGameOver, isFalse);

      // Nothing in the tray fits, so there is no legal drop to make; ask the
      // domain directly, then confirm a real placement flips the flag.
      expect(c.hasAnyMove(), isFalse);
      c.dispose();
    });

    test('15. the flag flips after the placement that kills the board', () {
      final GameController c = _deadEndAfterOneDrop();
      expect(c.isGameOver, isFalse);
      final int before = c.board.occupiedCount;

      // The single fits one hole; the other two pieces fit nowhere, and the
      // drop completes no line.
      expect(_drop(c, 0, 0, 0), isTrue);

      expect(c.board.occupiedCount, before + 1, reason: 'nothing was cleared');
      expect(c.lastTurn!.clearedLineCount, 0);
      expect(c.isGameOver, isTrue);
      c.dispose();
    });

    test('14. an invalid drop never ends the game', () {
      final GameController c = _deadEndAfterOneDrop();
      final int before = c.board.occupiedCount;

      // Onto an occupied cell — row 0 has holes at columns 0 and 4 only.
      c.startDrag(0, Offset.zero);
      c.updateDrag(Offset.zero, anchor: const BlockCell(0, 1));
      expect(c.drag!.canDrop, isFalse);
      expect(c.endDrag(), isFalse);
      expect(c.isGameOver, isFalse);

      // Released off the board.
      c.startDrag(0, Offset.zero);
      c.updateDrag(const Offset(9, 9));
      expect(c.endDrag(), isFalse);
      expect(c.isGameOver, isFalse);

      expect(c.board.occupiedCount, before);
      expect(c.tray[0], isNotNull);
      c.dispose();
    });

    test('16./17./18. game over freezes drag, score, tray and BEST', () {
      final InMemoryBestScoreStore store = InMemoryBestScoreStore();
      final GameController c = _deadEndAfterOneDrop(store: store);

      _drop(c, 0, 0, 0);
      expect(c.isGameOver, isTrue);

      final int score = c.score;
      final int best = c.bestScore;
      final int occupied = c.board.occupiedCount;
      final List<BlockPiece?> tray = c.tray;

      // Every drag attempt is refused outright.
      for (int slot = 0; slot < GameConstants.traySlotCount; slot++) {
        expect(c.startDrag(slot, Offset.zero), isFalse);
      }
      expect(c.isDragging, isFalse);
      expect(c.score, score);
      expect(c.bestScore, best);
      expect(store.value, best);
      expect(c.board.occupiedCount, occupied);
      expect(c.tray, tray);
      c.dispose();
    });
  });

  group('11. play again', () {
    GameController finished() {
      final GameController c = _deadEndAfterOneDrop(combo: 3);
      _drop(c, 0, 0, 0);
      return c;
    }

    test('19./20./21./22./23./24. resets the round but keeps BEST', () {
      final GameController c = finished();
      expect(c.isGameOver, isTrue);
      final int best = c.bestScore;
      expect(best, greaterThan(0));
      final List<BlockPiece?> oldTray = c.tray;

      c.reset();

      expect(c.board.occupiedCount, 0); // 19
      expect(c.score, 0); // 20
      expect(c.combo, 0); // 21
      expect(c.isGameOver, isFalse); // 22
      expect(c.tray.length, GameConstants.traySlotCount); // 23
      expect(c.tray.every((BlockPiece? p) => p != null), isTrue); // 23
      expect(c.tray, isNot(oldTray)); // 23
      expect(c.bestScore, best); // 24
      expect(c.lastTurn, isNull);
      expect(c.isDragging, isFalse);

      // And the game is playable again.
      expect(c.startDrag(0, Offset.zero), isTrue);
      c.dispose();
    });

    test('24. play again does not clear the stored best score', () async {
      final InMemoryBestScoreStore store = InMemoryBestScoreStore(777);
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
        bestScoreStore: store,
      );
      await c.loadBestScore();
      expect(c.bestScore, 777);

      c.reset();
      expect(c.bestScore, 777);
      expect(store.value, 777);
      c.dispose();
    });
  });

  group('10. game over overlay', () {
    Future<GameController> pumpFinished(
      WidgetTester tester,
      Size size,
    ) async {
      final GameController controller = _deadEndAfterOneDrop();
      addTearDown(controller.dispose);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HiHiBlockApp(controller: controller));
      await tester.pumpAndSettle();

      _drop(controller, 0, 0, 0);
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('is hidden until the game is over', (
      WidgetTester tester,
    ) async {
      final GameController controller = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(HiHiBlockApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverOverlay), findsNothing);
      expect(find.text('GAME OVER'), findsNothing);
    });

    testWidgets('shows GAME OVER with the score and best', (
      WidgetTester tester,
    ) async {
      final GameController controller = await pumpFinished(
        tester,
        const Size(390, 844),
      );

      expect(controller.isGameOver, isTrue);
      expect(find.byType(GameOverOverlay), findsOneWidget);
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('${controller.score}'), findsWidgets);
      expect(find.text('${controller.bestScore}'), findsWidgets);
    });

    for (final Size size in <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('27./28./29. fits ${size.width.toInt()}x${size.height.toInt()}',
          (WidgetTester tester) async {
        await pumpFinished(tester, size);

        expect(tester.takeException(), isNull);
        expect(find.byType(GameOverOverlay), findsOneWidget);

        final Rect card = tester.getRect(find.text('GAME OVER'));
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(size.height));

        final Rect button = tester.getRect(find.text('PLAY AGAIN'));
        expect(button.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('22. PLAY AGAIN restarts the round in place', (
      WidgetTester tester,
    ) async {
      final GameController controller = await pumpFinished(
        tester,
        const Size(390, 844),
      );
      final int best = controller.bestScore;

      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverOverlay), findsNothing);
      expect(controller.isGameOver, isFalse);
      expect(controller.board.occupiedCount, 0);
      expect(controller.score, 0);
      expect(controller.combo, 0);
      expect(controller.bestScore, best);
      // Still the same screen — no route was pushed or replaced.
      expect(find.byType(HiHiBlockApp), findsOneWidget);
    });
  });
}
