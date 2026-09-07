import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A small labelled score readout used for BEST and SCORE in the header.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final int value;
  final CrossAxisAlignment alignment;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSoft,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
            // Fixed-width digits: without these the score shifts sideways as
            // it counts up, because a 1 is narrower than a 0 in the default
            // proportional face.
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
