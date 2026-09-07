import 'dart:math' as math;

/// Every scoring rule in the game, in one place.
///
/// Pure functions — no state, no widgets — so the numbers are easy to reason
/// about and to test.
class ScoreSystem {
  const ScoreSystem._();

  /// Points awarded per cell of a placed block.
  static const int pointsPerCell = 10;

  /// Bonus for clearing 1..4 lines in a single placement.
  static const List<int> lineBonusTable = <int>[0, 100, 300, 600, 1000];

  /// Each line beyond the fourth in one placement.
  static const int extraLineBonus = 500;

  /// Bonus per combo step past the first.
  static const int comboStepBonus = 50;

  /// Points for dropping a block of [cellCount] cells.
  static int placementScore(int cellCount) => cellCount * pointsPerCell;

  /// Bonus for clearing [lineCount] rows + columns at once.
  ///
  /// 1/2/3/4 lines pay 100/300/600/1000; every line past the fourth adds
  /// another [extraLineBonus], so 5 lines pay 1500 and 6 lines pay 2000.
  static int lineClearBonus(int lineCount) {
    if (lineCount <= 0) return 0;
    if (lineCount < lineBonusTable.length) return lineBonusTable[lineCount];
    return lineBonusTable.last + (lineCount - 4) * extraLineBonus;
  }

  /// Bonus for being on combo step [combo].
  ///
  /// The first clear of a streak pays nothing; each further one adds
  /// [comboStepBonus].
  static int comboBonus(int combo) => math.max(0, combo - 1) * comboStepBonus;

  /// Total points for one placement.
  static int turnScore({
    required int cellCount,
    required int lineCount,
    required int combo,
  }) =>
      placementScore(cellCount) + lineClearBonus(lineCount) + comboBonus(combo);

  /// The combo step after a placement that cleared [lineCount] lines.
  ///
  /// A placement that clears nothing breaks the streak.
  static int nextCombo(int currentCombo, int lineCount) =>
      lineCount > 0 ? currentCombo + 1 : 0;
}
