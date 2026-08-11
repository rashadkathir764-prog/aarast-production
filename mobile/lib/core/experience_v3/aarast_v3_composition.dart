import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'aarast_v3_foundations.dart';

class AarastV3PageFrame extends StatelessWidget {
  const AarastV3PageFrame({
    required this.child,
    this.maxWidth = 620,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 112),
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeAreaBottom = false,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AarastV3Color.canvas,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          bottom: safeAreaBottom,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class AarastV3ContextBar extends StatelessWidget {
  const AarastV3ContextBar({
    required this.section,
    this.contextLabel,
    this.actions = const [],
    super.key,
  });

  final String section;
  final String? contextLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 34, color: AarastV3Color.primary),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section, style: AarastV3Type.label(context)),
              if (contextLabel != null) ...[
                const SizedBox(height: 1),
                Text(
                  contextLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AarastV3Color.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AarastV3Space.x3),
          Wrap(spacing: AarastV3Space.x2, children: actions),
        ],
      ],
    );
  }
}

class AarastV3NarrativeHeader extends StatelessWidget {
  const AarastV3NarrativeHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.titleColor = AarastV3Color.ink,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: AarastV3Type.label(
                    context,
                  ).copyWith(color: AarastV3Color.primary),
                ),
                const SizedBox(height: AarastV3Space.x2),
              ],
              Text(
                title,
                style: AarastV3Type.display(
                  context,
                ).copyWith(color: titleColor),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                Text(subtitle!, style: AarastV3Type.body(context)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AarastV3Space.x4),
          trailing!,
        ],
      ],
    );
  }
}

class AarastV3MetricData {
  const AarastV3MetricData({
    required this.label,
    required this.value,
    this.accent = AarastV3Color.primary,
  });

  final String label;
  final String value;
  final Color accent;
}

class AarastV3MetricRail extends StatelessWidget {
  const AarastV3MetricRail({
    required this.items,
    this.inverted = false,
    super.key,
  });

  final List<AarastV3MetricData> items;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: inverted
                ? Colors.white.withValues(alpha: .22)
                : AarastV3Color.line,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(
              child: _MetricCell(item: items[index], inverted: inverted),
            ),
            if (index != items.length - 1)
              Container(
                width: 1,
                height: 44,
                color: inverted
                    ? Colors.white.withValues(alpha: .2)
                    : AarastV3Color.line,
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.item, required this.inverted});

  final AarastV3MetricData item;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                item.value,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: inverted && item.accent == AarastV3Color.primary
                      ? Colors.white
                      : item.accent,
                  fontFamily: AarastV3Type.displayFamily,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AarastV3Type.label(context).copyWith(
              color: inverted ? Colors.white70 : AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class AarastV3SectionHeader extends StatelessWidget {
  const AarastV3SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AarastV3Type.section(context)),
              if (subtitle != null) ...[
                const SizedBox(height: AarastV3Space.x1),
                Text(subtitle!, style: AarastV3Type.body(context)),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: AarastV3Space.x3),
          action!,
        ],
      ],
    );
  }
}

class AarastV3ContinuousSurface extends StatelessWidget {
  const AarastV3ContinuousSurface({
    required this.children,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AarastV3Color.line),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, color: AarastV3Color.line),
          ],
        ],
      ),
    );
  }
}

/// A recoverable swipe reveal for dense rows.
///
/// It never dismisses the row by itself. The domain callback owns the real
/// mutation and the row remains mounted until its provider confirms the new
/// state. Every swipe action must also remain available inside the row for
/// keyboard and assistive-technology users.
class AarastV3SwipeActions extends StatelessWidget {
  const AarastV3SwipeActions({
    required this.itemKey,
    required this.child,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.primaryColor = AarastV3Color.mint,
    this.secondaryColor = AarastV3Color.primary,
    super.key,
  });

  final Key itemKey;
  final Widget child;
  final String primaryLabel;
  final IconData primaryIcon;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final Future<void> Function()? onSecondary;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Dismissible(
        key: itemKey,
        direction: onSecondary == null
            ? DismissDirection.startToEnd
            : DismissDirection.horizontal,
        dismissThresholds: const <DismissDirection, double>{
          DismissDirection.startToEnd: .32,
          DismissDirection.endToStart: .32,
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await onPrimary();
          } else {
            await onSecondary?.call();
          }
          return false;
        },
        background: _AarastV3SwipeCue(
          alignment: AlignmentDirectional.centerStart,
          label: primaryLabel,
          icon: primaryIcon,
          color: primaryColor,
        ),
        secondaryBackground: onSecondary == null
            ? null
            : _AarastV3SwipeCue(
                alignment: AlignmentDirectional.centerEnd,
                label: secondaryLabel ?? '',
                icon: secondaryIcon ?? LucideIcons.pencil,
                color: secondaryColor,
              ),
        child: child,
      ),
    );
  }
}

