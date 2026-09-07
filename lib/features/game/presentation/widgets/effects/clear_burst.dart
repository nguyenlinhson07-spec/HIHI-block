import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/constants/game_constants.dart';
import '../../../domain/models/block_cell.dart';
import '../../../logic/board_geometry.dart';

/// The line-clear effect: the removed cells flare, swell and shrink away
/// while a handful of sparks drift out of them.
///
/// The board itself is already empty by the time this runs — the controller
/// is the source of truth and never waits for an animation. What is painted
/// here is a ghost of the cells that were just taken, so the clear reads as
/// a moment instead of a jump cut.
///
/// Every cell of the clear — rows and columns together, intersections
/// included exactly once — animates in this single pass.
class ClearBurst extends StatefulWidget {
  const ClearBurst({
    super.key,
    required this.cells,
    required this.geometry,
    required this.color,
    required this.lineCount,
    required this.onDone,
    this.seed = 0,
  });

  final List<BlockCell> cells;
  final BoardGeometry geometry;
  final Color color;

  /// Rows + columns cleared; drives how big the effect reads.
  final int lineCount;

  final VoidCallback onDone;

  /// Fixed seed keeps a given burst reproducible in tests and goldens.
  final int seed;

  static const Duration duration = Duration(milliseconds: 260);

  /// Sparks to spawn for [lineCount] lines: 1 line is a modest puff, 3 or
  /// more is a proper burst. Bounded so this never becomes hundreds of items.
  static int particleCountFor(int lineCount) {
    if (lineCount <= 1) return 10;
    if (lineCount == 2) return 16;
    return 24;
  }

  @override
  State<ClearBurst> createState() => _ClearBurstState();
}

class _ClearBurstState extends State<ClearBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClearBurst.duration,
  )..forward().whenCompleteOrCancel(widget.onDone);

  late final List<_Spark> _sparks = _buildSparks();

  List<_Spark> _buildSparks() {
    if (widget.cells.isEmpty) return const <_Spark>[];

    final Random random = Random(widget.seed);
    final BoardGeometry geo = widget.geometry;
    final int count = ClearBurst.particleCountFor(widget.lineCount);
    final double half = geo.cellSize / 2;

    return List<_Spark>.generate(count, (int index) {
      // Sparks start from the cleared cells themselves, spread around them.
      final BlockCell cell = widget.cells[random.nextInt(widget.cells.length)];
      final Offset origin =
          geo.originOf(cell.row, cell.column) + Offset(half, half);
      final double angle = random.nextDouble() * 2 * pi;
      final double distance = geo.cellSize * (0.7 + random.nextDouble() * 1.1);

      return _Spark(
        origin: origin,
        velocity: Offset(cos(angle), sin(angle)) * distance,
        radius: 1.6 + random.nextDouble() * 2.4,
        delay: random.nextDouble() * 0.18,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BoardGeometry geo = widget.geometry;
    // Two or more lines glow noticeably harder — without ever flashing the
    // whole screen.
    final double intensity = widget.lineCount >= 3
        ? 1.0
        : widget.lineCount == 2
        ? 0.8
        : 0.6;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, _) {
            final double t = _controller.value;
            return CustomPaint(
              painter: _ClearPainter(
                cells: widget.cells,
                sparks: _sparks,
                geometry: geo,
                color: widget.color,
                progress: t,
                intensity: intensity,
              ),
              size: Size.square(geo.side),
            );
          },
        ),
      ),
    );
  }
}

/// One drifting spark.
class _Spark {
  const _Spark({
    required this.origin,
    required this.velocity,
    required this.radius,
    required this.delay,
  });

  final Offset origin;
  final Offset velocity;
  final double radius;
  final double delay;
}

/// Paints the whole burst in one pass — cheaper and steadier than a widget
/// per cell and per spark.
class _ClearPainter extends CustomPainter {
  const _ClearPainter({
    required this.cells,
    required this.sparks,
    required this.geometry,
    required this.color,
    required this.progress,
    required this.intensity,
  });

  final List<BlockCell> cells;
  final List<_Spark> sparks;
  final BoardGeometry geometry;
  final Color color;
  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    _paintCells(canvas);
    _paintSparks(canvas);
  }

  void _paintCells(Canvas canvas) {
    // Flare out to ~1.15 in the first third, then shrink and fade away.
    final double flare = Curves.easeOut.transform(
      (progress / 0.35).clamp(0.0, 1.0),
    );
    final double fade = Curves.easeIn.transform(
      ((progress - 0.25) / 0.75).clamp(0.0, 1.0),
    );
    final double scale = 1 + 0.15 * flare - 0.75 * fade;
    final double opacity = (1 - fade).clamp(0.0, 1.0);
    if (scale <= 0 || opacity <= 0) return;

    final Paint paint = Paint()
      ..color = Color.lerp(
        color,
        Colors.white,
        0.45 * intensity,
      )!.withValues(alpha: opacity);

    final double cell = geometry.cellSize;
    for (final BlockCell c in cells) {
      final Offset origin = geometry.originOf(c.row, c.column);
      final Rect rect = Rect.fromCenter(
        center: origin + Offset(cell / 2, cell / 2),
        width: cell * scale,
        height: cell * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(GameConstants.cellRadius),
        ),
        paint,
      );
    }
  }

  void _paintSparks(Canvas canvas) {
    final Paint paint = Paint();
    for (final _Spark spark in sparks) {
      final double t = ((progress - spark.delay) / (1 - spark.delay)).clamp(
        0.0,
        1.0,
      );
      if (t <= 0) continue;

      final double eased = Curves.easeOutCubic.transform(t);
      final Offset position = spark.origin + spark.velocity * eased;
      final double opacity = (1 - t) * intensity;
      if (opacity <= 0) continue;

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(position, spark.radius * (1 - 0.5 * t), paint);
    }
  }

  @override
  bool shouldRepaint(_ClearPainter old) =>
      old.progress != progress || old.cells != cells;
}
