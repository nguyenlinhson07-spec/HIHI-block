import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_cell_tile.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';

const List<Size> _phoneSizes = <Size>[
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
];

/// Pumps the app with [shapes] loaded into the tray.
Future<void> _pumpTray(
  WidgetTester tester,
  Size size,
  List<BlockShape> shapes,
) async {
  final GameController controller = GameController.withState(
    board: GameBoard.empty(),
    tray: shapes
        .map<BlockPiece?>((BlockShape s) => s.toPiece(Colors.cyanAccent))
        .toList(),
  );
  addTearDown(controller.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HiHiBlockApp(controller: controller));
  await tester.pumpAndSettle();
}

void main() {
  group('14. tray preview', () {
    for (final Size size in _phoneSizes) {
      testWidgets('25./26. the biggest shapes fit at ${size.width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await _pumpTray(tester, size, <BlockShape>[
          BlockShapes.line5H, // widest
          BlockShapes.square3, // bulkiest
          BlockShapes.line5V, // tallest
        ]);

        expect(tester.takeException(), isNull);

        final Rect tray = tester.getRect(find.byType(BlockTray));
        final List<Rect> previews = tester
            .widgetList(find.byType(BlockPieceView))
            .map((Widget w) => tester.getRect(find.byWidget(w)))
            .toList();

        expect(previews.length, 3);
        for (final Rect preview in previews) {
          expect(preview.width, greaterThan(0));
          expect(preview.height, greaterThan(0));
          expect(
            tray.contains(preview.topLeft) &&
                tray.contains(preview.bottomRight),
            isTrue,
            reason: 'preview $preview escapes the tray $tray',
          );
        }
      });
    }

    testWidgets('25. a line of 5 renders all five cells', (
      WidgetTester tester,
    ) async {
      await _pumpTray(tester, const Size(360, 800), <BlockShape>[
        BlockShapes.line5H,
        BlockShapes.line5V,
        BlockShapes.single,
      ]);

      final int tiles = tester
          .widgetList(
            find.descendant(
              of: find.byType(BlockTray),
              matching: find.byType(BlockCellTile),
            ),
          )
          .length;
      expect(tiles, 5 + 5 + 1);
    });

    testWidgets('26. a 3x3 renders all nine cells', (
      WidgetTester tester,
    ) async {
      await _pumpTray(tester, const Size(360, 800), <BlockShape>[
        BlockShapes.square3,
        BlockShapes.rect2x3,
        BlockShapes.tUp,
      ]);

      final int tiles = tester
          .widgetList(
            find.descendant(
              of: find.byType(BlockTray),
              matching: find.byType(BlockCellTile),
            ),
          )
          .length;
      expect(tiles, 9 + 6 + 4);
    });

    testWidgets('previews keep the shape aspect ratio', (
      WidgetTester tester,
    ) async {
      await _pumpTray(tester, const Size(390, 844), <BlockShape>[
        BlockShapes.line5H,
        BlockShapes.square3,
        BlockShapes.rect3x2,
      ]);

      final List<BlockPieceView> views = tester
          .widgetList<BlockPieceView>(find.byType(BlockPieceView))
          .toList();

      for (final BlockPieceView view in views) {
        final Rect rect = tester.getRect(find.byWidget(view));
        final BlockPiece piece = view.piece;
        final double expectedWidth =
            piece.columnCount * view.cellSize +
            (piece.columnCount - 1) * view.gap;
        final double expectedHeight =
            piece.rowCount * view.cellSize + (piece.rowCount - 1) * view.gap;
        expect(rect.width, closeTo(expectedWidth, 0.01));
        expect(rect.height, closeTo(expectedHeight, 0.01));
      }
    });

    testWidgets('every catalogue shape renders without overflowing', (
      WidgetTester tester,
    ) async {
      // Three at a time, across the whole catalogue.
      for (int i = 0; i < BlockShapes.catalogue.length; i += 3) {
        final List<BlockShape> batch = BlockShapes.catalogue
            .skip(i)
            .take(3)
            .toList();
        while (batch.length < 3) {
          batch.add(BlockShapes.single);
        }

        await _pumpTray(tester, const Size(360, 800), batch);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow while showing ${batch.map((BlockShape s) => s.id)}',
        );

        final Rect tray = tester.getRect(find.byType(BlockTray));
        for (final Element element in find.byType(BlockPieceView).evaluate()) {
          final Rect preview = tester.getRect(
            find.byElementPredicate((Element e) => e == element),
          );
          expect(preview.height, lessThanOrEqualTo(tray.height));
          expect(preview.width, lessThanOrEqualTo(tray.width / 3));
        }
      }
    });
  });

  group('tray blocks read at the same scale as the board', () {
    /// The size of one cell in the first tray preview.
    double trayCell(WidgetTester tester) => tester
        .widgetList<BlockPieceView>(
          find.descendant(
            of: find.byType(BlockTray),
            matching: find.byType(BlockPieceView),
          ),
        )
        .first
        .cellSize;

    double boardCell(WidgetTester tester) => BoardGeometry(
      side: tester.getSize(find.byType(GameBoardView)).width,
    ).cellSize;

    for (final Size size in _phoneSizes) {
      testWidgets('an ordinary hand fills most of a board cell at '
          '${size.width.toInt()}dp', (WidgetTester tester) async {
        // The everyday case: nothing wider than three cells.
        await _pumpTray(tester, size, <BlockShape>[
          BlockShapes.line2H,
          BlockShapes.lSmallSW,
          BlockShapes.square2,
        ]);

        final double ratio = trayCell(tester) / boardCell(tester);
        expect(
          ratio,
          greaterThan(0.7),
          reason:
              'a block should not shrink to a token in the tray and then '
              'double in size the moment it is picked up '
              '(tray ${trayCell(tester)}, board ${boardCell(tester)})',
        );
        expect(ratio, lessThanOrEqualTo(1.0));
      });
    }

    testWidgets(
      'a five-wide piece still fits, even though it must be smaller',
      (WidgetTester tester) async {
        await _pumpTray(tester, const Size(360, 800), <BlockShape>[
          BlockShapes.line5H,
          BlockShapes.square2,
          BlockShapes.single,
        ]);

        expect(tester.takeException(), isNull);
        final Rect tray = tester.getRect(find.byType(BlockTray));
        for (final Element element in find.byType(BlockPieceView).evaluate()) {
          final Rect preview = tester.getRect(
            find.byElementPredicate((Element e) => e == element),
          );
          expect(preview.width, lessThanOrEqualTo(tray.width / 3));
        }
      },
    );

    testWidgets('every slot keeps a marker once its block has been played', (
      WidgetTester tester,
    ) async {
      final GameController controller = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HiHiBlockApp(controller: controller));
      await tester.pumpAndSettle();

      final Rect trayBefore = tester.getRect(find.byType(BlockTray));
      expect(find.byType(BlockPieceView), findsNWidgets(3));

      // Play the first slot straight through the controller.
      controller.startDrag(0, Offset.zero);
      controller.updateDrag(Offset.zero, anchor: const BlockCell(0, 0));
      controller.endDrag();
      await tester.pumpAndSettle();

      // Two previews left, and the tray has not changed size or reflowed.
      expect(find.byType(BlockPieceView), findsNWidgets(2));
      expect(tester.getRect(find.byType(BlockTray)), trayBefore);
      expect(tester.takeException(), isNull);
    });
  });
}