class _AarastV3SwipeCue extends StatelessWidget {
  const _AarastV3SwipeCue({
    required this.alignment,
    required this.label,
    required this.icon,
    required this.color,
  });

  final AlignmentGeometry alignment;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: Colors.white),
              const SizedBox(width: AarastV3Space.x2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One compact, reusable list row for people, notifications and utilities.
///
/// The row owns hierarchy and density. Feature code supplies truthful content
/// and at most one contextual action; secondary mutations remain in overflow.
class AarastV3ListRow extends StatelessWidget {
  const AarastV3ListRow({
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.meta,
    this.details,
    this.footer,
    this.leading,
    this.status,
    this.action,
    this.onTap,
    this.accent = AarastV3Color.primary,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final String? meta;
  final Widget? details;
  final Widget? footer;
  final Widget? leading;
  final Widget? status;
  final Widget? action;
  final VoidCallback? onTap;
  final Color accent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AarastV3Density.rowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x3,
          vertical: AarastV3Space.x3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AarastV3Radius.pill),
              ),
            ),
            if (leading != null) ...[
              const SizedBox(width: AarastV3Space.x3),
              leading!,
            ],
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final effectiveTitle =
                          titleWidget ??
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AarastV3Color.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          );
                      final stacksStatus =
                          status != null && constraints.maxWidth < 190;

                      if (stacksStatus) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            effectiveTitle,
                            const SizedBox(height: AarastV3Space.x1),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: status!,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: effectiveTitle),
                          if (status != null) ...[
                            const SizedBox(width: AarastV3Space.x2),
                            status!,
                          ],
                        ],
                      );
                    },
                  ),
                  if (details != null) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    details!,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AarastV3Color.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    footer!,
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AarastV3Space.x2),
              action!,
            ] else if (onTap != null) ...[
              const SizedBox(width: AarastV3Space.x2),
              const Icon(
                LucideIcons.chevronLeft,
                color: AarastV3Color.textFaint,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class AarastV3MetricGridData {
  const AarastV3MetricGridData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
    this.accent = AarastV3Color.primary,
    this.heroTag,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;
  final Color accent;
  final Object? heroTag;
}

/// A fixed-size shared element for transitions from a dashboard metric to its
/// destination. Only the icon flies: cards with different content and heights
/// must never be interpolated inside the small metric-cell constraints.
class AarastV3HeroIcon extends StatelessWidget {
  const AarastV3HeroIcon({
    required this.icon,
    this.heroTag,
    this.color = AarastV3Color.primary,
    this.size = 18,
    super.key,
  });

  final IconData icon;
  final Object? heroTag;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final plainIcon = Icon(icon, size: size, color: color);
    final tag = heroTag;
    if (tag == null) return plainIcon;

    final iconWidget = SizedBox.square(
      dimension: size,
      child: Center(child: plainIcon),
    );

    return Hero(
      tag: tag,
      createRectTween: (begin, end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      child: Material(color: Colors.transparent, child: iconWidget),
    );
  }
}

/// A single 2x2 decision surface. Metrics remain individually operable without
/// turning the dashboard into four unrelated cards.
class AarastV3MetricGrid extends StatelessWidget {
  const AarastV3MetricGrid({required this.items, super.key});

  final List<AarastV3MetricGridData> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index += 2) {
      final first = items[index];
      final second = index + 1 < items.length ? items[index + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _AarastV3MetricCell(item: first)),
              if (second != null) ...[
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AarastV3Color.line,
                ),
                Expanded(child: _AarastV3MetricCell(item: second)),
              ],
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          border: Border.all(color: AarastV3Color.line),
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        ),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index != rows.length - 1)
                const Divider(height: 1, color: AarastV3Color.line),
            ],
          ],
        ),
      ),
    );
  }
}

class _AarastV3MetricCell extends StatelessWidget {
  const _AarastV3MetricCell({required this.item});

