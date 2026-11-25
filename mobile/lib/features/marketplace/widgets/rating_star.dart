import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// One star of a rating: a given star is filled saffron, an empty one only
/// its outline, so the two differ in shape and not by colour alone (Lucide
/// draws only the outline). The rating «4 من 5» is said by the row around
/// it.
class RatingStar extends StatelessWidget {
  const RatingStar({required this.filled, required this.size, super.key});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: RatingStarPainter(
          filled ? PaintingStyle.fill : PaintingStyle.stroke,
        ),
      ),
    );
  }
}

/// A five-point star, filled or as its outline.
class RatingStarPainter extends CustomPainter {
  const RatingStarPainter(this.style);

  final PaintingStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.08;
    // The outline is drawn inside the box, as wide as the filled star.
    final outer =
        size.shortestSide / 2 - (style == PaintingStyle.stroke ? stroke : 0);
    final inner = outer * 0.48;
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final radius = point.isEven ? outer : inner;
      final angle = -math.pi / 2 + point * math.pi / 5;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      point == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = style == PaintingStyle.fill
            ? AarastV3Color.saffron
            : AarastV3Color.fieldEdge
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke
        ..style = style,
    );
  }

  @override
  bool shouldRepaint(covariant RatingStarPainter old) => old.style != style;
}
