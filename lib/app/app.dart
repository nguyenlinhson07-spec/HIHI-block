import 'package:flutter/material.dart';

import '../core/audio/game_audio.dart';
import '../core/haptics/game_haptics.dart';
import '../core/theme/app_theme.dart';
import '../features/game/logic/game_controller.dart';
import '../features/game/logic/game_settings.dart';
import '../features/game/presentation/screens/game_screen.dart';

/// Root widget of Hi Hi Block.
class HiHiBlockApp extends StatelessWidget {
  const HiHiBlockApp({
    super.key,
    this.controller,
    this.settings,
    this.audio,
    this.haptics,
  });

  /// Optional session state, for tests that need a prepared board.
  final GameController? controller;

  /// Optional settings, for tests that need specific switches.
  final GameSettings? settings;

  /// Sound and haptic outputs. Left null in tests, where the screen falls
  /// back to silent implementations.
  final GameAudio? audio;
  final GameHaptics? haptics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hi Hi Block',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: GameScreen(
        controller: controller,
        settings: settings,
        audio: audio,
        haptics: haptics,
      ),
    );
  }
}