  final AarastV3MetricGridData item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.label}، ${item.value}، ${item.detail}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AarastV3Density.metricMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AarastV3HeroIcon(
                        heroTag: item.heroTag,
                        icon: item.icon,
                        color: item.accent,
                        size: 17,
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AarastV3Type.label(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      item.value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AarastV3Color.ink,
                        fontFamily: AarastV3Type.displayFamily,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    item.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: item.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AarastV3SignalLine extends StatelessWidget {
  const AarastV3SignalLine({
    required this.title,
    required this.message,
    required this.icon,
    this.color = AarastV3Color.amber,
    this.onTap,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Space.x3,
            vertical: AarastV3Space.x3,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AarastV3Color.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AarastV3Color.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AarastV3Space.x2),
                const Icon(
                  LucideIcons.chevronLeft,
                  color: AarastV3Color.textFaint,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AarastV3IconAction extends StatelessWidget {
  const AarastV3IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: emphasized
            ? AarastV3Color.primary
            : AarastV3Color.paper,
        foregroundColor: emphasized
            ? AarastV3Color.onPrimary
            : AarastV3Color.ink,
        side: const BorderSide(color: AarastV3Color.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class AarastV3ProgressLine extends StatelessWidget {
  const AarastV3ProgressLine({
    this.value,
    this.color = AarastV3Color.primary,
    this.backgroundColor = AarastV3Color.paperQuiet,
    this.height = 5,
    this.semanticsLabel,
    super.key,
  });

  final double? value;
  final Color color;
  final Color backgroundColor;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final normalized = value?.clamp(0.0, 1.0).toDouble();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget line(double? progress) => ClipRRect(
      borderRadius: BorderRadius.circular(AarastV3Radius.pill),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
    final progressLine = normalized == null
        ? line(null)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: normalized),
            duration: reduceMotion ? Duration.zero : AarastV3Motion.standard,
            curve: AarastV3Motion.curve,
            builder: (context, progress, _) => line(progress),
          );
    return Semantics(
      label: semanticsLabel,
      value: normalized == null ? null : '${(normalized * 100).round()}%',
      child: ExcludeSemantics(child: progressLine),
    );
  }
}

/// Aarast's quiet product signature: a real progress line punctuated by
/// milestones. It reads from right to left in Arabic and never invents stages.
class AarastV3PlanPath extends StatelessWidget {
  const AarastV3PlanPath({
    required this.value,
    required this.semanticsLabel,
    this.color = AarastV3Color.primary,
    this.trackColor = AarastV3Color.line,
    this.nodeFillColor = AarastV3Color.paper,
    this.inactiveNodeColor = AarastV3Color.lineStrong,
    this.nodes = 5,
    super.key,
  });

  final double value;
  final String semanticsLabel;
  final Color color;
  final Color trackColor;
  final Color nodeFillColor;
  final Color inactiveNodeColor;
  final int nodes;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textDirection = Directionality.of(context);
    return Semantics(
      label: semanticsLabel,
      value: '${(normalized * 100).round()}%',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: normalized),
          duration: reduceMotion ? Duration.zero : AarastV3Motion.deliberate,
          curve: AarastV3Motion.curve,
          builder: (context, progress, child) => SizedBox(
            height: 12,
            width: double.infinity,
            child: CustomPaint(
              painter: _AarastV3PlanPathPainter(
                progress: progress,
                color: color,
                trackColor: trackColor,
                nodeFillColor: nodeFillColor,
                inactiveNodeColor: inactiveNodeColor,
                nodes: nodes < 2 ? 2 : nodes,
                textDirection: textDirection,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AarastV3PlanPathPainter extends CustomPainter {
  const _AarastV3PlanPathPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.nodeFillColor,
    required this.inactiveNodeColor,
    required this.nodes,
    required this.textDirection,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final Color nodeFillColor;
  final Color inactiveNodeColor;
  final int nodes;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final isRtl = textDirection == TextDirection.rtl;
    final startX = isRtl ? size.width : 0.0;
    final endX = isRtl ? 0.0 : size.width;
    final activeX = isRtl ? size.width * (1 - progress) : size.width * progress;
    final basePaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), basePaint);
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(activeX, centerY),
      activePaint,
    );

    for (var index = 0; index < nodes; index++) {
      final ratio = index / (nodes - 1);
      final x = isRtl ? size.width * (1 - ratio) : size.width * ratio;
      final isActive = ratio <= progress + .001;
      canvas.drawCircle(
        Offset(x, centerY),
        4.2,
        Paint()..color = nodeFillColor,
      );
      canvas.drawCircle(
        Offset(x, centerY),
        isActive ? 3.2 : 2.5,
        Paint()..color = isActive ? color : inactiveNodeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AarastV3PlanPathPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.nodeFillColor != nodeFillColor ||
        oldDelegate.inactiveNodeColor != inactiveNodeColor ||
        oldDelegate.nodes != nodes ||
        oldDelegate.textDirection != textDirection;
  }
}
