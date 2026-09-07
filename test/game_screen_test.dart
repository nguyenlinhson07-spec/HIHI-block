import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_cell_tile.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/drag_ghost.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';

const List<Size> _phoneSizes = <Size>[
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
];

/// Pumps the app with the predictable Phase-1 trio in the tray — a 2-cell
/// domino, a 3-cell L and a 2x2 square — so drag assertions stay exact even
/// though production deals randomly.
Future<void> _pumpAt(WidgetTester tester, Size size) async {
  final GameController controller = GameController.withState(
    board: GameBoard.empty(),
    tray: BlockShapes.sampleTray(),
  );
  addTearDown(controller.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HiHiBlockApp(controller: controller));
  await tester.pumpAndSettle();
}

/// Counts the board tiles currently painted with [style].
int _boardTiles(WidgetTester tester, CellTileStyle style) => tester
    .widgetList<BlockCellTile>(
      find.descendant(
        of: find.byType(GameBoardView),
        matching: find.byType(BlockCellTile),
      ),
    )
    .where((BlockCellTile t) => t.style == style)
    .length;

/// Counts the block previews still sitting in the tray.
int _trayPieces(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: find.byType(BlockTray),
        matching: find.byType(BlockPieceView),
      ),
    )
    .length;

/// The pointer position that puts a dragged block over [boardPoint], undoing
/// the vertical drag lift.
Offset _pointerFor(Offset boardPoint) =>
    boardPoint + const Offset(0, GameConstants.dragLift);

void main() {
  group('layout', () {
    testWidgets('renders header, board and tray', (WidgetTester tester) async {
      await _pumpAt(tester, _phoneSizes.first);

      expect(find.text('HI HI'), findsOneWidget);
      expect(find.text('BLOCK'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.byType(GameBoardView), findsOneWidget);
      expect(find.byType(BlockTray), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('board renders 64 cells', (WidgetTester tester) async {
      await _pumpAt(tester, _phoneSizes.first);

      final int boardTiles = tester
          .widgetList(
            find.descendant(
              of: find.byType(GameBoardView),
              matching: find.byType(BlockCellTile),
            ),
          )
          .length;
      expect(boardTiles, GameConstants.boardSize * GameConstants.boardSize);
      expect(_boardTiles(tester, CellTileStyle.empty), 64);
    });

    testWidgets('tray shows the three sample pieces (2 + 3 + 4 tiles)', (
      WidgetTester tester,
    ) async {
      await _pumpAt(tester, _phoneSizes.first);

      final int trayTiles = tester
          .widgetList(
            find.descendant(
              of: find.byType(BlockTray),
              matching: find.byType(BlockCellTile),
            ),
          )
          .length;
      expect(trayTiles, 2 + 3 + 4);
      expect(_trayPieces(tester), GameConstants.traySlotCount);
    });

    for (final Size size in _phoneSizes) {
      testWidgets('11. no overflow at ${size.width}x${size.height}', (
        WidgetTester tester,
      ) async {
        await _pumpAt(tester, size);

        expect(tester.takeException(), isNull);

        // The board must stay square.
        final Size boardSize = tester.getSize(find.byType(GameBoardView));
        expect(boardSize.width, closeTo(boardSize.height, 0.5));
        expect(boardSize.width, greaterThan(0));
        expect(boardSize.width, lessThanOrEqualTo(size.width));
      });

      testWidgets('11. no overflow while dragging at ${size.width}', (
        WidgetTester tester,
      ) async {
        await _pumpAt(tester, size);

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
        await gesture.moveTo(_pointerFor(board.center));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(DragGhost), findsOneWidget);
        // The board did not move because a piece was picked up.
        expect(tester.getRect(find.byType(GameBoardView)), board);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('drag and drop', () {
    testWidgets('dragging a tray block onto the board places it', (
      WidgetTester tester,
    ) async {
      await _pumpAt(tester, const Size(390, 844));

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

      // Picked up: the slot is empty and the ghost follows the pointer.
      expect(_trayPieces(tester), GameConstants.traySlotCount - 1);
      expect(find.byType(DragGhost), findsOneWidget);

      await gesture.moveTo(_pointerFor(board.center));
      await tester.pump();

      // A valid preview highlights exactly the 2 cells of the domino.
      expect(_boardTiles(tester, CellTileStyle.previewValid), 2);
      expect(_boardTiles(tester, CellTileStyle.previewInvalid), 0);

      // The ghost sits above the pointer, not under the finger.
      final Rect ghost = tester.getRect(find.byType(DragGhost));
      expect(
        ghost.center.dy,
        closeTo(board.center.dy, 1.0),
        reason: 'ghost should be lifted onto the board, above the pointer',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(DragGhost), findsNothing);
      expect(_boardTiles(tester, CellTileStyle.filled), 2);
      expect(_boardTiles(tester, CellTileStyle.empty), 62);
      expect(_trayPieces(tester), GameConstants.traySlotCount - 1);
    });

    testWidgets('a block released off the board returns to the tray', (
      WidgetTester tester,
    ) async {
      await _pumpAt(tester, const Size(390, 844));

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
      // Stay down in the tray area, far below the board.
      await gesture.moveTo(slot + const Offset(40, 0));
      await tester.pump();
      expect(_boardTiles(tester, CellTileStyle.previewValid), 0);
      expect(_boardTiles(tester, CellTileStyle.previewInvalid), 0);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(_boardTiles(tester, CellTileStyle.filled), 0);
      expect(_trayPieces(tester), GameConstants.traySlotCount);
    });

    testWidgets('a block overlapping an occupied cell shows an invalid '
        'preview and is not placed', (WidgetTester tester) async {
      await _pumpAt(tester, const Size(390, 844));

      final Rect board = tester.getRect(find.byType(GameBoardView));
      Finder slotAt(int index) => find
          .descendant(
            of: find.byType(BlockTray),
            matching: find.byType(BlockPieceView),
          )
          .at(index);

      // First drop: the domino lands in the middle of the board.
      TestGesture gesture = await tester.startGesture(
        tester.getCenter(slotAt(0)),
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(board.center));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_boardTiles(tester, CellTileStyle.filled), 2);

      // Second drop: the 2x2 square aimed at the very same spot.
      gesture = await tester.startGesture(tester.getCenter(slotAt(1)));
      await tester.pump();
      await gesture.moveTo(_pointerFor(board.center));
      await tester.pump();

      expect(_boardTiles(tester, CellTileStyle.previewInvalid), greaterThan(0));
      expect(_boardTiles(tester, CellTileStyle.previewValid), 0);

      await gesture.up();
      await tester.pumpAndSettle();

      // Board unchanged, and the piece is back in its slot.
      expect(_boardTiles(tester, CellTileStyle.filled), 2);
      expect(_trayPieces(tester), GameConstants.traySlotCount - 1);
    });

    testWidgets('placed blocks survive a rebuild', (WidgetTester tester) async {
      await _pumpAt(tester, const Size(390, 844));

      final Rect board = tester.getRect(find.byType(GameBoardView));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(
          find
              .descendant(
                of: find.byType(BlockTray),
                matching: find.byType(BlockPieceView),
              )
              .at(0),
        ),
      );
      await tester.pump();
      await gesture.moveTo(_pointerFor(board.center));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Force a rebuild via the settings snackbar.
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(_boardTiles(tester, CellTileStyle.filled), 2);
    });
  });
}
