import 'package:flutter/material.dart';

import '../../../../../core/constants/game_constants.dart';
import '../../../domain/models/block_cell.dart';
import '../../../logic/board_geometry.dart';

/// The short bounce a block does the moment it lands on the board.
///
/// Drawn on top of the board rather than inside it, so committing a block
/// never re-animates the other 60-odd cells.
class PlacePulse extends StatefulWidget {
  const PlacePulse({
    super.key,
    required this.cells,
    required this.geometry,
    required this.color,
    required this.onDone,
  });

  final List<BlockCell> cells;
  final BoardGeometry geometry;
  final Color color;
  final VoidCallback onDone;

  static const Duration duration = Duration(milliseconds: 160);

  @override
  State<PlacePulse> createState() => _PlacePulseState();
}

class _PlacePulseState extends State<PlacePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlacePulse.duration,
  )..forward().whenCompleteOrCancel(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BoardGeometry geo = widget.geometry;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, _) {
            final double t = Curves.easeOutBack.transform(_controller.value);
            // 1.08 -> 1.0, settling rather than bouncing.
            final double scale = 1.08 - 0.08 * t;
            final double glow = (1 - _controller.value).clamp(0.0, 1.0);

            return Stack(
              children: <Widget>[
                for (final BlockCell cell in widget.cells)
                  Positioned(
                    left: geo.originOf(cell.row, cell.column).dx,
                    top: geo.originOf(cell.row, cell.column).dy,
                    width: geo.cellSize,
                    height: geo.cellSize,
                    child: Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55 * glow),
                          borderRadius: BorderRadius.circular(
                            GameConstants.cellRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
