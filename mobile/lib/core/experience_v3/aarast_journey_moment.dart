import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'aarast_journey.dart';
import 'aarast_v3_foundations.dart';

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
    this.color = AarastV3Color.primary,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final String action;
  final VoidCallback onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: color,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: JourneyQamariyaPainter(),
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: JourneyConfettiPainter(),
                                ),
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0, 0.75),
                              child: Text(
                                eyebrow,
                                style: JourneyType.of(
                                  JourneyType.body,
                                  weight: JourneyType.bold,
                                  color: AarastV3Color.onPrimaryMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: JourneyType.of(
                          JourneyType.body,
                          color: AarastV3Color.onPrimaryMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      body,
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AarastV3Color.paper.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (icon, name, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 19, color: AarastV3Color.onPrimary),
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.onPrimaryMuted,
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
class JourneyQamariyaPainter extends CustomPainter {
  const JourneyQamariyaPainter({this.alpha = 0.14});

  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AarastV3Color.paper.withValues(alpha: alpha);
    final radius = size.height * 0.95;
    final centre = Offset(size.width / 2, size.height + radius * 0.18);
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
  }

  @override
  bool shouldRepaint(covariant JourneyQamariyaPainter old) =>
      old.alpha != alpha;
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
            const Radius.circular(2),
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
