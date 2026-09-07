import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theme for the app.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundBottom,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
        labelSmall: TextStyle(
          color: AppColors.textSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
