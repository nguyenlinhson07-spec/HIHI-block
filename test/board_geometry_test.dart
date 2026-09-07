import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/logic/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    test('derives the cell pitch from the rendered side length', () {
      const BoardGeometry geo = BoardGeometry(side: 358);
      // 358 - 2*8 padding = 342 usable, 8 cells with 7 gaps of 4.
      expect(geo.cellSize * 8 + 7 * GameConstants.cellGap, closeTo(342, 0.001));
      expect(geo.pitch, closeTo(geo.cellSize + GameConstants.cellGap, 0.001));
    });

    test('round-trips a cell origin back to its own anchor', () {
      for (final double side in <double>[280, 358, 420, 464]) {
        final BoardGeometry geo = BoardGeometry(side: side);
        for (int row = 0; row < GameConstants.boardSize; row++) {
          for (int column = 0; column < GameConstants.boardSize; column++) {
            expect(
              geo.anchorFor(geo.originOf(row, column)),
              BlockCell(row, column),
              reason: 'side=$side cell=($row,$column)',
            );
          }
        }
      }
    });

    test('snaps to the nearest cell rather than flooring', () {
      const BoardGeometry geo = BoardGeometry(side: 358);
      final Offset justPast = geo.originOf(2, 2) + Offset(geo.pitch * 0.6, 0);
      expect(geo.anchorFor(justPast), const BlockCell(2, 3));

      final Offset justBefore = geo.originOf(2, 2) + Offset(geo.pitch * 0.4, 0);
      expect(geo.anchorFor(justBefore), const BlockCell(2, 2));
    });

    test('reports anchors outside the grid for off-board points', () {
      const BoardGeometry geo = BoardGeometry(side: 358);
      expect(geo.anchorFor(const Offset(-200, 10)).column, lessThan(0));
      expect(
        geo.anchorFor(const Offset(10, 900)).row,
        greaterThanOrEqualTo(GameConstants.boardSize),
      );
    });

    test('spans a multi-cell piece including the gaps', () {
      const BoardGeometry geo = BoardGeometry(side: 358);
      final Size span = geo.sizeOfSpan(2, 3);
      expect(span.width, closeTo(3 * geo.cellSize + 2 * geo.gap, 0.001));
      expect(span.height, closeTo(2 * geo.cellSize + geo.gap, 0.001));
    });
  });
}
