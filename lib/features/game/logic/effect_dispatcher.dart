import '../../../core/audio/game_audio.dart';
import '../../../core/haptics/game_haptics.dart';
import '../domain/models/game_effect.dart';
import 'game_settings.dart';

/// Turns a [GameEffect] into sound and haptics, honouring the player's
/// settings.
///
/// Both switches are checked here and nowhere else, so there is exactly one
/// place that can get "sound is off" wrong.
class EffectDispatcher {
  const EffectDispatcher({
    required this.audio,
    required this.haptics,
    required this.settings,
  });

  final GameAudio audio;
  final GameHaptics haptics;
  final GameSettings settings;

  void dispatch(GameEffect effect) {
    _playSound(effect);
    _fireHaptic(effect);
  }

  void _playSound(GameEffect effect) {
    if (!settings.soundEnabled) return;
    switch (effect.type) {
      case GameEffectType.dragStarted:
        // Picking a block up is silent on purpose — a sound on every touch
        // gets tiring fast.
        break;
      case GameEffectType.placed:
        audio.play(GameSound.place);
      case GameEffectType.invalid:
        audio.play(GameSound.invalid);
      case GameEffectType.cleared:
        audio.play(GameSound.clear);
      case GameEffectType.combo:
        audio.play(GameSound.combo);
      case GameEffectType.gameOver:
        audio.play(GameSound.gameOver);
    }
  }

  void _fireHaptic(GameEffect effect) {
    if (!settings.vibrationEnabled) return;
    switch (effect.type) {
      case GameEffectType.dragStarted:
        // One tick when the block leaves the tray. Pointer moves never fire.
        haptics.impact(HapticStrength.selection);
      case GameEffectType.placed:
        haptics.impact(HapticStrength.light);
      case GameEffectType.invalid:
        haptics.impact(HapticStrength.selection);
      case GameEffectType.cleared:
        haptics.impact(HapticStrength.medium);
      case GameEffectType.combo:
        // The clear already fired; a second light tap makes a streak read as
        // bigger without turning into a buzz.
        haptics.impact(HapticStrength.light);
      case GameEffectType.gameOver:
        haptics.impact(HapticStrength.selection);
    }
  }
}
