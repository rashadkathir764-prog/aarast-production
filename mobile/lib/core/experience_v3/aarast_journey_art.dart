import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// The journey's two pictures: the wedding lights hung in front of the
/// groom's house, and the fireworks behind them (prototype `v3/lights.dart`).
/// The night sky is the plan's own ([JourneyAccent.night]).
///
/// Painted with solid colours, opacity and blur only (DECISIONS 2026-10-22,
/// D3): the visual contract bans gradients and shadows.
abstract final class JourneyArt {
  /// The warm bulb colour.
  static const warm = Color(0xFFFFE3A3);
}

/// Bulb strings fanning down from one apex, the shape hung over Sanaa
/// streets for a wedding. The first [lit] strands glow; the rest wait.
class JourneyLightsPainter extends CustomPainter {
  const JourneyLightsPainter({
    this.strands = 9,
    this.lit = 9,
    this.apexY = 0.04,
    this.cross = true,
  });

  final int strands;
  final int lit;
  final double apexY;
  final bool cross;

  void _bulb(Canvas canvas, Offset o, bool on) {
    if (on) {
      canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = JourneyArt.warm.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(o, 2.4, Paint()..color = JourneyArt.warm);
    } else {
      canvas.drawCircle(
        o,
        2,
        Paint()..color = AarastV3Color.paper.withValues(alpha: 0.18),
      );
    }
  }

  Offset _quad(Offset a, Offset c, Offset b, double t) => Offset(
    math.pow(1 - t, 2) * a.dx + 2 * (1 - t) * t * c.dx + t * t * b.dx,
    math.pow(1 - t, 2) * a.dy + 2 * (1 - t) * t * c.dy + t * t * b.dy,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final apex = Offset(size.width * 0.5, size.height * apexY);
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AarastV3Color.paper.withValues(alpha: 0.16);
    // Strands light from the middle outwards so the shape fills evenly.
    final middle = (strands - 1) / 2;
    final order = List<int>.generate(strands, (i) => i)
      ..sort((a, b) => (a - middle).abs().compareTo((b - middle).abs()));
    for (var k = 0; k < strands; k++) {
      final i = order[k];
      final end = Offset(
        size.width * (-0.08 + 1.16 * i / math.max(1, strands - 1)),
        size.height,
      );
      final ctrl = Offset(
        (apex.dx + end.dx) / 2,
        (apex.dy + end.dy) / 2 + size.height * 0.10,
      );
      canvas.drawPath(
        Path()
          ..moveTo(apex.dx, apex.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
        wire,
      );
      for (var t = 0.06; t <= 1.0; t += 0.075) {
        _bulb(canvas, _quad(apex, ctrl, end, t), k < lit);
      }
    }
    if (cross) {
      // Two sagging strings across the street.
      for (final y in [0.30, 0.52]) {
        final a = Offset(0, size.height * y);
        final b = Offset(size.width, size.height * (y - 0.06));
        final m = Offset(size.width / 2, size.height * (y + 0.07));
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy),
          wire,
        );
        for (var t = 0.04; t < 1; t += 0.09) {
          _bulb(canvas, _quad(a, m, b, t), lit > 0);
        }
      }
    }
    canvas.drawCircle(apex, 4, Paint()..color = JourneyArt.warm);
  }

  @override
  bool shouldRepaint(covariant JourneyLightsPainter old) =>
      old.strands != strands || old.lit != lit || old.apexY != apexY;
}

/// One firework: where (0..1 of the size), its colour and its radius.
typedef JourneyBurst = (Offset, Color, double);

/// Fireworks behind the lights.
class JourneyFireworksPainter extends CustomPainter {
  const JourneyFireworksPainter({required this.bursts, this.alpha = 0.8});

  /// The three bursts drawn over the plan's sky; the small one is the
  /// plan's middle shade.
  static List<JourneyBurst> burstsFor(JourneyAccent accent) => [
    (const Offset(0.28, 0.45), AarastV3Color.saffron, 44.0),
    (const Offset(0.66, 0.38), JourneyArt.warm, 52.0),
    (const Offset(0.86, 0.62), accent.primaryMid, 30.0),
  ];

