import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the player's best score.
abstract class BestScoreStore {
  Future<int> load();
  Future<void> save(int value);
}

/// Stores the best score in the platform's shared preferences.
class SharedPreferencesBestScoreStore implements BestScoreStore {
  const SharedPreferencesBestScoreStore();

  /// Storage key. Branded for Hi Hi Block; nothing else reads or writes it.
  static const String key = 'hihiblock_best_score';

  // Persistence is a convenience, never a hard dependency: if the platform
  // channel is unavailable the game still runs, it just forgets the record.

  @override
  Future<int> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key) ?? 0;
    } on Object catch (error) {
      debugPrint('Could not read $key: $error');
      return 0;
    }
  }

  @override
  Future<void> save(int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } on Object catch (error) {
      debugPrint('Could not write $key: $error');
    }
  }
}

/// A store that keeps the value in memory only — used by tests and as a safe
/// fallback when no persistence is wired up.
class InMemoryBestScoreStore implements BestScoreStore {
  InMemoryBestScoreStore([this._value = 0]);

  int _value;

  int get value => _value;

  @override
  Future<int> load() async => _value;

  @override
  Future<void> save(int value) async => _value = value;
}
