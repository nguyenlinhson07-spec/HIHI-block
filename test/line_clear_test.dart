import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/domain/models/line_clear_result.dart';

const int _size = GameConstants.boardSize;

BlockPiece _single({Color color = Colors.cyan}) => BlockPiece(
  id: 'unit',
  cells: const <BlockCell>[BlockCell(0, 0)],
  color: color,
);

/// Fills every listed cell with a 1x1 block.
GameBoard _boardWith(Iterable<BlockCell> cells, {Color color = Colors.cyan}) {
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(_single(color: color), c.row, c.column);
  }
  return board;
}

/// Row [row], optionally leaving [gap] empty.
Iterable<BlockCell> _row(int row, {int? gap}) sync* {
  for (int c = 0; c < _size; c++) {
    if (c != gap) yield BlockCell(row, c);
  }
}

/// Column [column], optionally leaving [gap] empty.
Iterable<BlockCell> _column(int column, {int? gap}) sync* {
  for (int r = 0; r < _size; r++) {
    if (r != gap) yield BlockCell(r, column);
  }
}

void main() {
  group('detect', () {
    test('an incomplete row is not detected', () {
      final GameBoard board = _boardWith(_row(3, gap: 5));
      expect(board.isRowFull(3), isFalse);
      expect(board.findFullLines().isEmpty, isTrue);
    });

    test('1. a completed row is detected and cleared', () {
      final GameBoard board = _boardWith(_row(3));
      expect(board.isRowFull(3), isTrue);

      final LineClearResult clear = board.findFullLines();
      expect(clear.rows, <int>[3]);
      expect(clear.columns, isEmpty);
      expect(clear.lineCount, 1);
      expect(clear.cells.length, _size);

      final GameBoard after = board.clearLines(clear);
      expect(after.occupiedCount, 0);
      for (int c = 0; c < _size; c++) {
        expect(after.cellAt(3, c).occupied, isFalse);
        expect(after.cellAt(3, c).color, isNull);
      }
    });

    test('2. a completed column is detected and cleared', () {
      final GameBoard board = _boardWith(_column(6));
      expect(board.isColumnFull(6), isTrue);

      final LineClearResult clear = board.findFullLines();
      expect(clear.columns, <int>[6]);
      expect(clear.rows, isEmpty);
      expect(clear.cells.length, _size);

      expect(board.clearLines(clear).occupiedCount, 0);
    });

    test('3. a row and a column completed in the same turn both clear', () {
      // A full row 2 and a full column 4 already share cell (2, 4).
      final GameBoard board = _boardWith(<BlockCell>{
        ..._row(2),
        ..._column(4),
      });

      final LineClearResult clear = board.findFullLines();
      expect(clear.rows, <int>[2]);
      expect(clear.columns, <int>[4]);
      expect(clear.lineCount, 2);
      expect(board.clearLines(clear).occupiedCount, 0);
    });

    test('4. the intersection cell is only listed once', () {
      final GameBoard board = _boardWith(<BlockCell>{
        ..._row(2),
        ..._column(4),
      });
      final LineClearResult clear = board.findFullLines();

      // 8 + 8 cells minus the one they share.
      expect(clear.cells.length, _size + _size - 1);
      expect(
        clear.cells.where((BlockCell c) => c == const BlockCell(2, 4)).length,
        1,
      );
    });

    test('5. two rows completed at once clear together', () {
      final GameBoard board = _boardWith(<BlockCell>{..._row(0), ..._row(7)});
      final LineClearResult clear = board.findFullLines();

      expect(clear.rows, <int>[0, 7]);
      expect(clear.lineCount, 2);
      expect(clear.cells.length, 2 * _size);
      expect(board.clearLines(clear).occupiedCount, 0);
    });

    test('two columns completed at once clear together', () {
      final GameBoard board = _boardWith(<BlockCell>{
        ..._column(1),
        ..._column(2),
      });
      expect(board.findFullLines().columns, <int>[1, 2]);
    });

    test('6. cells outside the cleared lines are untouched', () {
      const Color rowColor = Colors.cyan;
      const Color keepColor = Colors.orange;
      GameBoard board = _boardWith(_row(3), color: rowColor);
      // Two survivors that are not on row 3.
      board = board.placePiece(_single(color: keepColor), 5, 2);
      board = board.placePiece(_single(color: keepColor), 6, 7);

      final GameBoard after = board.clearLines(board.findFullLines());

      expect(after.occupiedCount, 2);
      expect(after.cellAt(5, 2).occupied, isTrue);
      expect(after.cellAt(5, 2).color, keepColor);
      expect(after.cellAt(6, 7).occupied, isTrue);
      expect(after.cellAt(6, 7).color, keepColor);
      expect(after.cellAt(3, 0).occupied, isFalse);
    });

    test('7. a placement that completes nothing leaves the block on board', () {
      final GameBoard board = _boardWith(_row(3, gap: 0));
      final LineClearResult clear = board.findFullLines();

      expect(clear.isEmpty, isTrue);
      final GameBoard after = board.clearLines(clear);
      expect(identical(after, board), isTrue);
      expect(after.occupiedCount, _size - 1);
    });

    test('a full board reports all 8 rows and all 8 columns', () {
      final GameBoard board = _boardWith(<BlockCell>[
        for (int r = 0; r < _size; r++)
          for (int c = 0; c < _size; c++) BlockCell(r, c),
      ]);
      final LineClearResult clear = board.findFullLines();

      expect(clear.rows.length, _size);
      expect(clear.columns.length, _size);
      expect(clear.lineCount, 2 * _size);
      // Every cell is covered exactly once despite 64 overlaps.
      expect(clear.cells.length, _size * _size);
      expect(board.clearLines(clear).occupiedCount, 0);
    });

    test('rows and columns are scanned against the same snapshot', () {
      // Column 0 is full; row 3 is one cell short and that cell is (3, 0).
      // Clearing the column must NOT make row 3 count as completed.
      final GameBoard board = _boardWith(<BlockCell>{
        ..._column(0),
        ..._row(3, gap: 0),
      });
      final LineClearResult clear = board.findFullLines();

      expect(clear.columns, <int>[0]);
      expect(clear.rows, <int>[3]); // row 3 IS full: (3,0) came from column 0
      expect(clear.lineCount, 2);
    });

    test('clearLines does not mutate the original board', () {
      final GameBoard board = _boardWith(_row(3));
      final GameBoard after = board.clearLines(board.findFullLines());
      expect(board.occupiedCount, _size);
      expect(after.occupiedCount, 0);
    });
  });
}
