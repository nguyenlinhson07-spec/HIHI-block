import 'package:flutter/material.dart';

/// One cell of the 8x8 board.
@immutable
class BoardCell {
  const BoardCell({
    required this.row,
    required this.column,
    this.occupied = false,
    this.color,
  });

  final int row;
  final int column;
  final bool occupied;

  /// Fill colour when [occupied]; `null` for an empty cell.
  final Color? color;

  BoardCell copyWith({bool? occupied, Color? color}) => BoardCell(
    row: row,
    column: column,
    occupied: occupied ?? this.occupied,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCell &&
          other.row == row &&
          other.column == column &&
          other.occupied == occupied &&
          other.color == color;

  @override
  int get hashCode => Object.hash(row, column, occupied, color);
}
