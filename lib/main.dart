import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/audio/game_audio.dart';
import 'core/haptics/game_haptics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Warm the players up before the first block lands, so the first place
  // sound is not late. Failures here are already swallowed — the game runs
  // silently rather than not at all.
  final AudioPlayersGameAudio audio = AudioPlayersGameAudio();
  await audio.preload();

  runApp(HiHiBlockApp(audio: audio, haptics: const SystemGameHaptics()));
}
