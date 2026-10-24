import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../experience_v3/aarast_v3.dart';
import '../theme/app_theme.dart';
import '../theme/aarast_motion.dart';
import 'aarast_pressable.dart';

export 'aarast_bottom_sheet.dart';
export 'aarast_button.dart';
export 'aarast_dialog.dart';
export 'aarast_error_state.dart';
export 'aarast_feature_header.dart';
export 'aarast_filter_pill.dart';
export 'aarast_loading_state.dart';
export 'aarast_metric_tile.dart';
export 'aarast_phone_text.dart';
export 'aarast_pressable.dart';
export 'aarast_skeleton.dart';
export 'aarast_status_badge.dart';
export 'aarast_surface.dart';
export 'release_field_focus.dart';

/// غلاف الصفحات الموحّد — مبني فوق [AarastScreenFrame] حتى تتطابق كل
/// الشاشات في الخلفية والحدود والـ SafeArea، ويضيف ترويسة فاخرة اختيارية.
class AarastPageScaffold extends StatelessWidget {
  const AarastPageScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    this.padding = AppTheme.screenPadding,
    this.maxWidth = 560,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeAreaBottom = true,
    this.extendBody = false,
    this.backgroundColor,
    this.backgroundDecoration,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaBottom;
  final bool extendBody;
  final Color? backgroundColor;
  final Decoration? backgroundDecoration;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null || subtitle != null || actions.isNotEmpty || showBack;

    return AarastScreenFrame(
      maxWidth: maxWidth,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      safeAreaBottom: safeAreaBottom,
      extendBody: extendBody,
      backgroundColor: backgroundColor,
      backgroundDecoration: backgroundDecoration,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              AarastFadeSlide(
                child: AarastPageHeader(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  showBack: showBack,
                  onBack: onBack,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class AarastScaffold extends AarastPageScaffold {
  const AarastScaffold({
    required super.child,
    super.title,
    super.subtitle,
    super.actions,
    super.showBack,
    super.onBack,
    super.padding,
    super.bottomNavigationBar,
    super.floatingActionButton,
    super.resizeToAvoidBottomInset,
    super.key,
  });
}

class AarastScreenFrame extends StatelessWidget {
  const AarastScreenFrame({
    required this.child,
    this.maxWidth = 560,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeAreaBottom = true,
    this.extendBody = false,
    this.backgroundColor,
    this.backgroundDecoration,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaBottom;
  final bool extendBody;
  final Color? backgroundColor;
  final Decoration? backgroundDecoration;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppTheme.canvas,
        extendBody: extendBody,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: DecoratedBox(
          // A chosen colour fills the screen; the default decoration would
          // paint the canvas over it.
          decoration:
              backgroundDecoration ??
              (backgroundColor == null
                  ? AppTheme.screenDecoration()
                  : BoxDecoration(color: backgroundColor)),
          child: SafeArea(
            bottom: safeAreaBottom,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AarastPageHeader extends StatelessWidget {
  const AarastPageHeader({
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.arrowRight),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: AppTheme.gapSm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AarastV3Type.title(context),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AarastV3Type.body(context),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AppTheme.gapMd),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

class AarastCard extends StatelessWidget {
  const AarastCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = AppTheme.surfaceRaised,
    this.radius = AppTheme.radiusSurface,
    this.border,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final double radius;
  final Border? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: AppTheme.motionFast,
      curve: Curves.easeOutCubic,
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: AppTheme.surfaceDecoration(
        color: color,
        radius: radius,
        border: border,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return AarastPressable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(radius),
      clip: false,
      child: content,
    );
  }
}

/// Keeps optional form details available without making the primary task feel
/// like a long administrative form.
class AarastDisclosureCard extends StatelessWidget {
  const AarastDisclosureCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = LucideIcons.slidersHorizontal,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool initiallyExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AarastV3Disclosure(
      title: title,
      subtitle: subtitle,
      icon: icon,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }
}

class AarastSectionHeader extends StatelessWidget {
  const AarastSectionHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, color: AppTheme.brand, size: 22),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class AarastStatusPill extends StatelessWidget {
  const AarastStatusPill({
    required this.label,
    this.color = AppTheme.brand,
    this.backgroundColor,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(42)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AarastEmptyStateTone { neutral, positive, warning, restricted }

class AarastEmptyState extends StatelessWidget {
  const AarastEmptyState({
    required this.title,
    required this.message,
    this.icon = LucideIcons.inbox,
    this.action,
    this.tone = AarastEmptyStateTone.neutral,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final AarastEmptyStateTone tone;

  @override
  Widget build(BuildContext context) {
    final kind = switch (tone) {
      AarastEmptyStateTone.neutral => AarastV3ScreenStateKind.empty,
      AarastEmptyStateTone.positive => AarastV3ScreenStateKind.ready,
      AarastEmptyStateTone.warning => AarastV3ScreenStateKind.pending,
      AarastEmptyStateTone.restricted => AarastV3ScreenStateKind.locked,
    };
    return AarastV3StateSurface(
      kind: kind,
      title: title,
      message: message,
      icon: icon,
      action: action,
    );
  }
}
