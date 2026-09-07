import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Full-screen panel shown when no piece in the tray fits anywhere.
///
/// Fades in with a small settle — no cinematic — and the button is live from
/// the first frame, so a fast player is never held up by the animation.
///
/// The card scrolls if a very short screen cannot fit it, so the overlay never
/// overflows.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.onPlayAgain,
  });

  final int score;
  final int bestScore;
  final VoidCallback onPlayAgain;

  /// How long the overlay takes to settle in.
  static const Duration duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOut,
        builder: (BuildContext context, double t, Widget? child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
        ),
        child: _buildPanel(context),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundBottom.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.boardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.boardBorder),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'GAME OVER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Stat(label: 'SCORE', value: score, color: AppColors.accent),
                  const SizedBox(height: 16),
                  _Stat(label: 'BEST', value: bestScore, color: AppColors.gold),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPlayAgain,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