  final List<JourneyBurst> bursts;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    for (final burst in bursts) {
      final c = Offset(burst.$1.dx * size.width, burst.$1.dy * size.height);
      canvas.drawCircle(
        c,
        burst.$3 * 0.5,
        Paint()
          ..color = burst.$2.withValues(alpha: alpha * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      for (var i = 0; i < 28; i++) {
        final a = i * 2 * math.pi / 28 + rnd.nextDouble() * 0.1;
        final r = burst.$3 * (0.75 + rnd.nextDouble() * 0.25);
        final paint = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = burst.$2.withValues(alpha: alpha);
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * r * 0.35, c + dir * r, paint);
        canvas.drawCircle(
          c + dir * r,
          1.6,
          Paint()..color = burst.$2.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant JourneyFireworksPainter old) =>
      old.bursts != bursts || old.alpha != alpha;
}

/// The wedding sky: night, fireworks behind, the lights in front. The
/// lower part melts into [base] with a blurred solid band, not a gradient.
class JourneyWeddingSky extends StatelessWidget {
  const JourneyWeddingSky({
    this.strands = 11,
    this.lit = 11,
    this.bursts,
    this.fireAlpha = 0.8,
    this.base,
    super.key,
  });

  final int strands;
  final int lit;

  /// The fireworks; the plan's three when null.
  final List<JourneyBurst>? bursts;
  final double fireAlpha;

  /// When set, the bottom of the sky fades into this colour.
  final Color? base;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ColoredBox(
        color: context.accent.night,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: JourneyFireworksPainter(
                bursts:
                    bursts ?? JourneyFireworksPainter.burstsFor(context.accent),
                alpha: fireAlpha,
              ),
            ),
            CustomPaint(
              painter: JourneyLightsPainter(
                strands: strands,
                lit: lit,
                apexY: 0.03,
              ),
            ),
            if (base != null) CustomPaint(painter: _FadeIntoPainter(base!)),
          ],
        ),
      ),
    );
  }
}

/// A solid band at the bottom, softened by blur so the sky melts into it.
class _FadeIntoPainter extends CustomPainter {
  const _FadeIntoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height * 0.55;
    // Reach four blur radii past every other edge, so only the top fades.
    final reach = size.height * 0.32;
    canvas.drawRect(
      Rect.fromLTRB(-reach, top, size.width + reach, size.height + reach),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.08),
    );
    // The solid floor starts only where the blur is already opaque (more
    // than three blur radii below its edge), so no seam shows.
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.80, size.width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FadeIntoPainter old) => old.color != color;
}

/// The bride's card picture: a white ball gown on a form, drawn with solid
/// tones and blur (no gradients, D3).
class JourneyDressPainter extends CustomPainter {
  const JourneyDressPainter();

