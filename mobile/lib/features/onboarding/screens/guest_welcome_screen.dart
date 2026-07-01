import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({this.onContinue, this.onBack, super.key});

  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.ivory,
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _WeddingPattern()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        'أعرست',
                        style: TextStyle(
                          color: AppTheme.burgundy,
                          fontFamily: AppTheme.displayFontFamily,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.ink.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.burgundy, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.burgundy,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'ألف مبروك!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontFamily: AppTheme.displayFontFamily,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'رحلتكم نحو يومٍ لا يُنسى تبدأ من هنا.\nنرتّب الخطة معكم خطوة بخطوة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.7,
                      ),
                    ),
                    const Spacer(),
                    AarastButton(
                      key: const Key('guest-onboarding-primary-action'),
                      label: 'ابدأ التخطيط',
                      icon: Icons.arrow_back_rounded,
                      onPressed: onContinue ?? () {},
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'يمكنك البدء الآن وإكمال التسجيل لاحقًا',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeddingPattern extends StatelessWidget {
  const _WeddingPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WeddingPatternPainter());
  }
}

class _WeddingPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withAlpha(17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 58.0;
    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), 17, paint);
        canvas.drawCircle(Offset(x + 29, y + 29), 8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
