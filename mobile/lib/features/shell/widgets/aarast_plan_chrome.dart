import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_journey.dart';
import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/experience_v3/aarast_v3_foundations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_pressable.dart';

class AarastNavigationItem {
  const AarastNavigationItem({
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final int badge;
}

class AarastPlanNavigationBar extends StatelessWidget {
  const AarastPlanNavigationBar({
    required List<AarastNavigationItem> this.items,
    required this.activeIndex,
    required this.onSelected,
    super.key,
  });

  /// The plan's five tabs, named and coloured in the plan's profile.
  const AarastPlanNavigationBar.plan({
    required this.activeIndex,
    required this.onSelected,
    super.key,
  }) : items = null;

  /// Other bars' tabs; null draws the plan's five [JourneySection]s.
  final List<AarastNavigationItem>? items;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final planTabs = this.items == null;
    final items =
        this.items ??
        [
          for (final section in JourneySection.values)
            AarastNavigationItem(
              icon: section.icon,
              label: section.labelOf(context),
            ),
        ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScale - 1).clamp(0.0, 1.0) * 18).toDouble();
    // 48 inside the 5 of padding: every tab is a full touch target (D74).
    final navigationHeight = 58 + extraHeight;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            0,
            AarastV3Space.x4,
            AarastV3Space.x2,
          ),
          child: Container(
            height: navigationHeight,
            padding: const EdgeInsets.all(AarastV3Space.x1),
            decoration: BoxDecoration(
              color: AarastV3Color.paper,
              borderRadius: BorderRadius.circular(AarastV3Radius.card),
              border: Border.all(color: AarastV3Color.line),
            ),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    // The active tab is wide enough for its name beside
                    // its icon.
                    flex: activeIndex == index ? 3 : 2,
                    child: _PlanNavigationItem(
                      item: items[index],
                      active: activeIndex == index,
                      color: planTabs
                          ? JourneySection.values[index].colorOf(context)
                          : context.accent.primary,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanNavigationItem extends StatelessWidget {
  const _PlanNavigationItem({
    required this.item,
    required this.active,
    required this.onTap,
    required this.color,
  });

  final AarastNavigationItem item;
  final bool active;
  final VoidCallback onTap;

  /// The tab's section colour: the active tab is a pill in it (b02).
  final Color color;

  @override
  Widget build(BuildContext context) {
    // The active tab is a pill with an 18 icon and its bold name; the
    // others a faint 20 icon over a regular muted name.
    final foreground = active
        ? AarastV3Color.onPrimary
        : AarastV3Color.textMuted;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          item.icon,
          color: active ? AarastV3Color.onPrimary : AarastV3Color.textFaint,
          size: active ? 18 : 20,
        ),
        if (item.badge > 0)
          PositionedDirectional(
            start: -7,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AarastV3Color.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                item.badge > 9 ? '9+' : '${item.badge}',
                textScaler: TextScaler.noScaling,
                style: JourneyType.of(
                  JourneyType.badge,
                  weight: JourneyType.bold,
                  color: AarastV3Color.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
    // A tab name shrinks a little before it is ever cut.
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        item.label,
        maxLines: 1,
        style: JourneyType.of(
          active ? JourneyType.bodySmall : JourneyType.tabLabel,
          weight: active ? JourneyType.bold : FontWeight.w400,
          color: foreground,
          height: 1.1,
        ),
      ),
    );

    return AarastPressable(
      onTap: onTap,
      semanticLabel: item.badge > 0
          ? '${item.label}، تنبيهات غير مقروءة: ${item.badge}'
          : item.label,
      selected: active,
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: AnimatedContainer(
        key: ValueKey('${item.label}-$active'),
        duration: AppTheme.motionFast,
        curve: AppTheme.motionCurve,
        // Fills the bar, which grows with the person's text size.
        height: double.infinity,
        padding: const EdgeInsets.all(AarastV3Space.x1),
        decoration: BoxDecoration(
          color: active ? color : null,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        ),
        child: active
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: AarastV3Space.x1),
                  Flexible(child: label),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: AarastV3Space.half),
                  label,
                ],
              ),
      ),
    );
  }
}
