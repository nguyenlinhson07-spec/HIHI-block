import 'package:flutter/foundation.dart';

import 'block_cell.dart';

/// The full rows and columns found on the board after a placement, plus the
/// exact set of cells they cover.
///
/// [cells] is a [Set], so a cell sitting where a full row crosses a full
/// column appears once and is only ever cleared once.
@immutable
class LineClearResult {
  LineClearResult({
    required List<int> rows,
    required List<int> columns,
    required Set<BlockCell> cells,
  }) : rows = List<int>.unmodifiable(rows),
       columns = List<int>.unmodifiable(columns),
       cells = Set<BlockCell>.unmodifiable(cells);

  /// Nothing was completed.
  const LineClearResult.none()
    : rows = const <int>[],
      columns = const <int>[],
      cells = const <BlockCell>{};

  final List<int> rows;
  final List<int> columns;

  /// Every cell that should be emptied, de-duplicated across intersections.
  final Set<BlockCell> cells;

  /// Rows plus columns — the number the clear bonus is based on.
  int get lineCount => rows.length + columns.length;

  bool get isEmpty => lineCount == 0;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'LineClearResult(rows: $rows, columns: $columns, '
      '${cells.length} cells)';
}
