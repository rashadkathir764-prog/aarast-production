import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/aarast_motion.dart';
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
    final effectivePadding = padding.add(
      EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 28),
    );

    // خلفية عاجية نظيفة مثل بقية التطبيق — لا زخارف مرسومة.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.ivory,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: effectivePadding,
                    child: AarastFadeSlide(child: child),
                  ),
                ),
              ),
              if (leading != null)
                Positioned(top: 8, right: 16, child: leading!),
            ],
          ),
        ),
      ),
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
                        color: AppTheme.burgundy,
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
                LucideIcons.heart,
                color: AppTheme.gold,
                size: compact ? 12 : 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// زر إظهار/إخفاء كلمة المرور — مضغوط بحجم موحد عبر شاشات الدخول.
class AuthObscureToggle extends StatelessWidget {
  const AuthObscureToggle({
    required this.obscured,
    required this.onPressed,
    super.key,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      icon: Icon(
        obscured ? LucideIcons.eye : LucideIcons.eyeOff,
        color: AppTheme.muted,
      ),
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
        color: AppTheme.surface.withAlpha(244),
        radius: AppTheme.radiusXl,
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
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
    this.maxLines = 1,
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
  final int maxLines;
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
      maxLines: maxLines,
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
        color: AppTheme.burgundySoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertCircle, color: AppTheme.danger, size: 19),
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
      icon: const Icon(LucideIcons.arrowRight),
      tooltip: 'رجوع',
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text('$prefix $action'));
  }
}
