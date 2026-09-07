import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/drag_ghost.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';

/// Guards the drag fast path: geometry is captured once per drag and every
/// pointer move is arithmetic on it. If that cache ever goes stale, the block
/// lands on the wrong cell — so these tests check the mapping end to end
/// rather than trusting the maths in isolation.
const List<Size> _phoneSizes = <Size>[
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
];

Future<GameController> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<BlockPiece?>? tray,
}) async {
  final GameController controller = GameController.withState(
    board: GameBoard.empty(),
    tray: tray ?? BlockShapes.sampleTray(),
  );
  addTearDown(controller.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HiHiBlockApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Offset _slotCentre(WidgetTester tester, int index) => tester.getCenter(
  find
      .descendant(
        of: find.byType(BlockTray),
        matching: find.byType(BlockPieceView),
      )
      .at(index),
);

/// The pointer position that puts the block's top-left on ([row], [column]).
Offset _pointerFor(WidgetTester tester, int row, int column) {
  final Rect board = tester.getRect(find.byType(GameBoardView));
  final BoardGeometry geo = BoardGeometry(side: board.width);
  return board.topLeft +
      geo.originOf(row, column) +
      Offset(geo.cellSize / 2, geo.cellSize / 2 + GameConstants.dragLift);
}

void main() {
  group('pointer maps to the right cell', () {
    for (final Size size in _phoneSizes) {
      testWidgets('every anchor on the board at ${size.width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        final GameController controller = await _pump(
          tester,
          size: size,
          // A single cell can be anchored anywhere, so this sweeps all 64.
          tray: <BlockPiece?>[
            BlockShapes.single.toPiece(Colors.cyan),
            BlockShapes.single.toPiece(Colors.pink),
            BlockShapes.single.toPiece(Colors.green),
          ],
        );

        final TestGesture gesture = await tester.startGesture(
          _slotCentre(tester, 0),
        );
        await tester.pump();

        for (int row = 0; row < GameConstants.boardSize; row++) {
          for (int column = 0; column < GameConstants.boardSize; column++) {
            await gesture.moveTo(_pointerFor(tester, row, column));
            await tester.pump();
            expect(
              controller.drag!.anchor,
              BlockCell(row, column),
              reason: 'pointer aimed at ($row, $column) at ${size.width}dp',
            );
            expect(controller.drag!.canDrop, isTrue);
          }
        }

        await gesture.up();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('the block lands exactly where the preview said it would', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 2), // the 2x2 square
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(tester, 5, 6));
      await tester.pump();

      final BlockCell anchor = controller.drag!.anchor!;
      expect(anchor, const BlockCell(5, 6));

      await gesture.up();
      await tester.pumpAndSettle();

      for (int r = 5; r <= 6; r++) {
        for (int c = 6; c <= 7; c++) {
          expect(
            controller.board.cellAt(r, c).occupied,
            isTrue,
            reason: 'cell ($r, $c) should have been filled',
          );
        }
      }
      expect(controller.board.occupiedCount, 4);
    });

    testWidgets('leaving the board clears the anchor and comes back cleanly', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);
      final Rect board = tester.getRect(find.byType(GameBoardView));

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 0),
      );
      await tester.pump();

      await gesture.moveTo(_pointerFor(tester, 3, 3));
      await tester.pump();
      expect(controller.drag!.anchor, const BlockCell(3, 3));

      // Well below the board, over the tray.
      await gesture.moveTo(board.bottomCenter + const Offset(0, 260));
      await tester.pump();
      expect(controller.drag!.anchor, isNull);
      expect(controller.previewCells, isEmpty);

      // Back on: the cached geometry still maps correctly.
      await gesture.moveTo(_pointerFor(tester, 3, 3));
      await tester.pump();
      expect(controller.drag!.anchor, const BlockCell(3, 3));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the drag fast path does only the work it has to', () {
    testWidgets('moving within one cell moves the block but not the preview', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 0),
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(tester, 4, 4));
      await tester.pump();

      final int revisionAtCell = controller.previewRevision.value;
      final BlockCell anchor = controller.drag!.anchor!;
      final Rect ghostBefore = tester.getRect(find.byType(DragGhost));

      // Nudge a couple of pixels — the same cell, a different position.
      await gesture.moveTo(_pointerFor(tester, 4, 4) + const Offset(3, 3));
      await tester.pump();

      expect(
        controller.previewRevision.value,
        revisionAtCell,
        reason: 'the preview must not be recomputed while the anchor holds',
      );
      expect(controller.drag!.anchor, anchor);

      // ...but the block itself did follow the finger.
      final Rect ghostAfter = tester.getRect(find.byType(DragGhost));
      expect(ghostAfter.left, closeTo(ghostBefore.left + 3, 0.01));
      expect(ghostAfter.top, closeTo(ghostBefore.top + 3, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('crossing into a new cell does refresh the preview', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 0),
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(tester, 4, 4));
      await tester.pump();
      final int before = controller.previewRevision.value;

      await gesture.moveTo(_pointerFor(tester, 4, 5));
      await tester.pump();

      expect(controller.previewRevision.value, greaterThan(before));
      expect(controller.drag!.anchor, const BlockCell(4, 5));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the pointer notifier rests when no block is in the air', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);
      expect(controller.pointerPosition.value, isNull);

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 0),
      );
      await tester.pump();
      expect(controller.pointerPosition.value, isNotNull);

      await gesture.moveTo(_pointerFor(tester, 2, 2));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.pointerPosition.value, isNull);
      expect(find.byType(DragGhost), findsNothing);
    });

    testWidgets('a cancelled pointer leaves nothing behind', (
      WidgetTester tester,
    ) async {
      final GameController controller = await _pump(tester);

      final TestGesture gesture = await tester.startGesture(
        _slotCentre(tester, 0),
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(tester, 2, 2));
      await tester.pump();

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(controller.isDragging, isFalse);
      expect(controller.pointerPosition.value, isNull);
      expect(controller.board.occupiedCount, 0);
      expect(controller.tray[0], isNotNull);
      expect(find.byType(DragGhost), findsNothing);
    });
  });
}
