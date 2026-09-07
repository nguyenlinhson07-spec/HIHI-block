import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/audio/game_audio.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/core/haptics/game_haptics.dart';
import 'package:hihi_block/features/game/data/settings_store.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/logic/game_settings.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/combo_badge.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/clear_burst.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/place_pulse.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/return_ghost.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/score_pop.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_over_overlay.dart';

const int _size = GameConstants.boardSize;

const List<Size> _phoneSizes = <Size>[
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
];

BlockPiece _unit() => BlockShapes.single.toPiece(Colors.cyan);

GameBoard _boardWith(Iterable<BlockCell> cells) {
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(_unit(), c.row, c.column);
  }
  return board;
}

Iterable<BlockCell> _row(int row, {Set<int> gaps = const <int>{}}) sync* {
  for (int c = 0; c < _size; c++) {
    if (!gaps.contains(c)) yield BlockCell(row, c);
  }
}

Set<BlockCell> _isolatedHoles() => <BlockCell>{
  for (int r = 0; r < _size; r++) ...<BlockCell>[
    BlockCell(r, (3 * r) % _size),
    BlockCell(r, (3 * r + 4) % _size),
  ],
};

Iterable<BlockCell> _allExcept(Set<BlockCell> free) sync* {
  for (int r = 0; r < _size; r++) {
    for (int c = 0; c < _size; c++) {
      if (!free.contains(BlockCell(r, c))) yield BlockCell(r, c);
    }
  }
}

/// One harness for every widget test here: a prepared board, recording audio
/// and haptics, and both switches on unless told otherwise.
class _Harness {
  _Harness({
    required this.controller,
    required this.audio,
    required this.haptics,
    required this.settings,
  });

