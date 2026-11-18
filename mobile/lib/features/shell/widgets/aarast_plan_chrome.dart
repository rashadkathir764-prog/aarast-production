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
    final extraHeight = ((textScale - 1).clamp(0.0, 1.0) * _navigationGrowth)
        .toDouble();

    // The bar sits on the screen's bottom edge, as the phone's own bars do:
    // white to the edge, one hairline above it, and the system's gesture
    // area inside its white. Every tab is the same width and the same shape,
    // its icon over its name; the chosen one is told by the plan's colour and
    // a soft pill behind its icon, so the row never jumps when a tab changes.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AarastV3Color.paper,
          border: Border(top: BorderSide(color: AarastV3Color.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _navigationHeight + extraHeight,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _PlanNavigationItem(
                      item: items[index],
                      active: activeIndex == index,
                      color: planTabs
                          ? JourneySection.values[index].colorOf(context)
                          : context.accent.primary,
                      soft: planTabs
                          ? JourneySection.values[index].softOf(context)
                          : context.accent.primarySoft,
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

/// The bar's own height above the system's gesture area: a 32 pill, a 4
/// step and a 12 name between 8 above and 8 below, every tab a full touch
/// target (D74).
const _navigationHeight = 64.0;

/// What the bar grows by at the largest text size the app allows.
const _navigationGrowth = 18.0;

/// The soft pill behind the chosen tab's icon.
const _indicatorWidth = 56.0;
const _indicatorHeight = 32.0;

class _PlanNavigationItem extends StatelessWidget {
  const _PlanNavigationItem({
    required this.item,
    required this.active,
    required this.onTap,
    required this.color,
    required this.soft,
  });

  final AarastNavigationItem item;
  final bool active;
  final VoidCallback onTap;

  /// The plan's colour: the chosen tab's icon and name.
  final Color color;

  /// The plan's soft colour: the pill behind the chosen tab's icon.
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? color : AarastV3Color.textMuted;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(item.icon, color: foreground, size: AarastV3Icon.md),
        if (item.badge > 0)
          PositionedDirectional(
            start: -AarastV3Space.x2,
            top: -AarastV3Space.x1,
            child: Container(
              constraints: const BoxConstraints(minWidth: AarastV3Space.x4),
              height: AarastV3Space.x4,
              padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AarastV3Color.danger,
                borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                border: Border.all(color: AarastV3Color.paper),
              ),
              child: Text(
                item.badge > 9 ? '9+' : '${item.badge}',
                // «9+» reads as written, not mirrored into «+9».
                textDirection: TextDirection.ltr,
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

    return AarastPressable(
      onTap: onTap,
      semanticLabel: item.badge > 0
          ? '${item.label}، تنبيهات غير مقروءة: ${item.badge}'
          : item.label,
      selected: active,
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              key: ValueKey('${item.label}-$active'),
              duration: AppTheme.motionFast,
              curve: AppTheme.motionCurve,
              width: _indicatorWidth,
              height: _indicatorHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? soft : soft.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(AarastV3Radius.pill),
              ),
              child: icon,
            ),
            const SizedBox(height: AarastV3Space.x1),
            // A tab name shrinks a little before it is ever cut.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: JourneyType.of(
                    JourneyType.label,
                    weight: active ? JourneyType.bold : FontWeight.w500,
                    color: active ? color : AarastV3Color.textMuted,
                    height: 1.2,
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
