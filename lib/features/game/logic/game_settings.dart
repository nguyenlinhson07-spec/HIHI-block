import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';

/// The player's sound and vibration switches.
///
/// Both default to on and are written back as soon as they change, so the
/// choice survives a restart.
class GameSettings extends ChangeNotifier {
  GameSettings({SettingsStore? store})
    : _store = store ?? const SharedPreferencesSettingsStore();

  final SettingsStore _store;

  bool _soundEnabled = SharedPreferencesSettingsStore.defaultSound;
  bool _vibrationEnabled = SharedPreferencesSettingsStore.defaultVibration;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// Reads both switches back from storage.
  Future<void> load() async {
    final bool sound = await _store.loadSound();
    final bool vibration = await _store.loadVibration();
    if (sound == _soundEnabled && vibration == _vibrationEnabled) return;
    _soundEnabled = sound;
    _vibrationEnabled = vibration;
    notifyListeners();
  }

  void setSoundEnabled(bool enabled) {
    if (_soundEnabled == enabled) return;
    _soundEnabled = enabled;
    _store.saveSound(enabled);
    notifyListeners();
  }

  void setVibrationEnabled(bool enabled) {
    if (_vibrationEnabled == enabled) return;
    _vibrationEnabled = enabled;
    _store.saveVibration(enabled);
    notifyListeners();
  }
}
