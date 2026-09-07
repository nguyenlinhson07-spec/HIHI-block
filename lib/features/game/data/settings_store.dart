import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the player's sound and vibration preferences.
abstract class SettingsStore {
  Future<bool> loadSound();
  Future<bool> loadVibration();
  Future<void> saveSound(bool enabled);
  Future<void> saveVibration(bool enabled);
}

/// Shared-preferences backed settings.
class SharedPreferencesSettingsStore implements SettingsStore {
  const SharedPreferencesSettingsStore();

  /// Storage keys, branded for Hi Hi Block.
  static const String soundKey = 'hihiblock_sound_enabled';
  static const String vibrationKey = 'hihiblock_vibration_enabled';

  /// Both settings start switched on.
  static const bool defaultSound = true;
  static const bool defaultVibration = true;

  Future<bool> _read(String key, bool fallback) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } on Object catch (error) {
      debugPrint('Could not read $key: $error');
      return fallback;
    }
  }

  Future<void> _write(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Object catch (error) {
      debugPrint('Could not write $key: $error');
    }
  }

  @override
  Future<bool> loadSound() => _read(soundKey, defaultSound);

  @override
  Future<bool> loadVibration() => _read(vibrationKey, defaultVibration);

  @override
  Future<void> saveSound(bool enabled) => _write(soundKey, enabled);

  @override
  Future<void> saveVibration(bool enabled) => _write(vibrationKey, enabled);
}

/// In-memory settings for tests.
@visibleForTesting
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore({this.sound = true, this.vibration = true});

  bool sound;
  bool vibration;

  @override
  Future<bool> loadSound() async => sound;

  @override
  Future<bool> loadVibration() async => vibration;

  @override
  Future<void> saveSound(bool enabled) async => sound = enabled;

  @override
  Future<void> saveVibration(bool enabled) async => vibration = enabled;
}
