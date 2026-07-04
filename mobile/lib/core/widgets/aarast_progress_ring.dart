import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aarast_design_tokens.dart';
import '../theme/aarast_motion.dart';

/// حلقة التقدم الملكية — قوس متدرج يُرسم أمام العين مع نقطة مضيئة على رأسه.
///
/// تُستخدم في بطاقة العد التنازلي (الرئيسية) ونبض الميزانية (المال)
/// حتى تتكلم كل الشاشات لغة واحدة.
class AarastProgressRing extends StatelessWidget {
  const AarastProgressRing({
    required this.progress,
    required this.size,
    this.child,
    this.strokeWidth = 9,
    this.trackColor,
    this.gradientColors = const [
      AarastDesignTokens.goldDeep,
      AarastDesignTokens.gold,
      AarastDesignTokens.goldLight,
    ],
    this.tipColor = AarastDesignTokens.goldGlow,
    this.duration = const Duration(milliseconds: 1500),
    super.key,
  });

  /// 0..1
  final double progress;
  final double size;
  final Widget? child;
  final double strokeWidth;
  final Color? trackColor;
  final List<Color> gradientColors;
  final Color tipColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, ringChild) {
        return CustomPaint(
          painter: _RingPainter(
            progress: animated,
            strokeWidth: strokeWidth,
            trackColor:
                trackColor ?? Colors.white.withValues(alpha: 0.14),
            gradientColors: gradientColors,
            tipColor: tipColor,
          ),
          child: ringChild,
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.gradientColors,
    required this.tipColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final List<Color> gradientColors;
  final Color tipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - (strokeWidth / 2) - 2.5;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: gradientColors,
        transform: const GradientRotation(startAngle),
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    // نقطة مضيئة على رأس القوس — إحساس "حي".
    final tipAngle = startAngle + sweepAngle;
    final tipOffset = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tipOffset,
      strokeWidth / 2 + 1.5,
      Paint()..color = tipColor,
    );
    canvas.drawCircle(
      tipOffset,
      strokeWidth / 2 + 4,
      Paint()
        ..color = gradientColors[1].withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.gradientColors != gradientColors;
}
