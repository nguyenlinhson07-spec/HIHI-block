import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';

void main() {
  group('GameBoard', () {
    test('starts empty and square', () {
      final GameBoard board = GameBoard.empty();
      expect(board.size, GameConstants.boardSize);
      expect(board.cells.length, GameConstants.boardSize);
      for (final List<dynamic> row in board.cells) {
        expect(row.length, GameConstants.boardSize);
      }
      expect(
        board.cells.expand((List<dynamic> r) => r).length,
        GameConstants.boardSize * GameConstants.boardSize,
      );
      expect(board.cellAt(3, 4).occupied, isFalse);
      expect(board.occupiedCount, 0);
    });

    test('knows which coordinates it contains', () {
      final GameBoard board = GameBoard.empty();
      expect(board.contains(0, 0), isTrue);
      expect(board.contains(7, 7), isTrue);
      expect(board.contains(-1, 0), isFalse);
      expect(board.contains(0, 8), isFalse);
    });
  });

  group('BlockPiece', () {
    test('normalises cells to the origin', () {
      final BlockPiece piece = BlockPiece(
        id: 'offset',
        cells: const <BlockCell>[BlockCell(3, 5), BlockCell(3, 6)],
        color: Colors.red,
      );
      expect(piece.cells, const <BlockCell>[BlockCell(0, 0), BlockCell(0, 1)]);
      expect(piece.rowCount, 1);
      expect(piece.columnCount, 2);
    });

    test('reports its bounding box', () {
      final BlockPiece l = BlockPiece(
        id: 'l',
        cells: BlockShapes.lSmallSW.cells,
        color: Colors.blue,
      );
      expect(l.rowCount, 2);
      expect(l.columnCount, 2);
      expect(l.cells.length, 3);
      expect(l.contains(0, 1), isFalse);
    });
  });

  group('GameController', () {
    test('deals three playable pieces and a zero score', () {
      final GameController controller = GameController();
      expect(controller.tray.length, GameConstants.traySlotCount);
      expect(controller.tray.every((BlockPiece? p) => p != null), isTrue);
      expect(controller.score, 0);
      expect(controller.bestScore, 0);
      expect(controller.isDragging, isFalse);
      expect(controller.isGameOver, isFalse);
      // Every dealt piece comes from the catalogue.
      final Set<String> ids = BlockShapes.catalogue
          .map((BlockShape s) => s.id)
          .toSet();
      for (final BlockPiece? piece in controller.tray) {
        expect(ids, contains(piece!.id));
      }
      controller.dispose();
    });

    test('reset restores the board and the tray', () {
      final GameController controller = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      controller.startDrag(0, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 0));
      controller.endDrag();
      expect(controller.board.occupiedCount, greaterThan(0));

      controller.reset();
      expect(controller.board.occupiedCount, 0);
      expect(controller.tray.every((BlockPiece? p) => p != null), isTrue);
      expect(controller.isDragging, isFalse);
      controller.dispose();
    });
  });
}
