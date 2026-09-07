import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sounds the game can play.
enum GameSound {
  place('audio/place.wav'),
  invalid('audio/invalid.wav'),
  clear('audio/clear.wav'),
  combo('audio/combo.wav'),
  gameOver('audio/game_over.wav');

  const GameSound(this.asset);

  /// Path under `assets/`, as [AssetSource] expects it.
  final String asset;
}

/// Plays the game's sound effects.
///
/// Widgets never talk to an audio package directly — they hand a [GameSound]
/// to this, and the implementation decides how (or whether) to make noise.
abstract class GameAudio {
  /// Warms up the players so the first sound is not late.
  Future<void> preload();

  /// Plays [sound], cutting off any previous instance of the same sound.
  void play(GameSound sound);

  Future<void> dispose();
}

/// A [GameAudio] that does nothing — the default in tests and the fallback
/// when audio cannot be initialised.
class SilentGameAudio implements GameAudio {
  const SilentGameAudio();

  @override
  Future<void> preload() async {}

  @override
  void play(GameSound sound) {}

  @override
  Future<void> dispose() async {}
}

/// Real playback, backed by `audioplayers`.
///
/// One player is kept per sound and reused for the life of the app, so
/// nothing allocates a player mid-game.
class AudioPlayersGameAudio implements GameAudio {
  AudioPlayersGameAudio();

  final Map<GameSound, AudioPlayer> _players = <GameSound, AudioPlayer>{};
  bool _available = true;

  @override
  Future<void> preload() async {
    for (final GameSound sound in GameSound.values) {
      try {
        final AudioPlayer player = AudioPlayer(playerId: 'hihi-${sound.name}')
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource(sound.asset));
        _players[sound] = player;
      } on Object catch (error) {
        // Audio is a nicety, never a requirement: a device or platform that
        // cannot load it simply plays nothing.
        debugPrint('Could not preload ${sound.asset}: $error');
        _available = false;
        return;
      }
    }
  }

  @override
  void play(GameSound sound) {
    if (!_available) return;
    final AudioPlayer? player = _players[sound];
    if (player == null) return;

    // Restart rather than layer: two clears in a row should not stack.
    unawaited(
      player.seek(Duration.zero).then((_) => player.resume()).catchError((
        Object error,
      ) {
        debugPrint('Could not play ${sound.asset}: $error');
      }),
    );
  }

  @override
  Future<void> dispose() async {
    for (final AudioPlayer player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// Records what was asked for instead of playing it. Test-only.
@visibleForTesting
class RecordingGameAudio implements GameAudio {
  final List<GameSound> played = <GameSound>[];
  int preloadCount = 0;

  @override
  Future<void> preload() async => preloadCount++;

  @override
  void play(GameSound sound) => played.add(sound);

  @override
  Future<void> dispose() async {}
}
