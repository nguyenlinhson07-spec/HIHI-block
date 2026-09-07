import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/constants/game_constants.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/piece_generator.dart';

/// Fills [cells] on an empty board with 1x1 blocks.
GameBoard _boardWith(Iterable<BlockCell> cells) {
  final BlockPiece unit = BlockPiece(
    id: 'unit',
    cells: const <BlockCell>[BlockCell(0, 0)],
    color: Colors.cyan,
  );
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(unit, c.row, c.column);
  }
  return board;
}

void main() {
  group('catalogue', () {
    test('1. covers every required shape group', () {
      final Set<String> ids = BlockShapes.catalogue
          .map((BlockShape s) => s.id)
          .toSet();

      // Single.
      expect(ids, contains('single'));
      // Lines 2..5, both orientations.
      for (final int length in <int>[2, 3, 4, 5]) {
        expect(ids, contains('line$length-h'));
        expect(ids, contains('line$length-v'));
      }
      // Squares and rectangles.
      expect(ids, containsAll(<String>['square-2x2', 'square-3x3']));
      expect(ids, containsAll(<String>['rect-2x3', 'rect-3x2']));
      // Small and large L, four orientations each.
      for (final String corner in <String>['nw', 'ne', 'sw', 'se']) {
        expect(ids, contains('l3-$corner'));
        expect(ids, contains('l5-$corner'));
      }
      // T, four orientations.
      expect(
        ids,
        containsAll(<String>['t-up', 't-down', 't-left', 't-right']),
      );
      // S and Z, both orientations.
      expect(ids, containsAll(<String>['s-h', 's-v', 'z-h', 'z-v']));
    });

    test('2. shape ids are unique', () {
      final List<String> ids = BlockShapes.catalogue
          .map((BlockShape s) => s.id)
          .toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 29);
    });

    test('shapes have the cell counts their names imply', () {
      expect(BlockShapes.single.cellCount, 1);
      expect(BlockShapes.line5H.cellCount, 5);
      expect(BlockShapes.square3.cellCount, 9);
      expect(BlockShapes.rect2x3.cellCount, 6);
      expect(BlockShapes.lLargeNW.cellCount, 5);
      expect(BlockShapes.tUp.cellCount, 4);
      expect(BlockShapes.zVertical.cellCount, 4);
    });

    test('shape cells are distinct and already normalised', () {
      for (final BlockShape shape in BlockShapes.catalogue) {
        expect(
          shape.cells.toSet().length,
          shape.cells.length,
          reason: '${shape.id} repeats a cell',
        );
        expect(
          shape.cells.map((BlockCell c) => c.row).reduce(min),
          0,
          reason: '${shape.id} does not start at row 0',
        );
        expect(
          shape.cells.map((BlockCell c) => c.column).reduce(min),
          0,
          reason: '${shape.id} does not start at column 0',
        );
      }
    });

    test('every shape fits on an empty 8x8 board', () {
      final GameBoard board = GameBoard.empty();
      for (final BlockShape shape in BlockShapes.catalogue) {
        final BlockPiece piece = shape.toPiece(Colors.cyan);
        expect(
          board.canPlaceAnywhere(piece),
          isTrue,
          reason: '${shape.id} does not fit an empty board',
        );
      }
    });

    test('no shape is wider or taller than the tray budget', () {
      for (final BlockShape shape in BlockShapes.catalogue) {
        final BlockPiece piece = shape.toPiece(Colors.cyan);
        expect(piece.columnCount, lessThanOrEqualTo(BlockShapes.maxColumns));
        expect(piece.rowCount, lessThanOrEqualTo(BlockShapes.maxRows));
      }
    });

    test('size classes split the catalogue by cell count', () {
      expect(BlockShapes.single.size, ShapeSize.small);
      expect(BlockShapes.line3H.size, ShapeSize.small);
      expect(BlockShapes.square2.size, ShapeSize.medium);
      expect(BlockShapes.tUp.size, ShapeSize.medium);
      expect(BlockShapes.line5H.size, ShapeSize.large);
      expect(BlockShapes.square3.size, ShapeSize.large);

      for (final ShapeSize size in ShapeSize.values) {
        expect(BlockShapes.ofSize(size), isNotEmpty);
      }
      expect(
        ShapeSize.values
            .map((ShapeSize s) => BlockShapes.ofSize(s).length)
            .reduce((int a, int b) => a + b),
        BlockShapes.catalogue.length,
      );
    });
  });

  group('generator', () {
    test('3. always deals exactly three pieces', () {
      final PieceGenerator generator = PieceGenerator(random: Random(7));
      for (int i = 0; i < 200; i++) {
        final List<BlockPiece> tray = generator.generateTray(
          GameBoard.empty(),
          i * 100,
        );
        expect(tray.length, GameConstants.traySlotCount);
        expect(tray.every((BlockPiece p) => p.cells.isNotEmpty), isTrue);
      }
    });

    test('4. the same seed always deals the same trays', () {
      List<String> deal(int seed) {
        final PieceGenerator generator = PieceGenerator(random: Random(seed));
        return <String>[
          for (int i = 0; i < 10; i++)
            ...generator
                .generateTray(GameBoard.empty(), 0)
                .map((BlockPiece p) => p.id),
        ];
      }

      expect(deal(1234), deal(1234));
      expect(deal(1234), isNot(deal(4321)));
    });

    test('deals pieces only from the catalogue', () {
      final Set<String> ids = BlockShapes.catalogue
          .map((BlockShape s) => s.id)
          .toSet();
      final PieceGenerator generator = PieceGenerator(random: Random(3));
      for (int i = 0; i < 100; i++) {
        for (final BlockPiece piece in generator.generateTray(
          GameBoard.empty(),
          0,
        )) {
          expect(ids, contains(piece.id));
        }
      }
    });

    test('12. re-rolls a dead trio while the board still has room', () {
      // Two free cells that no 2-cell shape can cover: (0,0) and (7,7).
      final GameBoard board = _boardWith(<BlockCell>[
        for (int r = 0; r < GameConstants.boardSize; r++)
          for (int c = 0; c < GameConstants.boardSize; c++)
            if (!(r == 0 && c == 0) && !(r == 7 && c == 7)) BlockCell(r, c),
      ]);
      expect(board.occupiedCount, 62);

      // Only the single fits. Across many seeds the generator must find it.
      int trayWithAMove = 0;
      for (int seed = 0; seed < 40; seed++) {
        final List<BlockPiece> tray = PieceGenerator(
          random: Random(seed),
        ).generateTray(board, 0);
        if (board.hasAnyMove(tray)) trayWithAMove++;
      }
      expect(
        trayWithAMove,
        greaterThan(30),
        reason: 'the retry loop should almost always find the single',
      );
    });

    test('12. accepts a dead trio when the board really is finished', () {
      // Every cell taken: nothing can ever be placed again.
      final GameBoard full = _boardWith(<BlockCell>[
        for (int r = 0; r < GameConstants.boardSize; r++)
          for (int c = 0; c < GameConstants.boardSize; c++) BlockCell(r, c),
      ]);

      final List<BlockPiece> tray = PieceGenerator(
        random: Random(5),
      ).generateTray(full, 0);

      // It still returns a full tray — and it terminates, rather than looping.
      expect(tray.length, GameConstants.traySlotCount);
      expect(full.hasAnyMove(tray), isFalse);
    });
  });

  group('difficulty weighting', () {
    test('4. an open board leans on medium shapes', () {
      const SizeWeights w = PieceGenerator.openWeights;
      expect(w.medium, greaterThan(w.small));
      expect(w.medium, greaterThan(w.large));
      expect(PieceGenerator.weightsFor(0.0), w);
      expect(PieceGenerator.weightsFor(0.2), w);
    });

    test('4. a half-full board spreads the sizes evenly', () {
      const SizeWeights w = PieceGenerator.balancedWeights;
      expect(PieceGenerator.weightsFor(0.35), w);
      expect(PieceGenerator.weightsFor(0.5), w);
      expect((w.small - w.large).abs(), lessThanOrEqualTo(2));
    });

    test('4. a crowded board favours small shapes', () {
      const SizeWeights w = PieceGenerator.crowdedWeights;
      expect(PieceGenerator.weightsFor(0.6), w);
      expect(PieceGenerator.weightsFor(0.95), w);
      expect(w.small, greaterThan(PieceGenerator.openWeights.small));
      expect(w.large, lessThan(PieceGenerator.openWeights.large));
    });

    test('13. large shapes stay possible even on a crowded board', () {
      expect(PieceGenerator.crowdedWeights.large, greaterThan(0));
      expect(PieceGenerator.crowdedWeights.medium, greaterThan(0));
    });

    test('fillRatio is measured against all 64 cells', () {
      expect(PieceGenerator.fillRatioOf(GameBoard.empty()), 0);
      expect(
        PieceGenerator.fillRatioOf(
          _boardWith(<BlockCell>[
            for (int c = 0; c < 8; c++) BlockCell(0, c),
          ]),
        ),
        8 / 64,
      );
    });
  });

  group('16. distribution', () {
    /// Deals many trays on [board] and returns the shapes seen, by size.
    Map<ShapeSize, int> sample(GameBoard board, {int deals = 400}) {
      final PieceGenerator generator = PieceGenerator(random: Random(99));
      final Map<ShapeSize, int> counts = <ShapeSize, int>{
        for (final ShapeSize s in ShapeSize.values) s: 0,
      };
      for (int i = 0; i < deals; i++) {
        for (final BlockPiece piece in generator.generateTray(board, 0)) {
          final BlockShape shape = BlockShapes.catalogue.firstWhere(
            (BlockShape s) => s.id == piece.id,
          );
          counts[shape.size] = counts[shape.size]! + 1;
        }
      }
      return counts;
    }

    test('small, medium and large all show up on an open board', () {
      final Map<ShapeSize, int> counts = sample(GameBoard.empty());
      for (final ShapeSize size in ShapeSize.values) {
        expect(counts[size], greaterThan(0), reason: 'never dealt a $size');
      }
      // Medium is the most common on an open board.
      expect(counts[ShapeSize.medium], greaterThan(counts[ShapeSize.small]!));
      expect(counts[ShapeSize.medium], greaterThan(counts[ShapeSize.large]!));
    });

    test('a crowded board shifts towards small without banning large', () {
      // Half the board taken, in a pattern that leaves plenty of room.
      final GameBoard crowded = _boardWith(<BlockCell>[
        for (int r = 0; r < 6; r++)
          for (int c = 0; c < 7; c++) BlockCell(r, c),
      ]);
      expect(PieceGenerator.fillRatioOf(crowded), greaterThan(0.6));

      final Map<ShapeSize, int> counts = sample(crowded);
      expect(counts[ShapeSize.small], greaterThan(counts[ShapeSize.large]!));
      expect(counts[ShapeSize.large], greaterThan(0));
    });

    test('it is not stuck on one shape', () {
      final PieceGenerator generator = PieceGenerator(random: Random(11));
      final Set<String> seen = <String>{};
      for (int i = 0; i < 300; i++) {
        seen.addAll(
          generator.generateTray(GameBoard.empty(), 0).map((BlockPiece p) => p.id),
        );
      }
      expect(seen.length, greaterThan(15));
    });
  });
}
