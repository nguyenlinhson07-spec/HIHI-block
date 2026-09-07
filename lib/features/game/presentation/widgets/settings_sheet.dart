import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/game_settings.dart';

/// Sound and vibration switches.
///
/// Changes apply immediately and are written to storage by [GameSettings], so
/// nothing here needs a save button.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.settings});

  final GameSettings settings;

  static Future<void> show(BuildContext context, GameSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => SettingsSheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) => Container(
        decoration: const BoxDecoration(
          color: AppColors.boardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.boardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SETTINGS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              _SettingRow(
                icon: Icons.volume_up,
                label: 'Sound',
                value: settings.soundEnabled,
                onChanged: settings.setSoundEnabled,
              ),
              _SettingRow(
                icon: Icons.vibration,
                label: 'Vibration',
                value: settings.vibrationEnabled,
                onChanged: settings.setVibrationEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.accent,
      secondary: Icon(icon, color: AppColors.textSoft),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
