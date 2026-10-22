import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';

/// A sign-in screen (prototype a08b to a10): the round back button on top,
/// the form under it, and the main action held at the bottom.
class AuthWeddingScaffold extends StatelessWidget {
  const AuthWeddingScaffold({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.maxWidth = 560,
    this.leading,
    this.bottom,
    this.useSafeArea = true,
    this.contentAlignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Widget? leading;

  /// The screen's main action, kept above the keyboard and the edge.
  final Widget? bottom;
  final bool useSafeArea;
  final AlignmentGeometry contentAlignment;

  @override
  Widget build(BuildContext context) {
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: leading,
                ),
              ),
            Expanded(
              child: Align(
                alignment: contentAlignment,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: padding.add(const EdgeInsets.only(bottom: 20)),
                  child: AarastFadeSlide(child: child),
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: bottom,
              ),
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AarastV3Color.canvas,
        body: useSafeArea ? SafeArea(child: body) : body,
      ),
    );
  }
}

/// The app's name as everywhere else: «اعّرست» with the saffron dot.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return JourneyWordmark(size: compact ? 26 : 34);
  }
}

/// A sign-in screen's title and the line under it (prototype a08b, a10).
class AuthHeading extends StatelessWidget {
  const AuthHeading({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
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
        color: AppTheme.textSecondary,
      ),
    );
  }
}

/// The fields of a sign-in form. The fields carry their own boxes, so the
/// panel only spaces them.
class AuthPanel extends StatelessWidget {
  const AuthPanel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
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
    this.textDirection,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.compact = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final bool compact;

  static const _labelTop = 9.0;

  @override
  Widget build(BuildContext context) {
    final effectiveTextDirection =
        textDirection ??
        (keyboardType == TextInputType.phone
            ? TextDirection.ltr
            : Directionality.of(context));
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
    final valueSize = JourneyType.bodyLarge;
    // The field's own icon sits on the far edge (prototype a08b); a tool
    // such as the password eye sits beside it.
    final endTools = Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suffixIcon != null)
            IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: AarastV3Color.textMuted,
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  minimumSize: const Size.square(40),
                  padding: EdgeInsets.zero,
                  iconSize: 19,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                ),
              ),
              child: suffixIcon!,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Icon(icon, size: 22, color: AarastV3Color.textMuted),
          ),
        ],
      ),
    );

    // The small label stays above the value inside the box, typed or not;
    // the error, when any, shows under the box.
    return Semantics(
      label: label,
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            textAlign: TextAlign.right,
            textDirection: effectiveTextDirection,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            maxLines: maxLines,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            style: JourneyType.of(valueSize, weight: JourneyType.bold),
            cursorColor: AarastV3Color.primary,
            decoration: InputDecoration(
              hintText: hint,
              // A number's hint reads in the number's own direction.
              hintTextDirection: effectiveTextDirection,
              hintStyle: JourneyType.of(
                valueSize,
                weight: JourneyType.bold,
                color: AarastV3Color.textFaint,
              ),
              errorStyle: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
              errorMaxLines: 3,
              suffixIcon: endTools,
              suffixIconConstraints: const BoxConstraints(minHeight: 48),
              filled: true,
              fillColor: AarastV3Color.paper,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                16,
                _labelTop + 19,
                12,
                11,
              ),
              border: border(AarastV3Color.line, 1),
              enabledBorder: border(AarastV3Color.line, 1),
              focusedBorder: border(AarastV3Color.primary, 2),
              errorBorder: border(AarastV3Color.danger, 2),
              focusedErrorBorder: border(AarastV3Color.danger, 2),
            ),
          ),
          PositionedDirectional(
            top: _labelTop,
            start: 17,
            end: 64,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.caption,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthInlineError extends StatelessWidget {
  const AuthInlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round back button of every journey screen.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return JourneyRoundButton(
      icon: LucideIcons.arrowRight,
      tooltip: 'رجوع',
      onPressed: onPressed,
    );
  }
}

/// «لديك حساب؟ تسجيل الدخول»: the question quiet, the action in teal.
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
    final enabled = onTap != null;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text.rich(
        TextSpan(
          text: '$prefix ',
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
          children: [
            TextSpan(
              text: action,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: enabled
                    ? AarastV3Color.primary
                    : AarastV3Color.textFaint,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
