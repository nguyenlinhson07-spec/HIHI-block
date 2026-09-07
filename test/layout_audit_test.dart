@Tags(<String>['audit'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_header.dart';

/// Measures the real layout at each breakpoint. Run with:
///   flutter test --run-skipped --tags audit test/layout_audit_test.dart
const List<(String, Size)> _breakpoints = <(String, Size)>[
  ('desktop 1920', Size(1920, 1080)),
  ('desktop 1440', Size(1440, 900)),
  ('desktop 1366', Size(1366, 768)),
  ('tablet  1024', Size(1024, 768)),
  ('tablet   768', Size(768, 1024)),
  ('mobile   430', Size(430, 932)),
  ('mobile   390', Size(390, 844)),
  ('mobile   375', Size(375, 812)),
  ('mobile   360', Size(360, 800)),
  ('short    320', Size(320, 568)),
];

void main() {
  for (final (String label, Size size) in _breakpoints) {
    testWidgets(label, (WidgetTester tester) async {
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

      final Object? error = tester.takeException();
      final Rect header = tester.getRect(find.byType(GameHeader));
      final Rect board = tester.getRect(find.byType(GameBoardView));
      final Rect tray = tester.getRect(find.byType(BlockTray));

      final double gapAbove = board.top - header.bottom;
      final double gapBelow = tray.top - board.bottom;
      final double dead = gapAbove + gapBelow;

      final double boardCell = BoardGeometry(side: board.width).cellSize;
      final BlockPieceView first = tester.widgetList<BlockPieceView>(
        find.descendant(
          of: find.byType(BlockTray),
          matching: find.byType(BlockPieceView),
        ),
      ).first;
      final double trayCell = first.cellSize;

      debugPrint(
        '$label | board ${board.width.toStringAsFixed(0)} '
        '| boardCell ${boardCell.toStringAsFixed(1)} '
        '| trayCell ${trayCell.toStringAsFixed(1)} '
        '(${(trayCell / boardCell * 100).toStringAsFixed(0)}% of board cell) '
        '| dead ${dead.toStringAsFixed(0)}px '
        '(${(dead / size.height * 100).toStringAsFixed(0)}%) '
        '| trayH ${tray.height.toStringAsFixed(0)} '
        '| err: ${error ?? "none"}',
      );
    });
  }
}
