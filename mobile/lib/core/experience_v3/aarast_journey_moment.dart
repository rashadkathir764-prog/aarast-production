import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'aarast_journey.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _momentArtHeight = 200.0;

/// A full-screen moment between stages of the journey (prototype
/// `v3/touches.dart` `_moment`): the qamariya arcs and confetti on top, a
/// short eyebrow, a big title, a line under it, the facts in a glass box
/// and one white button. The prototype's sky gradient becomes one solid
/// colour (D3).
class JourneyMoment extends StatelessWidget {
  const JourneyMoment({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
    required this.onAction,
    this.color,
    this.picture,
    super.key,
  });

  /// The picture on top; the qamariya arcs and confetti when null. The
  /// wedding week and day (y06, y07) hang the wedding lights there.
  final Widget? picture;

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final String action;
  final VoidCallback onAction;

  /// The moment's sky; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.accent.primary;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: color,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _momentArtHeight,
                        child: Stack(
                          children: [
                            if (picture case final picture?)
                              Positioned.fill(
                                bottom: 28,
                                child: ExcludeSemantics(child: picture),
                              )
                            else ...const [
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: CustomPaint(
                                    painter: JourneyQamariyaPainter(),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: CustomPaint(
                                    painter: JourneyConfettiPainter(),
                                  ),
                                ),
                              ),
                            ],
                            Align(
                              alignment: const Alignment(0, 0.75),
                              child: Text(
                                eyebrow,
                                style: JourneyType.of(
                                  JourneyType.body,
                                  weight: JourneyType.bold,
                                  color: context.accent.onPrimaryMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x4),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: JourneyType.of(
                            JourneyType.display,
                            weight: JourneyType.bold,
                            color: AarastV3Color.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: JourneyType.of(
                          JourneyType.body,
                          color: context.accent.onPrimaryMuted,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x6),
                      body,
                      const SizedBox(height: AarastV3Space.x4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  AarastV3Space.x2,
                  AarastV3Space.x4,
                  AarastV3Space.x4,
                ),
                child: JourneyButton(
                  key: const ValueKey('journey-moment-action'),
                  label: action,
                  background: AarastV3Color.paper,
                  foreground: color,
                  expand: true,
                  large: true,
                  onPressed: onAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The moment's facts: an icon, a name and a value per row, on glass.
class JourneyGlassRows extends StatelessWidget {
  const JourneyGlassRows({required this.rows, super.key});

  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AarastV3Color.paper.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        border: Border.all(color: AarastV3Color.paper.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x4,
          vertical: AarastV3Space.x2,
        ),
        child: Column(
          children: [
            for (final (icon, name, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
                child: Row(
                  children: [
                    Icon(icon, size: 19, color: AarastV3Color.onPrimary),
                    const SizedBox(width: AarastV3Space.x3),
                    Expanded(
                      child: Text(
                        name,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                          color: AarastV3Color.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Text(
                      value,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: context.accent.onPrimaryMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sanaa's signature: the half-moon of a qamariya window as faint arcs
/// with its stained-glass ribs, centred at the bottom.
///
/// The home countdown (b01, b02) moves the window toward the card's far
/// end ([centreX], a share of the width from the left) and adds the gypsum
/// zigzag [frieze] along the bottom edge.
class JourneyQamariyaPainter extends CustomPainter {
  const JourneyQamariyaPainter({
    this.alpha = 0.14,
    this.centreX = 0.5,
    this.frieze = false,
  });

  final double alpha;
  final double centreX;
  final bool frieze;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AarastV3Color.paper.withValues(alpha: alpha);
    final radius = size.height * 0.95;
    final centre = Offset(size.width * centreX, size.height + radius * 0.18);
    for (final fraction in [1.0, 0.78, 0.56]) {
      paint.strokeWidth = fraction == 1.0 ? 2.2 : 1.4;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius * fraction),
        math.pi,
        math.pi,
        false,
        paint,
      );
    }
    paint.strokeWidth = 1.2;
    for (var rib = 1; rib < 6; rib++) {
      final angle = math.pi + math.pi * rib / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * (radius * 0.56),
        centre + direction * radius,
        paint,
      );
    }
    if (frieze) {
      final fill = Paint()
        ..color = AarastV3Color.paper.withValues(alpha: alpha * 0.9);
      const tooth = 10.0;
      final base = size.height - 3;
      for (double x = 0; x < size.width; x += tooth) {
        canvas.drawPath(
          Path()
            ..moveTo(x, base)
            ..lineTo(x + tooth / 2, base - 5)
            ..lineTo(x + tooth, base)
            ..close(),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant JourneyQamariyaPainter old) =>
      old.alpha != alpha || old.centreX != centreX || old.frieze != frieze;
}

/// Saffron, white and mint confetti, the same scatter every time.
class JourneyConfettiPainter extends CustomPainter {
  const JourneyConfettiPainter();

  static const _colors = [
    AarastV3Color.saffron,
    AarastV3Color.paper,
    AarastV3Color.mintSoft,
    AarastV3Color.brandAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var piece = 0; piece < 46; piece++) {
      final paint = Paint()
        ..color = _colors[piece % _colors.length].withValues(alpha: 0.85);
      canvas
        ..save()
        ..translate(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height * 0.55,
        )
        ..rotate(random.nextDouble() * math.pi);
      if (piece.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -2, 10, 4),
            const Radius.circular(AarastV3Radius.xs),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 2.6, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant JourneyConfettiPainter old) => false;
}
