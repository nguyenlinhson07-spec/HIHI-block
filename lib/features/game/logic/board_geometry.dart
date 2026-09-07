import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/constants/game_constants.dart';
import '../domain/models/block_cell.dart';

/// Pure geometry of a rendered board: converts between board-local pixels and
/// row/column indices.
///
/// Everything is derived from the board's actual on-screen [side], so the
/// mapping stays correct on any screen size — nothing is hardcoded per device.
@immutable
class BoardGeometry {
  const BoardGeometry({
    required this.side,
    this.boardSize = GameConstants.boardSize,
    this.padding = GameConstants.boardPadding,
    this.gap = GameConstants.cellGap,
  });

  /// Width (== height) of the whole board widget in logical pixels.
  final double side;

  /// Number of cells per axis.
  final int boardSize;

  /// Inner padding of the board container.
  final double padding;

  /// Spacing between two neighbouring cells.
  final double gap;

  /// Distance from the left edge of one cell to the left edge of the next.
  double get pitch => (side - 2 * padding + gap) / boardSize;

  /// Side length of a single cell.
  double get cellSize => pitch - gap;

  /// Board-local top-left pixel of the cell at ([row], [column]).
  Offset originOf(int row, int column) =>
      Offset(padding + column * pitch, padding + row * pitch);

  /// Nearest anchor (top-left cell) for a piece whose bounding box starts at
  /// [pieceTopLeft], given in board-local coordinates.
  ///
  /// Rounding — rather than flooring — means the piece snaps to whichever cell
  /// it overlaps most, which feels far more forgiving under a finger.
  BlockCell anchorFor(Offset pieceTopLeft) => BlockCell(
    ((pieceTopLeft.dy - padding) / pitch).round(),
    ((pieceTopLeft.dx - padding) / pitch).round(),
  );

  /// Pixel size of a piece bounding box that is [rows] x [columns] cells.
  Size sizeOfSpan(int rows, int columns) => Size(
    columns * cellSize + (columns - 1) * gap,
    rows * cellSize + (rows - 1) * gap,
  );
}
