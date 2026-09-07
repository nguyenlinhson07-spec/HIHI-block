import 'package:flutter/foundation.dart';

/// A single filled cell of a [BlockPiece], expressed as an offset relative to
/// the top-left corner of the piece's bounding box.
@immutable
class BlockCell {
  const BlockCell(this.row, this.column);

  final int row;
  final int column;

  BlockCell copyWith({int? row, int? column}) =>
      BlockCell(row ?? this.row, column ?? this.column);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockCell && other.row == row && other.column == column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'BlockCell($row, $column)';
}
