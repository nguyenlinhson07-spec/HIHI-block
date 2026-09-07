import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Small round settings button shown in the bottom-right of the play area.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.trayBackground,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Settings',
        iconSize: 20,
        color: AppColors.textSoft,
        icon: const Icon(Icons.settings),
      ),
    );
  }
}
