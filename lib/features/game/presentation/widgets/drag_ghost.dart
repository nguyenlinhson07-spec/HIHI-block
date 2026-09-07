import 'package:flutter/material.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/block_piece.dart';
import 'block_piece_view.dart';

/// The block that follows the pointer while dragging.
///
/// It is laid out on the board's own cell pitch — but drawn a little smaller
/// than a cell — so it lands exactly over the preview while still letting the
/// highlight show as a ring around each square. Over an illegal spot it turns
/// red, which stays readable even though it covers the preview underneath.
class DragGhost extends StatelessWidget {
  const DragGhost({
    super.key,
    required this.piece,
    required this.cellSize,
    required this.pitch,
    this.isOverBoard = false,
    this.isValid = false,
  });

  final BlockPiece piece;

  /// Side of a single ghost square.
  final double cellSize;

  /// Board cell pitch, so the ghost squares line up with the grid.
  final double pitch;

  final bool isOverBoard;
  final bool isValid;

  bool get _rejected => isOverBoard && !isValid;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: _rejected ? 0.8 : GameConstants.dragGhostOpacity,
        child: BlockPieceView(
          piece: piece,
          cellSize: cellSize,
          gap: pitch - cellSize,
          elevated: true,
          overrideColor: _rejected ? AppColors.blockRejected : null,
        ),
      ),
    );
  }
}
