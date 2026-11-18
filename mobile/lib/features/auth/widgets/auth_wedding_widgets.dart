import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/widgets/aarast_pressable.dart';

/// A sign-in screen (prototype a08b to a10): the round back button on top,
/// the form under it, and the main action held at the bottom.
class AuthWeddingScaffold extends StatelessWidget {
  const AuthWeddingScaffold({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AarastV3Space.x4,
      vertical: AarastV3Space.x2,
    ),
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
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  AarastV3Space.x2,
                  AarastV3Space.x4,
                  0,
                ),
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
                  padding: padding.add(
                    const EdgeInsets.only(bottom: AarastV3Space.x5),
                  ),
                  child: AarastFadeSlide(child: child),
                ),
              ),
            ),
            if (bottom != null)
              Padding(padding: AarastV3Density.actionInsets, child: bottom),
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
              JourneyType.pageTitle,
              weight: JourneyType.bold,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AarastV3Space.x1),
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

/// The eye inside a password field: shows or hides what is typed.
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
    // A full 48 target at the field's end (JourneyFieldBox.trailing).
    return IconButton(
      tooltip: obscured ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        minimumSize: const Size.square(AarastV3Size.touch),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      iconSize: AarastV3Icon.md,
      icon: Icon(
        obscured ? LucideIcons.eye : LucideIcons.eyeOff,
        color: AarastV3Color.textMuted,
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
            padding: EdgeInsets.only(top: AarastV3Space.half),
            child: Icon(
              LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              size: AarastV3Icon.md,
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
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
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$prefix $action',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AarastV3Size.touch),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AarastV3Space.x2),
              child: _FooterLinkText(
                prefix: prefix,
                action: action,
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLinkText extends StatelessWidget {
  const _FooterLinkText({
    required this.prefix,
    required this.action,
    required this.enabled,
  });

  final String prefix;
  final String action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$prefix ',
        style: JourneyType.of(JourneyType.body, color: AarastV3Color.textMuted),
        children: [
          TextSpan(
            text: action,
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: enabled ? context.accent.primary : AarastV3Color.textFaint,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
