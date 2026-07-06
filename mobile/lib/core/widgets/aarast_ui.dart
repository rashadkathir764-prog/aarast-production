import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/aarast_motion.dart';
import 'aarast_pressable.dart';

export 'aarast_bottom_sheet.dart';
export 'aarast_button.dart';
export 'aarast_error_state.dart';
export 'aarast_loading_state.dart';
export 'aarast_metric_tile.dart';
export 'aarast_pressable.dart';
export 'aarast_skeleton.dart';
export 'aarast_status_badge.dart';

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
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaBottom;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.ivory,
        extendBody: extendBody,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: DecoratedBox(
          decoration: AppTheme.screenDecoration(),
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
            icon: const Icon(Icons.arrow_forward_rounded),
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.ink,
                    fontFamily: AppTheme.displayFontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
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
    this.color = AppTheme.surface,
    this.radius = AppTheme.radiusLg,
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
      decoration: AppTheme.premiumCardDecoration(
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
          Icon(icon, color: AppTheme.burgundy, size: 20),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
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
                    color: AppTheme.muted,
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
    this.color = AppTheme.burgundy,
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

class AarastEmptyState extends StatelessWidget {
  const AarastEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.burgundySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(icon, color: AppTheme.burgundy, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
