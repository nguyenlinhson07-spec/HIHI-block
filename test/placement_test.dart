import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/domain/models/placement_result.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';

BlockPiece _piece(List<BlockCell> cells, {Color color = Colors.cyan}) =>
    BlockPiece(id: 'test', cells: cells, color: color);

/// A controller on an empty board with the predictable Phase-1 trio:
/// a 2-cell domino, a 3-cell L and a 2x2 square.
GameController _fixedTrayController() => GameController.withState(
  board: GameBoard.empty(),
  tray: BlockShapes.sampleTray(),
);

void main() {
  final BlockPiece domino = _piece(BlockShapes.line2H.cells);
  final BlockPiece lShape = _piece(BlockShapes.lSmallSW.cells);
  final BlockPiece square = _piece(BlockShapes.square2.cells);

  group('GameBoard.evaluate', () {
    test('1. a piece in the middle of the board is valid', () {
      final GameBoard board = GameBoard.empty();
      expect(board.canPlace(domino, 4, 3), isTrue);
      expect(board.canPlace(lShape, 3, 3), isTrue);
      expect(board.canPlace(square, 2, 2), isTrue);
    });

    test('2. hanging off the left edge is rejected', () {
      final GameBoard board = GameBoard.empty();
      expect(board.evaluate(domino, 4, -1).status, PlacementStatus.outOfBounds);
      expect(board.canPlace(domino, 4, -1), isFalse);
    });

    test('3. hanging off the right edge is rejected', () {
      final GameBoard board = GameBoard.empty();
      // A 2-wide piece anchored at the last column would need column 8.
      expect(board.evaluate(domino, 4, 7).status, PlacementStatus.outOfBounds);
      expect(board.canPlace(domino, 4, 7), isFalse);
      // Anchored one column earlier it fits exactly.
      expect(board.canPlace(domino, 4, 6), isTrue);
    });

    test('4. hanging off the top edge is rejected', () {
      final GameBoard board = GameBoard.empty();
      expect(board.evaluate(square, -1, 3).status, PlacementStatus.outOfBounds);
      expect(board.canPlace(square, -1, 3), isFalse);
    });

    test('5. hanging off the bottom edge is rejected', () {
      final GameBoard board = GameBoard.empty();
      // A 2-tall piece anchored on the last row would need row 8.
      expect(board.evaluate(square, 7, 3).status, PlacementStatus.outOfBounds);
      expect(board.canPlace(square, 7, 3), isFalse);
      expect(board.canPlace(square, 6, 3), isTrue);
    });

    test('6. overlapping an occupied cell is rejected', () {
      final GameBoard board = GameBoard.empty().placePiece(square, 3, 3);
      expect(board.evaluate(domino, 3, 3).status, PlacementStatus.overlap);
      expect(board.canPlace(domino, 3, 3), isFalse);
      // Even a single shared cell blocks it.
      expect(board.canPlace(domino, 4, 4), isFalse);
      // Clear of the square, it is fine again.
      expect(board.canPlace(domino, 5, 3), isTrue);
    });

    test('out of bounds wins over overlap when both apply', () {
      final GameBoard board = GameBoard.empty().placePiece(domino, 0, 6);
      expect(board.evaluate(domino, 0, 7).status, PlacementStatus.outOfBounds);
    });

    test('placePiece throws on an invalid anchor', () {
      final GameBoard board = GameBoard.empty();
      expect(() => board.placePiece(domino, 4, 7), throwsStateError);
    });

    test('placePiece does not mutate the original board', () {
      final GameBoard board = GameBoard.empty();
      final GameBoard next = board.placePiece(square, 1, 1);
      expect(board.occupiedCount, 0);
      expect(next.occupiedCount, 4);
    });
  });

  group('GameController drop', () {
    test('7. a valid drop occupies exactly the block cells, keeping colour', () {
      final GameController controller = _fixedTrayController();
      final BlockPiece piece = controller.tray[1]!; // the L shape
      controller.startDrag(1, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(2, 2));
      expect(controller.drag!.canDrop, isTrue);
      expect(controller.endDrag(), isTrue);

      expect(controller.board.occupiedCount, piece.cells.length);
      for (final BlockCell c in piece.cells) {
        final cell = controller.board.cellAt(2 + c.row, 2 + c.column);
        expect(cell.occupied, isTrue);
        expect(cell.color, piece.color);
      }
      controller.dispose();
    });

    test('8. a played piece leaves its tray slot empty', () {
      final GameController controller = _fixedTrayController();
      controller.startDrag(0, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 0));
      expect(controller.endDrag(), isTrue);

      expect(controller.tray[0], isNull);
      expect(controller.tray.length, GameConstants.traySlotCount);
      expect(controller.tray[1], isNotNull);
      expect(controller.tray[2], isNotNull);
      // The slot cannot be dragged again.
      expect(controller.startDrag(0, Offset.zero), isFalse);
      controller.dispose();
    });

    test('9. an invalid drop leaves the board and the tray untouched', () {
      final GameController controller = _fixedTrayController();
      final BlockPiece original = controller.tray[2]!;

      // Off the right edge.
      controller.startDrag(2, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 7));
      expect(controller.drag!.canDrop, isFalse);
      expect(controller.endDrag(), isFalse);
      expect(controller.board.occupiedCount, 0);
      expect(controller.tray[2], same(original));

      // Released away from the board entirely: no anchor, no preview.
      controller.startDrag(2, Offset.zero);
      controller.updateDrag(const Offset(10, 10));
      expect(controller.drag!.isOverBoard, isFalse);
      expect(controller.previewCells, isEmpty);
      expect(controller.endDrag(), isFalse);
      expect(controller.board.occupiedCount, 0);
      expect(controller.tray[2], same(original));

      // Onto an occupied cell.
      controller.startDrag(0, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(4, 4));
      controller.endDrag();
      controller.startDrag(2, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(4, 4));
      expect(controller.drag!.canDrop, isFalse);
      expect(controller.previewCells, isNotEmpty); // invalid preview is shown
      expect(controller.endDrag(), isFalse);
      expect(controller.tray[2], same(original));
      controller.dispose();
    });

    test('10. the board stays 8x8 after placements', () {
      final GameController controller = _fixedTrayController();
      for (int slot = 0; slot < GameConstants.traySlotCount; slot++) {
        controller.startDrag(slot, Offset.zero);
        controller.updateDrag(Offset.zero, anchor: BlockCell(slot * 2, 0));
        controller.endDrag();
      }
      expect(controller.board.size, GameConstants.boardSize);
      expect(controller.board.cells.length, GameConstants.boardSize);
      for (final List<Object?> row in controller.board.cells) {
        expect(row.length, GameConstants.boardSize);
      }
      expect(controller.tray.length, GameConstants.traySlotCount);
      controller.dispose();
    });

    test('cancelDrag returns the piece without touching the board', () {
      final GameController controller = _fixedTrayController();
      controller.startDrag(0, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 0));
      controller.cancelDrag();
      expect(controller.isDragging, isFalse);
      expect(controller.board.occupiedCount, 0);
      expect(controller.tray[0], isNotNull);
      controller.dispose();
    });

    test('a second drag cannot start while one is running', () {
      final GameController controller = _fixedTrayController();
      expect(controller.startDrag(0, Offset.zero), isTrue);
      expect(controller.startDrag(1, Offset.zero), isFalse);
      controller.dispose();
    });
  });
}
