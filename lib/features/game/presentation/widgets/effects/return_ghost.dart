import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/block_piece.dart';
import '../block_piece_view.dart';

/// The block gliding back to its tray slot after a release that could not be
/// placed.
///
/// It flashes red on the way, briefly and softly — enough to read as "not
/// there", not enough to feel like a punishment. The board is untouched
/// throughout; this is purely the piece finding its way home.
class ReturnGhost extends StatefulWidget {
  const ReturnGhost({
    super.key,
    required this.piece,
    required this.cellSize,
    required this.pitch,
    required this.from,
    required this.to,
    required this.onDone,
  });

  final BlockPiece piece;

  /// Cell size the ghost was being dragged at.
  final double cellSize;

  /// Cell pitch the ghost was being dragged at.
  final double pitch;

  /// Where the block was released, in overlay coordinates.
  final Offset from;

  /// Centre of the tray slot it belongs to, in overlay coordinates.
  final Offset to;

  final VoidCallback onDone;

  static const Duration duration = Duration(milliseconds: 180);

  @override
  State<ReturnGhost> createState() => _ReturnGhostState();
}

class _ReturnGhostState extends State<ReturnGhost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ReturnGhost.duration,
  )..forward().whenCompleteOrCancel(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeInOut.transform(_controller.value);
            final Offset offset = Offset.lerp(widget.from, widget.to, t)!;
            // Red at the moment of rejection, back to its own colour as it
            // settles into the tray.
            final double redness = (1 - _controller.value * 1.6).clamp(
              0.0,
              1.0,
            );

            return Transform.translate(
              offset: offset,
              child: Transform.scale(
                scale: 1 - 0.35 * t,
                child: Opacity(
                  opacity: 1 - 0.25 * t,
                  child: BlockPieceView(
                    piece: widget.piece,
                    cellSize: widget.cellSize,
                    gap: widget.pitch - widget.cellSize,
                    elevated: true,
                    overrideColor: redness > 0.02
                        ? Color.lerp(
                            widget.piece.color,
                            AppColors.blockRejected,
                            redness,
                          )
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