  static const _backdrop = Color(0xFFE9E9E6);
  static const _shade = Color(0xFFCFCFD4);
  static const _form = Color(0xFFEDE7DC);
  static const _bead = Color(0xFFA6AAB5);
  static const _cap = Color(0xFFD9B15F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(11);
    canvas.drawRect(Offset.zero & size, Paint()..color = _backdrop);
    final cx = w * 0.5;
    final waistY = h * 0.47;
    final topY = h * 0.20;
    final bw = w * 0.17;
    final ww = w * 0.12;

    // The form's neck, cap and shoulders.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.09),
          width: w * 0.09,
          height: h * 0.10,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = _form,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.015),
          width: w * 0.11,
          height: h * 0.05,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = _cap,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.045, h * 0.13)
        ..quadraticBezierTo(
          cx - w * 0.06,
          topY - h * 0.01,
          cx - bw * 0.85,
          topY + h * 0.025,
        )
        ..lineTo(cx + bw * 0.85, topY + h * 0.025)
        ..quadraticBezierTo(
          cx + w * 0.06,
          topY - h * 0.01,
          cx + w * 0.045,
          h * 0.13,
        )
        ..close(),
      Paint()..color = _form,
    );

    // Skirt: grey edges, a blurred white body for the round fall, pleats.
    final hemY = h * 1.25;
    final skirt = Path()
      ..moveTo(cx - ww, waistY)
      ..cubicTo(
        cx - w * 0.35,
        h * 0.62,
        cx - w * 0.75,
        h * 0.95,
        cx - w * 0.95,
        hemY,
      )
      ..lineTo(cx + w * 0.95, hemY)
      ..cubicTo(
        cx + w * 0.75,
        h * 0.95,
        cx + w * 0.35,
        h * 0.62,
        cx + ww,
        waistY,
      )
      ..close();
    canvas.drawPath(skirt, Paint()..color = _shade);
    canvas.save();
    canvas.clipPath(skirt);
    canvas.drawRect(
      Rect.fromLTRB(cx - w * 0.45, waistY, cx + w * 0.35, hemY),
      Paint()
        ..color = AarastV3Color.paper
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
    );
    for (var i = -8; i <= 8; i++) {
      final f = i / 8;
      final pleat = Path()
        ..moveTo(cx + f * ww * 0.9, waistY)
        ..quadraticBezierTo(cx + f * w * 0.35, h * 0.75, cx + f * w, hemY);
      canvas.drawPath(
        pleat,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..color = _shade.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    for (var i = 0; i < 220; i++) {
      final t = math.pow(rnd.nextDouble(), 0.8).toDouble();
      final y = waistY + t * (hemY - waistY);
      final half = ww + (w * 0.95 - ww) * math.pow(t, 0.7);
      canvas.drawCircle(
        Offset(cx + (rnd.nextDouble() * 2 - 1) * half, y),
        0.5 + rnd.nextDouble() * 1.0,
        Paint()..color = _bead.withValues(alpha: 0.7),
      );
    }
    canvas.restore();

    // Bodice.
    final bodice = Path()
      ..moveTo(cx - bw, topY + h * 0.03)
      ..quadraticBezierTo(cx - bw * 0.5, topY - h * 0.025, cx, topY + h * 0.04)
      ..quadraticBezierTo(
        cx + bw * 0.5,
        topY - h * 0.025,
        cx + bw,
        topY + h * 0.03,
      )
      ..quadraticBezierTo(cx + bw * 0.92, h * 0.36, cx + ww, waistY)
      ..lineTo(cx, waistY + h * 0.03)
      ..lineTo(cx - ww, waistY)
      ..quadraticBezierTo(cx - bw * 0.92, h * 0.36, cx - bw, topY + h * 0.03)
      ..close();
    canvas.drawPath(bodice, Paint()..color = _shade);
    canvas.save();
    canvas.clipPath(bodice);
    canvas.drawRect(
      Rect.fromLTRB(cx - bw * 0.6, topY, cx + bw * 0.5, waistY + h * 0.03),
      Paint()
        ..color = AarastV3Color.paper
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    for (var i = 0; i < 70; i++) {
      final k = rnd.nextDouble();
      final y = topY + h * 0.04 + k * (waistY - topY - h * 0.04);
      final spread = (bw * (1 - k) + ww * k) * 0.9;
      canvas.drawCircle(
        Offset(cx + (rnd.nextDouble() * 2 - 1) * spread, y),
        0.6 + rnd.nextDouble() * 0.8,
        Paint()..color = _bead,
      );
    }
    canvas.restore();

    // A few glints.
    for (var i = 0; i < 14; i++) {
      final k = rnd.nextDouble();
      final y = waistY - h * 0.2 + k * h * 0.7;
      final half = y < waistY ? bw * 0.8 : ww + (y - waistY) * 1.1;
      final p = Offset(cx + (rnd.nextDouble() * 2 - 1) * half, y);
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = AarastV3Color.paper.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant JourneyDressPainter old) => false;
}
