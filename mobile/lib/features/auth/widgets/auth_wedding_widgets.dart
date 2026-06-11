import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthWeddingScaffold extends StatelessWidget {
  const AuthWeddingScaffold({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
    this.maxWidth = 430,
    this.leading,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthWeddingBackground()),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: padding,
                        child: child,
                      ),
                    ),
                  ),
                  if (leading != null)
                    Positioned(top: 8, right: 16, child: leading!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWeddingBackground extends StatelessWidget {
  const AuthWeddingBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.dBg,
      child: CustomPaint(painter: _AuthWeddingBackgroundPainter()),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            Text(
              'أعرسِت',
              textAlign: TextAlign.center,
              style:
                  (compact ? textTheme.headlineMedium : textTheme.displaySmall)
                      ?.copyWith(
                        color: AppTheme.dMaroon,
                        fontFamily: AppTheme.displayFontFamily,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
            ),
            Positioned(
              top: compact ? -3 : -6,
              right: compact ? -8 : -12,
              child: Icon(
                Icons.favorite_rounded,
                color: AppTheme.dGoldDeep,
                size: compact ? 12 : 16,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        const _HeartRule(),
      ],
    );
  }
}

class WeddingRingsBadge extends StatelessWidget {
  const WeddingRingsBadge({this.size = 82, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.dGold2.withAlpha(150)),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: CustomPaint(painter: _RingsPainter()),
    );
  }
}

class AuthPanel extends StatelessWidget {
  const AuthPanel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: AppTheme.premiumCardDecoration(
        color: AppTheme.dCard2.withAlpha(244),
        radius: AppTheme.radiusXl,
        border: Border.all(color: AppTheme.dLine.withAlpha(220)),
      ),
      child: child,
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AuthInlineError extends StatelessWidget {
  const AuthInlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dPinkBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.danger,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded),
      tooltip: 'رجوع',
    );
  }
}

class AuthFeatureTile extends StatelessWidget {
  const AuthFeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.dPinkBg.withAlpha(130),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.dMaroon, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    required this.prefix,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HeartRule(),
        const SizedBox(height: 14),
        TextButton(onPressed: onTap, child: Text('$prefix $action')),
      ],
    );
  }
}

class _HeartRule extends StatelessWidget {
  const _HeartRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 38, height: 1, color: AppTheme.dGold2),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.favorite_rounded,
            color: AppTheme.dGoldDeep,
            size: 12,
          ),
        ),
        Container(width: 38, height: 1, color: AppTheme.dGold2),
      ],
    );
  }
}

class _AuthWeddingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final archPaint = Paint()
      ..color = AppTheme.dGold2.withAlpha(48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final stemPaint = Paint()
      ..color = AppTheme.dGoldDeep.withAlpha(48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final petalPaint = Paint()
      ..color = AppTheme.dMaroon.withAlpha(18)
      ..style = PaintingStyle.fill;

    final arch = Path()
      ..moveTo(size.width * 0.20, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.02,
        size.width * 0.80,
        size.height * 0.24,
      )
      ..lineTo(size.width * 0.80, size.height * 0.48)
      ..moveTo(size.width * 0.20, size.height * 0.24)
      ..lineTo(size.width * 0.20, size.height * 0.48);
    canvas.drawPath(arch, archPaint);

    _drawFloralCluster(
      canvas,
      Offset(size.width * 0.10, size.height * 0.82),
      -1,
      stemPaint,
      petalPaint,
    );
    _drawFloralCluster(
      canvas,
      Offset(size.width * 0.90, size.height * 0.12),
      1,
      stemPaint,
      petalPaint,
    );
  }

  void _drawFloralCluster(
    Canvas canvas,
    Offset origin,
    int direction,
    Paint stemPaint,
    Paint petalPaint,
  ) {
    final stem = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(
        origin.dx + direction * 26,
        origin.dy - 44,
        origin.dx + direction * 52,
        origin.dy - 92,
      );
    canvas.drawPath(stem, stemPaint);

    for (var i = 0; i < 5; i++) {
      final y = origin.dy - 18.0 - (i * 16);
      final x = origin.dx + direction * (16 + i * 7);
      final leaf = Rect.fromCenter(center: Offset(x, y), width: 18, height: 9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(direction * 0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: leaf.width,
          height: leaf.height,
        ),
        petalPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.dMaroon
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final goldPaint = Paint()
      ..color = AppTheme.dGoldDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final heartPaint = Paint()
      ..color = AppTheme.dMaroon
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2 + size.height * 0.06);
    final radius = size.width * 0.18;
    canvas.drawCircle(center.translate(-radius * 0.48, 0), radius, paint);
    canvas.drawCircle(center.translate(radius * 0.48, 0), radius, paint);
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(0, -radius * 0.12),
        radius: radius * 1.18,
      ),
      -0.15,
      3.45,
      false,
      goldPaint,
    );

    final heart = Path()
      ..moveTo(size.width / 2, size.height * 0.28)
      ..cubicTo(
        size.width * 0.37,
        size.height * 0.18,
        size.width * 0.24,
        size.height * 0.34,
        size.width / 2,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.34,
        size.width * 0.63,
        size.height * 0.18,
        size.width / 2,
        size.height * 0.28,
      );
    canvas.drawPath(heart, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
