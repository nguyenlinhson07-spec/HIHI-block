import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/data/best_score_store.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/combo_badge.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/score_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the app with the predictable Phase-1 trio in the tray, still backed
/// by the real shared-preferences store so BEST behaves as in production.
Future<void> _pump(WidgetTester tester) async {
  final GameController controller = GameController.withState(
    board: GameBoard.empty(),
    tray: BlockShapes.sampleTray(),
    bestScoreStore: const SharedPreferencesBestScoreStore(),
  );
  addTearDown(controller.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HiHiBlockApp(controller: controller));
  await tester.pumpAndSettle();
}

/// Reads the number rendered under [label] in the header.
int _headerValue(WidgetTester tester, String label) => tester
    .widgetList<ScoreBadge>(find.byType(ScoreBadge))
    .firstWhere((ScoreBadge b) => b.label == label)
    .value;

/// Drags the first tray block onto the middle of the board.
Future<void> _dropFirstPiece(WidgetTester tester) async {
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
  await gesture.moveTo(
    board.center + const Offset(0, GameConstants.dragLift),
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('header', () {
    testWidgets('18. SCORE starts at 0 and is not hardcoded', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(_headerValue(tester, 'SCORE'), 0);
      expect(_headerValue(tester, 'BEST'), 0);
    });

    testWidgets('18. SCORE updates right after a placement', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _dropFirstPiece(tester);

      // The 2-cell domino is worth 10 per cell.
      expect(_headerValue(tester, 'SCORE'), 20);
      expect(find.text('20'), findsWidgets);
    });

    testWidgets('19. BEST follows the score up', (WidgetTester tester) async {
      await _pump(tester);
      await _dropFirstPiece(tester);

      expect(_headerValue(tester, 'BEST'), 20);
    });

    testWidgets('21. BEST is restored from storage on start', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesBestScoreStore.key: 4321,
      });

      await _pump(tester);
      // The load is async; pumpAndSettle in _pump already gave it a turn.
      await tester.pumpAndSettle();

      expect(_headerValue(tester, 'BEST'), 4321);
      expect(_headerValue(tester, 'SCORE'), 0);
    });

    testWidgets('20. a restored BEST is not lowered by a small score', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesBestScoreStore.key: 4321,
      });

      await _pump(tester);
      await tester.pumpAndSettle();
      await _dropFirstPiece(tester);

      expect(_headerValue(tester, 'SCORE'), 20);
      expect(_headerValue(tester, 'BEST'), 4321);
    });
  });

  group('ComboBadge', () {
    Future<void> pumpBadge(WidgetTester tester, int combo) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: ComboBadge(combo: combo)))),
    );

    testWidgets('9. stays hidden below combo 2', (WidgetTester tester) async {
      for (final int combo in <int>[0, 1]) {
        await pumpBadge(tester, combo);
        expect(find.textContaining('COMBO'), findsNothing);
      }
    });

    testWidgets('9. shows COMBO xN from combo 2 up', (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, 2);
      expect(find.text('COMBO x2'), findsOneWidget);

      await pumpBadge(tester, 3);
      expect(find.text('COMBO x3'), findsOneWidget);

      await pumpBadge(tester, 7);
      expect(find.text('COMBO x7'), findsOneWidget);
    });

    testWidgets('9. hides again when the streak breaks', (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, 3);
      expect(find.text('COMBO x3'), findsOneWidget);

      await pumpBadge(tester, 0);
      expect(find.textContaining('COMBO'), findsNothing);
    });

    testWidgets('keeps the same height whether visible or not', (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, 0);
      final Size hidden = tester.getSize(find.byType(ComboBadge));

      await pumpBadge(tester, 4);
      expect(tester.getSize(find.byType(ComboBadge)).height, hidden.height);
    });
  });

  _mainCombo();

  group('combo badge on the game screen', () {
    testWidgets('9. is present but empty at the start of a game', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.byType(ComboBadge), findsOneWidget);
      expect(find.textContaining('COMBO'), findsNothing);
    });

    testWidgets('the board does not move when a piece is played', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Rect before = tester.getRect(find.byType(GameBoardView));
      await _dropFirstPiece(tester);
      expect(tester.getRect(find.byType(GameBoardView)), before);
    });
  });
}

/// Board pre-filled with every cell of rows 0, 2 and 4 except column 7.
GameController _almostThreeRows() {
  GameBoard board = GameBoard.empty();
  final BlockPiece seed = BlockPiece(
    id: 'seed',
    cells: const <BlockCell>[BlockCell(0, 0)],
    color: Colors.deepPurpleAccent,
  );
  for (final int row in <int>[0, 2, 4]) {
    for (int column = 0; column < GameConstants.boardSize - 1; column++) {
      board = board.placePiece(seed, row, column);
    }
  }
  final BlockPiece unit = BlockPiece(
    id: 'unit',
    cells: const <BlockCell>[BlockCell(0, 0)],
    color: Colors.cyanAccent,
  );
  return GameController.withState(
    board: board,
    tray: <BlockPiece?>[unit, unit, unit],
  );
}

/// Drags tray preview [index] onto board cell ([row], [column]).
Future<void> _dropOn(
  WidgetTester tester,
  int index,
  int row,
  int column,
) async {
  final Rect board = tester.getRect(find.byType(GameBoardView));
  final BoardGeometry geo = BoardGeometry(side: board.width);
  // Aim the pointer so the 1x1 block lands on the wanted cell, undoing the
  // drag lift and the half-cell centring.
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
  await tester.pumpAndSettle();
}

void _mainCombo() {
  group('combo through the UI', () {
    testWidgets('14./15./9. clearing rows back to back shows COMBO x2', (
      WidgetTester tester,
    ) async {
      final GameController controller = _almostThreeRows();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HiHiBlockApp(controller: controller));
      await tester.pumpAndSettle();

      // First clear: row 0. Combo 1, so no badge yet.
      await _dropOn(tester, 0, 0, 7);
      expect(controller.combo, 1);
      expect(controller.score, 110);
      expect(_headerValue(tester, 'SCORE'), 110);
      expect(find.textContaining('COMBO'), findsNothing);

      // Second clear: row 2. Combo 2, badge appears.
      await _dropOn(tester, 0, 2, 7);
      expect(controller.combo, 2);
      expect(controller.score, 110 + 160);
      expect(_headerValue(tester, 'SCORE'), 270);
      expect(find.text('COMBO x2'), findsOneWidget);

      // The cleared rows are gone; row 4 is still waiting.
      expect(controller.board.cellAt(0, 0).occupied, isFalse);
      expect(controller.board.cellAt(2, 0).occupied, isFalse);
      expect(controller.board.cellAt(4, 0).occupied, isTrue);
      expect(_headerValue(tester, 'BEST'), 270);
    });

    testWidgets('16. a placement that clears nothing hides the badge again', (
      WidgetTester tester,
    ) async {
      final GameController controller = _almostThreeRows();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HiHiBlockApp(controller: controller));
      await tester.pumpAndSettle();

      await _dropOn(tester, 0, 0, 7);
      await _dropOn(tester, 0, 2, 7);
      expect(find.text('COMBO x2'), findsOneWidget);

      // Drop into open space: streak broken.
      await _dropOn(tester, 0, 6, 3);
      expect(controller.combo, 0);
      expect(find.textContaining('COMBO'), findsNothing);
      expect(controller.score, 270 + 10);
      expect(_headerValue(tester, 'SCORE'), 280);
    });
  });
}
