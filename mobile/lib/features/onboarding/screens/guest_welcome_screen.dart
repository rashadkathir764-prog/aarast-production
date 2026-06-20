import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';

class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({this.onContinue, this.onBack, super.key});

  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dMaroonDeep,
        body: Stack(
          children: [
            const Positioned.fill(child: _WeddingPattern()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'أعرست',
                            style: TextStyle(
                              color: AppTheme.dGold2,
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
                            color: Colors.white.withAlpha(18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.dGold2,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.dGold2,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'ألف مبروك!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
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
                            color: Color(0xFFF3E9DF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.7,
                          ),
                        ),
                        const Spacer(),
                        PrimaryActionButton(
                          key: const Key('guest-onboarding-primary-action'),
                          label: 'ابدأ التخطيط',
                          icon: Icons.arrow_back_rounded,
                          backgroundColor: AppTheme.dGold,
                          foregroundColor: AppTheme.dMaroonDeep,
                          onPressed: onContinue ?? () {},
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'يمكنك البدء الآن وإكمال التسجيل لاحقًا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD9C8C0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
      ..color = AppTheme.dGold.withAlpha(17)
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
