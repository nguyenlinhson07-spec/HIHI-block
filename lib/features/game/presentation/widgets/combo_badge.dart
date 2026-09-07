import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Minimal combo readout shown just under the board.
///
/// The widget always occupies its slot — it only hides its label — so the
/// board never shifts when a streak starts or breaks. Each new streak step
/// pops the label briefly, and a longer streak pops slightly bigger.
class ComboBadge extends StatelessWidget {
  const ComboBadge({super.key, required this.combo, this.height = 22});

  final int combo;
  final double height;

  /// A streak is only worth announcing from the second clear on.
  static const int minimumVisibleCombo = 2;

  @override
  Widget build(BuildContext context) {
    final bool visible = combo >= minimumVisibleCombo;
    // Grows a little with the streak, but capped so it never crowds the board.
    final double emphasis = visible
        ? (1.0 + 0.04 * (combo - minimumVisibleCombo)).clamp(1.0, 1.2)
        : 1.0;

    return SizedBox(
      height: height,
      child: Center(
        child: visible
            ? TweenAnimationBuilder<double>(
                // Keyed on the streak value, so every step replays the pop.
                key: ValueKey<int>(combo),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (BuildContext context, double t, Widget? child) =>
                    Transform.scale(
                      scale: emphasis * (0.7 + 0.3 * t),
                      child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    'COMBO x$combo',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
