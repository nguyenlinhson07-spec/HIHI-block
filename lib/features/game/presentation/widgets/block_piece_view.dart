import 'package:flutter/material.dart';

import '../../../../core/constants/game_constants.dart';
import '../../domain/models/block_piece.dart';
import 'block_cell_tile.dart';

/// A static rendering of a [BlockPiece] on a grid of [cellSize] squares.
///
/// Used both for the tray previews and for the block that follows the pointer.
class BlockPieceView extends StatelessWidget {
  const BlockPieceView({
    super.key,
    required this.piece,
    required this.cellSize,
    this.gap = GameConstants.pieceGap,
    this.elevated = false,
    this.overrideColor,
  });

  final BlockPiece piece;
  final double cellSize;
  final double gap;

  /// Draws the block with a shadow, so a dragged block looks lifted.
  final bool elevated;

  /// Paints every square in this colour instead of the piece's own — used to
  /// tint a dragged block red when it cannot be dropped.
  final Color? overrideColor;

  @override
  Widget build(BuildContext context) {
    final int rows = piece.rowCount;
    final int columns = piece.columnCount;

    return SizedBox(
      width: columns * cellSize + (columns - 1) * gap,
      height: rows * cellSize + (rows - 1) * gap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int row = 0; row < rows; row++) ...<Widget>[
            if (row > 0) SizedBox(height: gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int column = 0; column < columns; column++) ...<Widget>[
                  if (column > 0) SizedBox(width: gap),
                  SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: piece.contains(row, column)
                        ? BlockCellTile(
                            color: overrideColor ?? piece.color,
                            style: CellTileStyle.filled,
                            elevated: elevated,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
