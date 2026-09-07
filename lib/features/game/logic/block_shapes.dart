import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/block_cell.dart';
import '../domain/models/block_piece.dart';

/// Rough size class of a shape, used to weight the generator.
enum ShapeSize {
  /// Up to 3 cells: single, short lines, small corners.
  small,

  /// Exactly 4 cells: squares, T, S/Z, line 4.
  medium,

  /// 5 cells or more: line 5, 3x3, rectangles, big corners.
  large,
}

/// One entry of the shape catalogue: a stable id plus the cells it covers.
@immutable
class BlockShape {
  const BlockShape(this.id, this.cells);

  /// Stable identifier — safe to persist and to assert on in tests.
  final String id;

  final List<BlockCell> cells;

  int get cellCount => cells.length;

  ShapeSize get size {
    if (cellCount <= 3) return ShapeSize.small;
    if (cellCount == 4) return ShapeSize.medium;
    return ShapeSize.large;
  }

  /// Builds a playable piece of this shape in [color].
  BlockPiece toPiece(Color color) =>
      BlockPiece(id: id, cells: cells, color: color);

  @override
  String toString() => 'BlockShape($id, $cellCount cells)';
}

/// The catalogue of shapes Hi Hi Block can deal.
class BlockShapes {
  const BlockShapes._();

  // --- Lines --------------------------------------------------------------

  static const BlockShape single = BlockShape('single', <BlockCell>[
    BlockCell(0, 0),
  ]);

  static const BlockShape line2H = BlockShape('line2-h', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
  ]);
  static const BlockShape line2V = BlockShape('line2-v', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
  ]);

  static const BlockShape line3H = BlockShape('line3-h', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
  ]);
  static const BlockShape line3V = BlockShape('line3-v', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(2, 0),
  ]);

  static const BlockShape line4H = BlockShape('line4-h', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(0, 3),
  ]);
  static const BlockShape line4V = BlockShape('line4-v', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(2, 0),
    BlockCell(3, 0),
  ]);

  static const BlockShape line5H = BlockShape('line5-h', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(0, 3),
    BlockCell(0, 4),
  ]);
  static const BlockShape line5V = BlockShape('line5-v', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(2, 0),
    BlockCell(3, 0),
    BlockCell(4, 0),
  ]);

  // --- Blocks -------------------------------------------------------------

  static const BlockShape square2 = BlockShape('square-2x2', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
  ]);

  static const BlockShape square3 = BlockShape('square-3x3', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(1, 2),
    BlockCell(2, 0),
    BlockCell(2, 1),
    BlockCell(2, 2),
  ]);

  /// 2 rows x 3 columns.
  static const BlockShape rect2x3 = BlockShape('rect-2x3', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(1, 2),
  ]);

  /// 3 rows x 2 columns.
  static const BlockShape rect3x2 = BlockShape('rect-3x2', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(2, 0),
    BlockCell(2, 1),
  ]);

  // --- Small L (the four corners of a 2x2) --------------------------------

  static const BlockShape lSmallNW = BlockShape('l3-nw', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(1, 0),
  ]);
  static const BlockShape lSmallNE = BlockShape('l3-ne', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(1, 1),
  ]);
  static const BlockShape lSmallSW = BlockShape('l3-sw', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(1, 1),
  ]);
  static const BlockShape lSmallSE = BlockShape('l3-se', <BlockCell>[
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
  ]);

  // --- Large L (the four corners of a 3x3) --------------------------------

  static const BlockShape lLargeNW = BlockShape('l5-nw', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 0),
    BlockCell(2, 0),
  ]);
  static const BlockShape lLargeNE = BlockShape('l5-ne', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 2),
    BlockCell(2, 2),
  ]);
  static const BlockShape lLargeSW = BlockShape('l5-sw', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(2, 0),
    BlockCell(2, 1),
    BlockCell(2, 2),
  ]);
  static const BlockShape lLargeSE = BlockShape('l5-se', <BlockCell>[
    BlockCell(0, 2),
    BlockCell(1, 2),
    BlockCell(2, 0),
    BlockCell(2, 1),
    BlockCell(2, 2),
  ]);

  // --- T ------------------------------------------------------------------

  static const BlockShape tUp = BlockShape('t-up', <BlockCell>[
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(1, 2),
  ]);
  static const BlockShape tDown = BlockShape('t-down', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 1),
  ]);
  static const BlockShape tLeft = BlockShape('t-left', <BlockCell>[
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(2, 1),
  ]);
  static const BlockShape tRight = BlockShape('t-right', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(2, 0),
  ]);

  // --- S / Z --------------------------------------------------------------

  static const BlockShape sHorizontal = BlockShape('s-h', <BlockCell>[
    BlockCell(0, 1),
    BlockCell(0, 2),
    BlockCell(1, 0),
    BlockCell(1, 1),
  ]);
  static const BlockShape sVertical = BlockShape('s-v', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(2, 1),
  ]);
  static const BlockShape zHorizontal = BlockShape('z-h', <BlockCell>[
    BlockCell(0, 0),
    BlockCell(0, 1),
    BlockCell(1, 1),
    BlockCell(1, 2),
  ]);
  static const BlockShape zVertical = BlockShape('z-v', <BlockCell>[
    BlockCell(0, 1),
    BlockCell(1, 0),
    BlockCell(1, 1),
    BlockCell(2, 0),
  ]);

  // --- Catalogue ----------------------------------------------------------

  /// Every shape the generator can deal.
  static const List<BlockShape> catalogue = <BlockShape>[
    single,
    line2H,
    line2V,
    line3H,
    line3V,
    line4H,
    line4V,
    line5H,
    line5V,
    square2,
    square3,
    rect2x3,
    rect3x2,
    lSmallNW,
    lSmallNE,
    lSmallSW,
    lSmallSE,
    lLargeNW,
    lLargeNE,
    lLargeSW,
    lLargeSE,
    tUp,
    tDown,
    tLeft,
    tRight,
    sHorizontal,
    sVertical,
    zHorizontal,
    zVertical,
  ];

  /// The catalogue grouped by [ShapeSize].
  static List<BlockShape> ofSize(ShapeSize size) =>
      catalogue.where((BlockShape s) => s.size == size).toList(growable: false);

  /// Widest shape in the catalogue, in cells.
  ///
  /// A ceiling on the catalogue, not a layout budget: the tray sizes itself
  /// from the pieces it is actually holding, so a hand of small blocks is not
  /// shrunk to fit a line of five that is not on offer.
  static const int maxColumns = 5;

  /// Tallest shape in the catalogue, in cells.
  static const int maxRows = 5;

  /// A fixed trio used by tests that need a predictable tray.
  ///
  /// Production always deals from [PieceGenerator] instead.
  @visibleForTesting
  static List<BlockPiece?> sampleTray() => <BlockPiece?>[
    line2H.toPiece(AppColors.blockPalette[0]),
    lSmallSW.toPiece(AppColors.blockPalette[1]),
    square2.toPiece(AppColors.blockPalette[2]),
  ];
}
