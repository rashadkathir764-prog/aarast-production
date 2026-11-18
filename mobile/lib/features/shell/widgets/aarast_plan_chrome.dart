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

    // The bar speaks the app's own language: the shape of its sheets (white,
    // 24 corners on top, resting on the bottom edge) and the selected fill of
    // its switchers (the plan's colour, white words). Every tab is the same
    // width with its icon over its name; the chosen one is filled, so the row
    // never jumps when a tab changes.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AarastV3Radius.sheet),
          ),
          boxShadow: [
            BoxShadow(
              color: AarastV3Color.ink.withValues(alpha: 0.06),
              blurRadius: AarastV3Space.x6,
              offset: const Offset(0, -AarastV3Space.x1),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x2,
              AarastV3Space.x2,
              AarastV3Space.x2,
              AarastV3Space.x1,
            ),
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
                        onTap: () => onSelected(index),
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

/// A tab's height: an icon over its name, a full touch target (D74).
const _navigationHeight = 56.0;

/// What the bar grows by at the largest text size the app allows.
const _navigationGrowth = 18.0;

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

  /// The plan's colour: the chosen tab's fill.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? AarastV3Color.onPrimary
        : AarastV3Color.textMuted;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.half),
      child: AarastPressable(
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
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
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
                      color: foreground,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
