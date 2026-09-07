@Tags(<String>['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/logic/game_settings.dart';
import 'package:hihi_block/features/game/data/settings_store.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/clear_burst.dart';
import 'package:hihi_block/features/game/presentation/widgets/effects/place_pulse.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_over_overlay.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';

/// Renders the game screen into `test/screenshot/goldens/`.
/// Run with: flutter test --update-goldens --tags screenshot test/screenshot
Future<void> _pump(WidgetTester tester, {GameController? controller}) async {
  final GameController session =
      controller ??
      GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
  addTearDown(session.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HiHiBlockApp(controller: session));
  await tester.pumpAndSettle();
}

Offset _slotCenter(WidgetTester tester, int index) => tester.getCenter(
  find
      .descendant(
        of: find.byType(BlockTray),
        matching: find.byType(BlockPieceView),
      )
      .at(index),
);

void main() {
  testWidgets('idle board', (WidgetTester tester) async {
    await _pump(tester);
    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/game_screen.png'),
    );
  });

  testWidgets('valid drag preview', (WidgetTester tester) async {
    await _pump(tester);
    final Rect board = tester.getRect(find.byType(GameBoardView));

    final TestGesture gesture = await tester.startGesture(
      _slotCenter(tester, 2),
    );
    await tester.pump();
    await gesture.moveTo(
      board.center + const Offset(0, GameConstants.dragLift),
    );
    await tester.pump();

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/drag_preview_valid.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('invalid drag preview over a placed block', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    final Rect board = tester.getRect(find.byType(GameBoardView));

    // Drop the domino in the middle first.
    TestGesture gesture = await tester.startGesture(_slotCenter(tester, 0));
    await tester.pump();
    await gesture.moveTo(
      board.center + const Offset(0, GameConstants.dragLift),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Then aim the 2x2 square at the same spot.
    gesture = await tester.startGesture(_slotCenter(tester, 1));
    await tester.pump();
    await gesture.moveTo(
      board.center + const Offset(0, GameConstants.dragLift),
    );
    await tester.pump();

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/drag_preview_invalid.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('after two drops', (WidgetTester tester) async {
    await _pump(tester);
    final Rect board = tester.getRect(find.byType(GameBoardView));

    // Indices are into the *remaining* tray previews, so both drops use the
    // piece currently drawn first and second.
    for (final (int slot, Offset aim) in <(int, Offset)>[
      (0, const Offset(-60, -60)),
      (1, const Offset(40, 30)),
    ]) {
      final TestGesture gesture = await tester.startGesture(
        _slotCenter(tester, slot),
      );
      await tester.pump();
      await gesture.moveTo(
        board.center + aim + const Offset(0, GameConstants.dragLift),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/after_drops.png'),
    );
  });

  testWidgets('score and combo after two clears', (WidgetTester tester) async {
    // A board where rows 0, 2 and 4 each need only their last cell.
    GameBoard board = GameBoard.empty();
    final BlockPiece seed = BlockPiece(
      id: 'seed',
      cells: const <BlockCell>[BlockCell(0, 0)],
      color: const Color(0xFFB18CFF),
    );
    for (final int row in <int>[0, 2, 4]) {
      for (int column = 0; column < GameConstants.boardSize - 1; column++) {
        board = board.placePiece(seed, row, column);
      }
    }
    final BlockPiece unit = BlockPiece(
      id: 'unit',
      cells: const <BlockCell>[BlockCell(0, 0)],
      color: const Color(0xFF4FD1FF),
    );
    final GameController controller = GameController.withState(
      board: board,
      tray: <BlockPiece?>[unit, unit, unit],
    );
    await _pump(tester, controller: controller);

    final Rect rect = tester.getRect(find.byType(GameBoardView));
    final BoardGeometry geo = BoardGeometry(side: rect.width);
    for (final int row in <int>[0, 2]) {
      final TestGesture gesture = await tester.startGesture(
        _slotCenter(tester, 0),
      );
      await tester.pump();
      await gesture.moveTo(
        rect.topLeft +
            geo.originOf(row, GameConstants.boardSize - 1) +
            Offset(geo.cellSize / 2, geo.cellSize / 2 + GameConstants.dragLift),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/score_and_combo.png'),
    );
  });

  testWidgets('tray with the biggest shapes', (WidgetTester tester) async {
    await _pump(
      tester,
      controller: GameController.withState(
        board: GameBoard.empty(),
        tray: <BlockPiece?>[
          BlockShapes.line5H.toPiece(const Color(0xFF4FD1FF)),
          BlockShapes.square3.toPiece(const Color(0xFF7EE787)),
          BlockShapes.lLargeSW.toPiece(const Color(0xFFFF6B9D)),
        ],
      ),
    );

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/tray_large_shapes.png'),
    );
  });

  testWidgets('game over overlay', (WidgetTester tester) async {
    // Two isolated holes per row and per column: nothing but a single fits,
    // and filling one completes no line.
    GameBoard board = GameBoard.empty();
    final BlockPiece seed = BlockShapes.single.toPiece(const Color(0xFFB18CFF));
    final Set<BlockCell> holes = <BlockCell>{
      for (int r = 0; r < GameConstants.boardSize; r++) ...<BlockCell>[
        BlockCell(r, (3 * r) % GameConstants.boardSize),
        BlockCell(r, (3 * r + 4) % GameConstants.boardSize),
      ],
    };
    for (int r = 0; r < GameConstants.boardSize; r++) {
      for (int c = 0; c < GameConstants.boardSize; c++) {
        if (!holes.contains(BlockCell(r, c))) {
          board = board.placePiece(seed, r, c);
        }
      }
    }

    final GameController controller = GameController.withState(
      board: board,
      tray: <BlockPiece?>[
        BlockShapes.single.toPiece(const Color(0xFF4FD1FF)),
        BlockShapes.square2.toPiece(const Color(0xFF7EE787)),
        BlockShapes.line5H.toPiece(const Color(0xFFFFD166)),
      ],
      score: 2480,
      bestScore: 5310,
    );
    await _pump(tester, controller: controller);

    controller.startDrag(0, Offset.zero);
    controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 0));
    controller.endDrag();
    await tester.pumpAndSettle();

    expect(find.byType(GameOverOverlay), findsOneWidget);
    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/game_over.png'),
    );
  });

  testWidgets('place pulse mid-animation', (WidgetTester tester) async {
    final GameController controller = GameController.withState(
      board: GameBoard.empty(),
      tray: BlockShapes.sampleTray(),
    );
    await _pump(tester, controller: controller);

    final Rect rect = tester.getRect(find.byType(GameBoardView));
    final BoardGeometry geo = BoardGeometry(side: rect.width);
    final TestGesture gesture = await tester.startGesture(
      _slotCenter(tester, 2),
    );
    await tester.pump();
    await gesture.moveTo(
      rect.topLeft +
          geo.originOf(3, 3) +
          Offset(geo.cellSize / 2, geo.cellSize / 2 + GameConstants.dragLift),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // A third of the way into the bounce, with the score pop already rising.
    await tester.pump(PlacePulse.duration ~/ 3);

    expect(find.byType(PlacePulse), findsOneWidget);
    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/effect_place.png'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('line clear burst mid-animation', (WidgetTester tester) async {
    // Row 4 needs one cell; a few loose blocks stay behind to show that only
    // the completed line is taken.
    GameBoard board = GameBoard.empty();
    final BlockPiece seed = BlockShapes.single.toPiece(const Color(0xFFB18CFF));
    for (int c = 0; c < GameConstants.boardSize - 1; c++) {
      board = board.placePiece(seed, 4, c);
    }
    board = board.placePiece(seed, 6, 2);
    board = board.placePiece(seed, 6, 3);

    final GameController controller = GameController.withState(
      board: board,
      tray: <BlockPiece?>[
        BlockShapes.single.toPiece(const Color(0xFF4FD1FF)),
        BlockShapes.square2.toPiece(const Color(0xFF7EE787)),
        BlockShapes.line3H.toPiece(const Color(0xFFFF6B9D)),
      ],
    );
    await _pump(tester, controller: controller);

    final Rect rect = tester.getRect(find.byType(GameBoardView));
    final BoardGeometry geo = BoardGeometry(side: rect.width);
    final TestGesture gesture = await tester.startGesture(
      _slotCenter(tester, 0),
    );
    await tester.pump();
    await gesture.moveTo(
      rect.topLeft +
          geo.originOf(4, GameConstants.boardSize - 1) +
          Offset(geo.cellSize / 2, geo.cellSize / 2 + GameConstants.dragLift),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // Just past the flare, while the sparks are still travelling.
    await tester.pump(const Duration(milliseconds: 110));

    expect(find.byType(ClearBurst), findsOneWidget);
    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/effect_clear.png'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('settings sheet', (WidgetTester tester) async {
    final GameSettings settings = GameSettings(store: InMemorySettingsStore());
    addTearDown(settings.dispose);

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

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HiHiBlockApp),
      matchesGoldenFile('goldens/settings_sheet.png'),
    );
  });
}
