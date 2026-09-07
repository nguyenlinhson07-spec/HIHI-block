import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/features/game/logic/score_system.dart';

void main() {
  group('placement score', () {
    test('8. is 10 points per placed cell', () {
      expect(ScoreSystem.placementScore(1), 10);
      expect(ScoreSystem.placementScore(2), 20);
      expect(ScoreSystem.placementScore(3), 30);
      expect(ScoreSystem.placementScore(4), 40);
      expect(ScoreSystem.placementScore(5), 50);
      expect(ScoreSystem.placementScore(0), 0);
    });
  });

  group('line clear bonus', () {
    test('no lines pays nothing', () {
      expect(ScoreSystem.lineClearBonus(0), 0);
      expect(ScoreSystem.lineClearBonus(-1), 0);
    });

    test('9. one line pays 100', () {
      expect(ScoreSystem.lineClearBonus(1), 100);
    });

    test('10. two lines pay 300', () {
      expect(ScoreSystem.lineClearBonus(2), 300);
    });

    test('11. three lines pay 600', () {
      expect(ScoreSystem.lineClearBonus(3), 600);
    });

    test('12. four lines pay 1000', () {
      expect(ScoreSystem.lineClearBonus(4), 1000);
    });

    test('13. every line past the fourth adds 500', () {
      expect(ScoreSystem.lineClearBonus(5), 1500);
      expect(ScoreSystem.lineClearBonus(6), 2000);
      expect(ScoreSystem.lineClearBonus(7), 2500);
      expect(ScoreSystem.lineClearBonus(8), 3000);
      // The theoretical maximum: all 8 rows and all 8 columns.
      expect(ScoreSystem.lineClearBonus(16), 1000 + 12 * 500);
    });
  });

  group('combo bonus', () {
    test('17. the first clear of a streak pays no combo bonus', () {
      expect(ScoreSystem.comboBonus(0), 0);
      expect(ScoreSystem.comboBonus(1), 0);
    });

    test('17. each further clear adds 50', () {
      expect(ScoreSystem.comboBonus(2), 50);
      expect(ScoreSystem.comboBonus(3), 100);
      expect(ScoreSystem.comboBonus(4), 150);
      expect(ScoreSystem.comboBonus(10), 450);
    });
  });

  group('combo streak', () {
    test('a clear advances the streak', () {
      expect(ScoreSystem.nextCombo(0, 1), 1);
      expect(ScoreSystem.nextCombo(1, 2), 2);
      expect(ScoreSystem.nextCombo(5, 1), 6);
    });

    test('16. a placement without a clear breaks the streak', () {
      expect(ScoreSystem.nextCombo(0, 0), 0);
      expect(ScoreSystem.nextCombo(7, 0), 0);
    });
  });

  group('turn score', () {
    test('sums placement, line bonus and combo bonus', () {
      // 4 cells, 2 lines, third clear in a row.
      expect(
        ScoreSystem.turnScore(cellCount: 4, lineCount: 2, combo: 3),
        40 + 300 + 100,
      );
      // A placement that clears nothing is worth only its cells.
      expect(
        ScoreSystem.turnScore(cellCount: 3, lineCount: 0, combo: 0),
        30,
      );
    });
  });
}
