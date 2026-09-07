import 'package:flutter/foundation.dart';

import 'block_cell.dart';
import 'line_clear_result.dart';

/// Everything that happened during one successful placement.
///
/// The widget layer only reads this — it never recomputes any of it.
@immutable
class TurnResult {
  TurnResult({
    required List<BlockCell> placedCells,
    required this.clear,
    required this.placementScore,
    required this.lineClearBonus,
    required this.comboBonus,
    required this.combo,
  }) : placedCells = List<BlockCell>.unmodifiable(placedCells);

  /// Board cells the dropped block filled.
  final List<BlockCell> placedCells;

  /// Rows/columns completed by this placement.
  final LineClearResult clear;

  final int placementScore;
  final int lineClearBonus;
  final int comboBonus;

  /// Combo step reached by this placement; `0` when the streak broke.
  final int combo;

  List<int> get clearedRows => clear.rows;
  List<int> get clearedColumns => clear.columns;

  /// Every cell emptied by this placement, intersections counted once.
  Set<BlockCell> get clearedCells => clear.cells;

  int get clearedLineCount => clear.lineCount;

  /// Total points this placement was worth.
  int get scoreGained => placementScore + lineClearBonus + comboBonus;

  @override
  String toString() =>
      'TurnResult(+$scoreGained, ${clear.lineCount} lines, combo $combo)';
}
