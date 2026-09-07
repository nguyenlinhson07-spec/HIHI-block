import 'package:flutter/material.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/block_cell.dart';
import '../../domain/models/board_cell.dart';
import '../../domain/models/game_board.dart';
import 'block_cell_tile.dart';

/// Renders the square 8x8 board plus the drag preview.
///
/// The widget forces a 1:1 aspect ratio and lays the cells out with a
/// [GridView], so it scales with the available width without overflowing.
/// [boardKey] is attached to the square container so callers can map a global
/// pointer position into board-local coordinates.
class GameBoardView extends StatelessWidget {
  const GameBoardView({
    super.key,
    required this.board,
    this.boardKey,
    this.previewCells = const <BlockCell>[],
    this.previewIsValid = false,
    this.previewColor,
  });

  final GameBoard board;
  final GlobalKey? boardKey;

  /// Absolute board cells the dragged block would cover.
  final List<BlockCell> previewCells;
  final bool previewIsValid;
  final Color? previewColor;

  @override
  Widget build(BuildContext context) {
    final Set<int> preview = previewCells
        .where((BlockCell c) => board.contains(c.row, c.column))
        .map((BlockCell c) => c.row * board.size + c.column)
        .toSet();

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        key: boardKey,
        padding: const EdgeInsets.all(GameConstants.boardPadding),
        decoration: BoxDecoration(
          color: AppColors.boardBackground,
          borderRadius: BorderRadius.circular(GameConstants.boardRadius),
          border: Border.all(color: AppColors.boardBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: board.size * board.size,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: board.size,
            mainAxisSpacing: GameConstants.cellGap,
            crossAxisSpacing: GameConstants.cellGap,
          ),
          itemBuilder: (BuildContext context, int index) {
            final BoardCell cell = board.cellAt(
              index ~/ board.size,
              index % board.size,
            );
            if (preview.contains(index) && !cell.occupied) {
              return BlockCellTile(
                color: previewColor,
                style: previewIsValid
                    ? CellTileStyle.previewValid
                    : CellTileStyle.previewInvalid,
              );
            }
            return BlockCellTile(
              color: cell.color,
              style: cell.occupied ? CellTileStyle.filled : CellTileStyle.empty,
            );
          },
        ),
      ),
    );
  }
}
