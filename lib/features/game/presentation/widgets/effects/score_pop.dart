import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The `+40` that floats up out of the board after a placement.
///
/// It is laid out inside a zero-size overlay so it cannot move the board.
class ScorePop extends StatefulWidget {
  const ScorePop({
    super.key,
    required this.amount,
    required this.onDone,
    this.emphasised = false,
  });

  /// Points the placement was worth — straight from `lastTurn.scoreGained`.
  final int amount;

  /// Bigger and gold when the placement also cleared lines.
  final bool emphasised;

  final VoidCallback onDone;

  static const Duration duration = Duration(milliseconds: 620);

  @override
  State<ScorePop> createState() => _ScorePopState();
}

class _ScorePopState extends State<ScorePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ScorePop.duration,
  )..forward().whenCompleteOrCancel(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value;
            final double rise = Curves.easeOutCubic.transform(t);
            final double fade = t < 0.25
                ? t /
                      0.25 // ease in
                : 1 - ((t - 0.25) / 0.75); // then out
            final double pop = t < 0.2
                ? 0.8 + 0.2 * (t / 0.2)
                : 1.0 + 0.05 * (1 - t);

            return Transform.translate(
              offset: Offset(0, -34 * rise),
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(scale: pop, child: child),
              ),
            );
          },
          child: Text(
            '+${widget.amount}',
            style: TextStyle(
              color: widget.emphasised ? AppColors.gold : AppColors.textPrimary,
              fontSize: widget.emphasised ? 24 : 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: const <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
