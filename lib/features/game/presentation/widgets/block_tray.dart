import 'package:flutter/material.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/block_piece.dart';
import 'block_piece_view.dart';

/// Signature for "the player put a finger down on tray slot [slotIndex]".
typedef TraySlotDragStart = void Function(int slotIndex, Offset globalPosition);

/// The strip under the board holding the block pieces on offer.
///
/// Slots keep their size whether or not they hold a piece, so picking a block
/// up never reflows the tray or nudges the board.
class BlockTray extends StatelessWidget {
  const BlockTray({
    super.key,
    required this.pieces,
    this.slotHeight = GameConstants.trayHeight,
    this.onSlotDragStart,
    this.draggingSlotIndex,
  });

  /// Fixed-length slot list; `null` means the slot's piece has been played.
  final List<BlockPiece?> pieces;

  final double slotHeight;
  final TraySlotDragStart? onSlotDragStart;

  /// Slot currently in the air — rendered empty, since the piece is drawn by
  /// the drag layer instead.
  final int? draggingSlotIndex;

  /// Largest bounding box among the pieces on offer, floored at
  /// [GameConstants.trayMinimumSpan].
  ///
  /// Sizing from the pieces actually in the tray — rather than from the
  /// biggest shape in the whole catalogue — is what keeps a tray of small
  /// blocks looking like blocks instead of confetti. The floor stops a tray
  /// of single cells from blowing up to comic proportions.
  (int, int) _span() {
    int rows = GameConstants.trayMinimumSpan;
    int columns = GameConstants.trayMinimumSpan;
    for (final BlockPiece? piece in pieces) {
      if (piece == null) continue;
      if (piece.rowCount > rows) rows = piece.rowCount;
      if (piece.columnCount > columns) columns = piece.columnCount;
    }
    return (rows, columns);
  }

  @override
  Widget build(BuildContext context) {
    final (int rows, int columns) = _span();

    return Container(
      height: slotHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: GameConstants.trayPadding,
        vertical: GameConstants.trayPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.trayBackground,
        borderRadius: BorderRadius.circular(GameConstants.trayRadius),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Every slot gets an equal share of the width; the cell is then the
          // largest square that lets the widest and the tallest piece on
          // offer fit inside one slot, gaps included.
          const double gap = GameConstants.pieceGap;
          final double slotWidth = constraints.maxWidth / pieces.length;

          final double cellSize = <double>[
            (slotWidth - GameConstants.traySlotMargin - (columns - 1) * gap) /
                columns,
            (constraints.maxHeight - (rows - 1) * gap) / rows,
            GameConstants.trayMaxCellSize,
          ].reduce((double a, double b) => a < b ? a : b);

          return Row(
            children: <Widget>[
              for (int index = 0; index < pieces.length; index++)
                Expanded(
                  child: _TraySlot(
                    index: index,
                    piece: pieces[index],
                    cellSize: cellSize.clamp(
                      GameConstants.trayMinCellSize,
                      GameConstants.trayMaxCellSize,
                    ),
                    hidden: index == draggingSlotIndex,
                    onDragStart: onSlotDragStart,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TraySlot extends StatelessWidget {
  const _TraySlot({
    required this.index,
    required this.piece,
    required this.cellSize,
    required this.hidden,
    this.onDragStart,
  });

  final int index;
  final BlockPiece? piece;
  final double cellSize;
  final bool hidden;
  final TraySlotDragStart? onDragStart;

  @override
  Widget build(BuildContext context) {
    final BlockPiece? current = piece;

    return Listener(
      // Opaque so the whole slot — not just the filled squares — starts a drag.
      behavior: HitTestBehavior.opaque,
      onPointerDown: current == null
          ? null
          : (PointerDownEvent event) =>
                onDragStart?.call(index, event.position),
      child: Center(
        // A played slot — or one whose piece is currently in the air — keeps a
        // faint marker. The tray still reads as three slots instead of looking
        // like blocks went missing, and a dragged piece can see where it came
        // from.
        child: current == null || hidden
            ? _EmptySlotMarker(size: cellSize)
            : BlockPieceView(piece: current, cellSize: cellSize),
      ),
    );
  }
}

/// The quiet placeholder left behind by a played block.
class _EmptySlotMarker extends StatelessWidget {
  const _EmptySlotMarker({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.traySlotEmpty,
          borderRadius: BorderRadius.circular(GameConstants.cellRadius),
        ),
      ),
    );
  }
}
