@Tags(<String>['audit'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/app/app.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_piece_view.dart';
import 'package:hihi_block/features/game/presentation/widgets/block_tray.dart';
import 'package:hihi_block/features/game/presentation/widgets/game_board_view.dart';

/// Counts what Flutter actually rebuilds while a block is dragged across the
/// board. Run with:
///   flutter test --run-skipped --tags audit test/drag_perf_test.dart
///
/// This drives `debugPrintRebuildDirtyWidgets`, so the numbers are Flutter's
/// own account of dirty widgets — not an estimate.
void main() {
  testWidgets('rebuilds per pointer move while dragging', (
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

    final Rect board = tester.getRect(find.byType(GameBoardView));
    final BoardGeometry geo = BoardGeometry(side: board.width);
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

    // Sweep the block diagonally across the whole board, one small step per
    // frame — the shape of a real drag.
    const int steps = 40;
    final Offset from =
        board.topLeft +
        geo.originOf(0, 0) +
        const Offset(0, GameConstants.dragLift);
    final Offset to =
        board.topLeft +
        geo.originOf(7, 7) +
        const Offset(0, GameConstants.dragLift);

    final List<String> lines = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    debugPrintRebuildDirtyWidgets = true;

    for (int i = 1; i <= steps; i++) {
      final double t = i / steps;
      await gesture.moveTo(Offset.lerp(from, to, t)!);
      await tester.pump();
    }

    debugPrintRebuildDirtyWidgets = false;
    debugPrint = original;

    int countOf(String name) =>
        lines.where((String l) => l.contains(name)).length;

    final int total = lines
        .where((String l) => !l.startsWith('Rebuilt '))
        .length;

    debugPrint('--- $steps pointer moves across the board ---');
    for (final String widget in <String>[
      'BlockCellTile',
      'GameBoardView',
      'BlockTray',
      'BlockPieceView',
      'GameHeader',
      'ScoreBadge',
      'ComboBadge',
      'DragGhost',
      'GridView',
      'SettingsButton',
    ]) {
      final int n = countOf(widget);
      debugPrint(
        '  ${widget.padRight(16)} ${n.toString().padLeft(6)} rebuilds  '
        '(${(n / steps).toStringAsFixed(1)} per move)',
      );
    }
    debugPrint('  ${"TOTAL dirty".padRight(16)} ${total.toString().padLeft(6)}'
        '  (${(total / steps).toStringAsFixed(1)} per move)');

    // What is left, so the remaining cost is named rather than guessed at.
    final Map<String, int> byType = <String, int>{};
    for (final String line in lines) {
      if (line.startsWith('Rebuilt ')) continue;
      // Lines read "Rebuilding <Widget>(...)" / "Building <Widget>(...)", so
      // the widget name is the token after the verb.
      final List<String> tokens = line
          .trim()
          .split(RegExp(r'[\s(]'))
          .where((String t) => t.isNotEmpty)
          .toList();
      if (tokens.length < 2) continue;
      final String name = tokens[1];
      if (name.isEmpty) continue;
      byType[name] = (byType[name] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> top = byType.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    debugPrint('  --- most-rebuilt widgets ---');
    for (final MapEntry<String, int> e in top.take(12)) {
      debugPrint(
        '  ${e.key.padRight(28)} ${(e.value / steps).toStringAsFixed(1)}'
        ' per move',
      );
    }

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
