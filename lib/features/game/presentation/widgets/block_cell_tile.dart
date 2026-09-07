import 'package:flutter/material.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// How a single square should be painted.
enum CellTileStyle {
  /// An empty board cell.
  empty,

  /// A block: either sitting on the board or being dragged.
  filled,

  /// The board highlight under a droppable block.
  previewValid,

  /// The board highlight under a block that cannot be dropped here.
  previewInvalid,
}

/// A single square tile, used for board cells, previews and block previews.
class BlockCellTile extends StatelessWidget {
  const BlockCellTile({
    super.key,
    this.color,
    this.radius,
    this.style = CellTileStyle.empty,
    this.elevated = false,
  });

  /// Block colour; required for [CellTileStyle.filled].
  final Color? color;

  final double? radius;
  final CellTileStyle style;

  /// Adds a drop shadow so a dragged block reads as lifted off the board.
  final bool elevated;

  /// The one empty cell.
  ///
  /// Every vacant square on the board looks the same, so they can all be the
  /// *same instance*: Flutter skips rebuilding an element whose new widget is
  /// identical to its old one, which takes most of the board out of the work
  /// whenever the grid rebuilds.
  static const BlockCellTile vacant = BlockCellTile();

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(
      radius ?? GameConstants.cellRadius,
    );
    final Color fill = color ?? AppColors.accent;

    switch (style) {
      case CellTileStyle.empty:
        return DecoratedBox(
          decoration: BoxDecoration(
            // A hair lighter at the top than the bottom. Flat fills made the
            // grid read as one dark slab; this is just enough to separate the
            // cells without competing with the blocks sitting on them.
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[AppColors.emptyCellTop, AppColors.emptyCell],
            ),
            borderRadius: shape,
          ),
        );
      case CellTileStyle.previewValid:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: fill.withValues(alpha: 0.45),
            borderRadius: shape,
            border: Border.all(color: AppColors.previewValidBorder, width: 1.5),
          ),
        );
      case CellTileStyle.previewInvalid:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.previewInvalid,
            borderRadius: shape,
            border: Border.all(
              color: AppColors.previewInvalidBorder,
              width: 1.5,
            ),
          ),
        );
      case CellTileStyle.filled:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color.lerp(fill, Colors.white, 0.28)!, fill],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: elevated
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
        );
    }
  }
}
