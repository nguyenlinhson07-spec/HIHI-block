import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/features/game/data/settings_store.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/logic/game_settings.dart';
import 'package:hihi_block/features/game/presentation/widgets/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('13. settings persistence', () {
    test('both switches default to on', () async {
      final GameSettings settings = GameSettings(
        store: const SharedPreferencesSettingsStore(),
      );
      expect(settings.soundEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);

      await settings.load();
      expect(settings.soundEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);
      settings.dispose();
    });

    test('14./15. the branded keys are the ones actually used', () async {
      expect(
        SharedPreferencesSettingsStore.soundKey,
        'hihiblock_sound_enabled',
      );
      expect(
        SharedPreferencesSettingsStore.vibrationKey,
        'hihiblock_vibration_enabled',
      );

      final GameSettings settings = GameSettings(
        store: const SharedPreferencesSettingsStore(),
      );
      settings.setSoundEnabled(false);
      settings.setVibrationEnabled(false);
      await Future<void>.delayed(Duration.zero);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hihiblock_sound_enabled'), isFalse);
      expect(prefs.getBool('hihiblock_vibration_enabled'), isFalse);
      // The old BlockJoy keys are never written.
      expect(prefs.getBool('blockjoy_sound_enabled'), isNull);
      expect(prefs.getBool('blockjoy_vibration_enabled'), isNull);
      settings.dispose();
    });

    test('13. stored values are restored on the next launch', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesSettingsStore.soundKey: false,
        SharedPreferencesSettingsStore.vibrationKey: true,
      });

      final GameSettings settings = GameSettings(
        store: const SharedPreferencesSettingsStore(),
      );
      await settings.load();

      expect(settings.soundEnabled, isFalse);
      expect(settings.vibrationEnabled, isTrue);
      settings.dispose();
    });

    test('a change notifies listeners exactly once', () {
      final GameSettings settings = GameSettings(
        store: InMemorySettingsStore(),
      );
      int notifications = 0;
      settings.addListener(() => notifications++);

      settings.setSoundEnabled(false);
      expect(notifications, 1);
      // Setting the same value again is a no-op.
      settings.setSoundEnabled(false);
      expect(notifications, 1);

      settings.setVibrationEnabled(false);
      expect(notifications, 2);
      settings.dispose();
    });

    test('a change is written through immediately', () async {
      final InMemorySettingsStore store = InMemorySettingsStore();
      final GameSettings settings = GameSettings(store: store);

      settings.setSoundEnabled(false);
      settings.setVibrationEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(store.sound, isFalse);
      expect(store.vibration, isFalse);
      settings.dispose();
    });
  });

  group('settings sheet', () {
    Future<GameSettings> pumpGame(
      WidgetTester tester,
      GameSettings settings,
    ) async {
      final GameController controller = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        HiHiBlockApp(controller: controller, settings: settings),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('the settings button opens real switches', (
      WidgetTester tester,
    ) async {
      final GameSettings settings = GameSettings(
        store: InMemorySettingsStore(),
      );
      addTearDown(settings.dispose);
      await pumpGame(tester, settings);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsSheet), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('toggling sound updates the settings and the store', (
      WidgetTester tester,
    ) async {
      final InMemorySettingsStore store = InMemorySettingsStore();
      final GameSettings settings = GameSettings(store: store);
      addTearDown(settings.dispose);
      await pumpGame(tester, settings);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sound'));
      await tester.pumpAndSettle();

      expect(settings.soundEnabled, isFalse);
      expect(store.sound, isFalse);
      // Vibration is untouched.
      expect(settings.vibrationEnabled, isTrue);
    });

    testWidgets('toggling vibration updates the settings and the store', (
      WidgetTester tester,
    ) async {
      final InMemorySettingsStore store = InMemorySettingsStore();
      final GameSettings settings = GameSettings(store: store);
      addTearDown(settings.dispose);
      await pumpGame(tester, settings);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vibration'));
      await tester.pumpAndSettle();

      expect(settings.vibrationEnabled, isFalse);
      expect(store.vibration, isFalse);
      expect(settings.soundEnabled, isTrue);
    });

    testWidgets('the sheet shows what was restored from storage', (
      WidgetTester tester,
    ) async {
      final GameSettings settings = GameSettings(
        store: InMemorySettingsStore(sound: false, vibration: true),
      );
      addTearDown(settings.dispose);
      await settings.load();
      await pumpGame(tester, settings);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      final List<Switch> switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches.map((Switch s) => s.value), <bool>[false, true]);
    });
  });
}
