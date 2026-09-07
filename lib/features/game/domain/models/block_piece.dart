import 'package:flutter/material.dart';

import 'block_cell.dart';

/// A shape that can be dropped onto the board.
///
/// [cells] are normalised so that the smallest row and column are both `0`.
@immutable
class BlockPiece {
  BlockPiece({
    required this.id,
    required List<BlockCell> cells,
    required this.color,
  }) : cells = List<BlockCell>.unmodifiable(_normalise(cells));

  final String id;
  final List<BlockCell> cells;
  final Color color;

  /// Number of rows the piece occupies.
  int get rowCount =>
      cells.fold<int>(0, (int max, BlockCell c) => c.row > max ? c.row : max) +
      1;

  /// Number of columns the piece occupies.
  int get columnCount =>
      cells.fold<int>(
        0,
        (int max, BlockCell c) => c.column > max ? c.column : max,
      ) +
      1;

  bool contains(int row, int column) => cells.contains(BlockCell(row, column));

  static List<BlockCell> _normalise(List<BlockCell> cells) {
    assert(cells.isNotEmpty, 'A BlockPiece needs at least one cell.');
    final int minRow = cells
        .map((BlockCell c) => c.row)
        .reduce((int a, int b) => a < b ? a : b);
    final int minColumn = cells
        .map((BlockCell c) => c.column)
        .reduce((int a, int b) => a < b ? a : b);
    return cells
        .map((BlockCell c) => BlockCell(c.row - minRow, c.column - minColumn))
        .toList(growable: false);
  }

  @override
  String toString() => 'BlockPiece($id, ${cells.length} cells)';
}
