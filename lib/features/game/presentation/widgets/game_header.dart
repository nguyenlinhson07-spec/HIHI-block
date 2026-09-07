import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'score_badge.dart';

/// Top bar: BEST on the left, the logo in the middle, SCORE on the right.
class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.score, required this.bestScore});

  final int score;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: ScoreBadge(
            label: 'BEST',
            value: bestScore,
            valueColor: AppColors.gold,
          ),
        ),
        const _GameLogo(),
        Expanded(
          child: ScoreBadge(
            label: 'SCORE',
            value: score,
            alignment: CrossAxisAlignment.end,
            valueColor: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        Text(
          'HI HI',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            height: 1.05,
          ),
        ),
        Text(
          'BLOCK',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}