  final GameController controller;
  final RecordingGameAudio audio;
  final RecordingGameHaptics haptics;
  final GameSettings settings;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  GameBoard? board,
  List<BlockPiece?>? tray,
  Size size = const Size(390, 844),
  bool sound = true,
  bool vibration = true,
}) async {
  final GameController controller = GameController.withState(
    board: board ?? GameBoard.empty(),
    tray: tray ?? BlockShapes.sampleTray(),
  );
  final RecordingGameAudio audio = RecordingGameAudio();
  final RecordingGameHaptics haptics = RecordingGameHaptics();
  final GameSettings settings =
      GameSettings(
          store: InMemorySettingsStore(sound: sound, vibration: vibration),
        )
        ..setSoundEnabled(sound)
        ..setVibrationEnabled(vibration);

  addTearDown(controller.dispose);
  addTearDown(settings.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    HiHiBlockApp(
      controller: controller,
      settings: settings,
      audio: audio,
      haptics: haptics,
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    controller: controller,
    audio: audio,
    haptics: haptics,
    settings: settings,
  );
}

/// Drags tray preview [index] onto board cell ([row], [column]).
Future<void> _dropOn(
  WidgetTester tester,
  int index,
  int row,
  int column, {
  bool settle = true,
}) async {
  final Rect board = tester.getRect(find.byType(GameBoardView));
  final BoardGeometry geo = BoardGeometry(side: board.width);
  final Offset target =
      board.topLeft +
      geo.originOf(row, column) +
      Offset(geo.cellSize / 2, geo.cellSize / 2 + GameConstants.dragLift);

  final Offset slot = tester.getCenter(
    find
        .descendant(
          of: find.byType(BlockTray),
          matching: find.byType(BlockPieceView),
        )
        .at(index),
  );
  final TestGesture gesture = await tester.startGesture(slot);
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

void main() {
  group('place animation', () {
    testWidgets('a landing block pulses, then the pulse is gone', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _dropOn(tester, 0, 3, 3, settle: false);

      expect(find.byType(PlacePulse), findsOneWidget);

      // Halfway through it is still on screen...
      await tester.pump(PlacePulse.duration ~/ 2);
      expect(find.byType(PlacePulse), findsOneWidget);

      // ...and afterwards it has taken itself away.
      await tester.pumpAndSettle();
      expect(find.byType(PlacePulse), findsNothing);
    });

    testWidgets('22. the score pop shows exactly what the turn was worth', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(tester);
      await _dropOn(tester, 0, 3, 3, settle: false);

      expect(find.byType(ScorePop), findsOneWidget);
      final ScorePop pop = tester.widget<ScorePop>(find.byType(ScorePop));
      expect(pop.amount, h.controller.lastTurn!.scoreGained);
      expect(pop.amount, 20);
      expect(find.text('+20'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ScorePop), findsNothing);
    });

    testWidgets('21. every effect widget is gone once it finishes', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      await _dropOn(tester, 0, 0, 7, settle: false);
      expect(find.byType(PlacePulse), findsOneWidget);
      expect(find.byType(ClearBurst), findsOneWidget);
      expect(find.byType(ScorePop), findsOneWidget);

      await tester.pumpAndSettle();

      // Nothing lingers: no controllers, no particles, no text.
      expect(find.byType(PlacePulse), findsNothing);
      expect(find.byType(ClearBurst), findsNothing);
      expect(find.byType(ScorePop), findsNothing);
      expect(find.byType(ReturnGhost), findsNothing);
    });
  });

  group('invalid animation', () {
    testWidgets('a rejected block glides back and leaves no trace', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(tester);

      // Release well below the board, over the tray.
      final Offset slot = tester.getCenter(
        find
            .descendant(
              of: find.byType(BlockTray),
              matching: find.byType(BlockPieceView),
            )
            .at(0),
      );
      final TestGesture gesture = await tester.startGesture(slot);
      await tester.pump();
      await gesture.moveTo(slot + const Offset(30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byType(ReturnGhost), findsOneWidget);
      expect(h.audio.played, contains(GameSound.invalid));

      await tester.pumpAndSettle();
      expect(find.byType(ReturnGhost), findsNothing);
      // The board never changed.
      expect(h.controller.board.occupiedCount, 0);
      expect(h.controller.tray[0], isNotNull);
      expect(h.controller.score, 0);
    });
  });

  group('clear animation', () {
    testWidgets('cells keep animating after the board has already cleared', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(
        tester,
        board: _boardWith(_row(2, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      await _dropOn(tester, 0, 2, 7, settle: false);

      // The domain is already final...
      expect(h.controller.board.occupiedCount, 0);
      // ...while the burst is still on screen showing what was taken.
      final ClearBurst burst = tester.widget<ClearBurst>(
        find.byType(ClearBurst),
      );
      expect(burst.cells.length, _size);
      expect(burst.lineCount, 1);

      await tester.pumpAndSettle();
      expect(find.byType(ClearBurst), findsNothing);
    });

    testWidgets('4./5. a row and a column animate as one burst', (
      WidgetTester tester,
    ) async {
      // Row 3 and column 5 both finish on cell (3, 5).
      final Set<BlockCell> seeded = <BlockCell>{
        for (int c = 0; c < _size; c++)
          if (c != 5) BlockCell(3, c),
        for (int r = 0; r < _size; r++)
          if (r != 3) BlockCell(r, 5),
      };
      await _pump(
        tester,
        board: _boardWith(seeded),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      await _dropOn(tester, 0, 3, 5, settle: false);

      // One burst, not one per line, and the intersection appears once.
      expect(find.byType(ClearBurst), findsOneWidget);
      final ClearBurst burst = tester.widget<ClearBurst>(
        find.byType(ClearBurst),
      );
      expect(burst.lineCount, 2);
      expect(burst.cells.length, _size + _size - 1);
      expect(burst.cells.toSet().length, burst.cells.length);

      await tester.pumpAndSettle();
    });

    test('6. more lines mean more particles, within bounds', () {
      expect(ClearBurst.particleCountFor(1), inInclusiveRange(8, 12));
      expect(ClearBurst.particleCountFor(2), inInclusiveRange(12, 18));
      expect(ClearBurst.particleCountFor(3), inInclusiveRange(18, 28));
      expect(ClearBurst.particleCountFor(6), inInclusiveRange(18, 28));

      expect(
        ClearBurst.particleCountFor(2),
        greaterThan(ClearBurst.particleCountFor(1)),
      );
      expect(
        ClearBurst.particleCountFor(3),
        greaterThan(ClearBurst.particleCountFor(2)),
      );
    });
  });

  group('8. rebuilds never replay an effect', () {
    testWidgets('pumping frames after a placement plays nothing more', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(tester);

      await _dropOn(tester, 0, 3, 3);
      final int soundsAfterDrop = h.audio.played.length;
      final int hapticsAfterDrop = h.haptics.impacts.length;
      expect(h.audio.played, contains(GameSound.place));

      // Force many rebuilds: resizing, settling, tapping around.
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GameBoardView), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.audio.played.length, soundsAfterDrop);
      expect(h.haptics.impacts.length, hapticsAfterDrop);
    });

    testWidgets('16. play again does not replay the game over sound', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(
        tester,
        board: _boardWith(_allExcept(_isolatedHoles())),
        tray: <BlockPiece?>[
          _unit(),
          BlockShapes.square2.toPiece(Colors.green),
          BlockShapes.line5H.toPiece(Colors.amber),
        ],
      );

      await _dropOn(tester, 0, 0, 0);
      expect(h.controller.isGameOver, isTrue);
      expect(
        h.audio.played.where((GameSound s) => s == GameSound.gameOver).length,
        1,
      );

      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverOverlay), findsNothing);
      expect(
        h.audio.played.where((GameSound s) => s == GameSound.gameOver).length,
        1,
        reason: 'restarting must not sound like losing again',
      );
    });
  });

  group('9.-12. settings gate the feedback', () {
    testWidgets('sound off plays nothing while a placement still works', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(tester, sound: false);
      await _dropOn(tester, 0, 3, 3);

      expect(h.audio.played, isEmpty);
      expect(h.haptics.impacts, isNotEmpty);
      expect(h.controller.board.occupiedCount, 2);
      expect(h.controller.score, 20);
    });

    testWidgets('vibration off fires no haptics', (WidgetTester tester) async {
      final _Harness h = await _pump(tester, vibration: false);
      await _dropOn(tester, 0, 3, 3);

      expect(h.haptics.impacts, isEmpty);
      expect(h.audio.played, isNotEmpty);
    });

    testWidgets('15. dragging across cells does not spam haptics', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(tester);

      final Rect board = tester.getRect(find.byType(GameBoardView));
      final Offset slot = tester.getCenter(
        find
            .descendant(
              of: find.byType(BlockTray),
              matching: find.byType(BlockPieceView),
            )
            .at(0),
      );

      final TestGesture gesture = await tester.startGesture(slot);
      await tester.pump();
      final int afterPickUp = h.haptics.impacts.length;

      // Sweep across the whole board: many preview changes, no extra buzz.
      for (int i = 0; i < 24; i++) {
        await gesture.moveTo(
          board.topLeft + Offset(20.0 + i * 12, board.height / 2),
        );
        await tester.pump();
      }
      expect(h.haptics.impacts.length, afterPickUp);
      expect(h.audio.played, isEmpty, reason: 'dragging is silent');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('animation never touches the game state', () {
    testWidgets('17./18./19./20. board, score, combo and BEST hold still', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(
        tester,
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{7}),
          ..._row(2, gaps: <int>{7}),
        }),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      await _dropOn(tester, 0, 0, 7);
      await _dropOn(tester, 0, 2, 7);

      final int occupied = h.controller.board.occupiedCount;
      final int score = h.controller.score;
      final int combo = h.controller.combo;
      final int best = h.controller.bestScore;
      expect(combo, 2);

      // Run well past every animation duration.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(h.controller.board.occupiedCount, occupied);
      expect(h.controller.score, score);
      expect(h.controller.combo, combo);
      expect(h.controller.bestScore, best);
    });

    testWidgets('a disposed screen mid-animation leaves the state intact', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(
        tester,
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      await _dropOn(tester, 0, 0, 7, settle: false);
      expect(find.byType(ClearBurst), findsOneWidget);

      final int score = h.controller.score;
      final int occupied = h.controller.board.occupiedCount;

      // Tear the whole tree down while the burst is still running.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(h.controller.score, score);
      expect(h.controller.board.occupiedCount, occupied);
      expect(h.controller.combo, 1);
    });
  });

  group('23.-26. layout is unchanged by the effects', () {
    for (final Size size in _phoneSizes) {
      testWidgets(
        'no overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
          await _pump(
            tester,
            size: size,
            board: _boardWith(<BlockCell>{
              ..._row(0, gaps: <int>{7}),
              ..._row(2, gaps: <int>{7}),
            }),
            tray: <BlockPiece?>[_unit(), _unit(), _unit()],
          );

          final Rect boardBefore = tester.getRect(find.byType(GameBoardView));

          await _dropOn(tester, 0, 0, 7, settle: false);
          // Mid-animation, with a burst, a pulse and a pop all on screen.
          expect(tester.takeException(), isNull);
          expect(tester.getRect(find.byType(GameBoardView)), boardBefore);

          await tester.pumpAndSettle();
          await _dropOn(tester, 0, 2, 7, settle: false);
          // 23. the combo badge appearing must not move the board either.
          expect(find.text('COMBO x2'), findsOneWidget);
          expect(tester.getRect(find.byType(GameBoardView)), boardBefore);

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getRect(find.byType(GameBoardView)), boardBefore);

          final Size boardSize = boardBefore.size;
          expect(boardSize.width, closeTo(boardSize.height, 0.5));
        },
      );
    }

    testWidgets('23. the combo badge keeps its height as the streak changes', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final double hidden = tester.getSize(find.byType(ComboBadge)).height;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: ComboBadge(combo: 5))),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ComboBadge)).height, hidden);
    });
  });

  group('18. game over overlay settles in', () {
    testWidgets('fades in and the button works from the first frame', (
      WidgetTester tester,
    ) async {
      final _Harness h = await _pump(
        tester,
        board: _boardWith(_allExcept(_isolatedHoles())),
        tray: <BlockPiece?>[
          _unit(),
          BlockShapes.square2.toPiece(Colors.green),
          BlockShapes.line5H.toPiece(Colors.amber),
        ],
      );

      await _dropOn(tester, 0, 0, 0, settle: false);
      expect(find.byType(GameOverOverlay), findsOneWidget);

      // Part-way through the fade the panel is not yet fully opaque.
      await tester.pump(const Duration(milliseconds: 60));
      final Opacity fading = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GameOverOverlay),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(fading.opacity, lessThan(1.0));
      expect(fading.opacity, greaterThan(0.0));

      // Even so, PLAY AGAIN responds immediately.
      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pumpAndSettle();
      expect(h.controller.isGameOver, isFalse);
      expect(find.byType(GameOverOverlay), findsNothing);
    });
  });
}
