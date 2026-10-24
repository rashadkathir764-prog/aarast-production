import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_journey.dart';
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
    required this.items,
    required this.activeIndex,
    required this.onSelected,
    super.key,
  });

  const AarastPlanNavigationBar.plan({
    required this.activeIndex,
    required this.onSelected,
    super.key,
  }) : items = _planItems;

  static const _planItems = [
    AarastNavigationItem(icon: LucideIcons.home, label: 'الرئيسية'),
    AarastNavigationItem(icon: LucideIcons.wallet, label: 'المال'),
    AarastNavigationItem(icon: LucideIcons.listChecks, label: 'المهام'),
    AarastNavigationItem(icon: LucideIcons.users, label: 'الضيوف'),
    AarastNavigationItem(icon: LucideIcons.store, label: 'المزودين'),
  ];

  final List<AarastNavigationItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScale - 1).clamp(0.0, 1.0) * 18).toDouble();
    final navigationHeight = 64 + extraHeight;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: navigationHeight,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AarastV3Color.paper,
              borderRadius: BorderRadius.circular(22),
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
                      color:
                          identical(items, _planItems) &&
                              index < JourneySection.values.length
                          ? JourneySection.values[index].color
                          : AarastV3Color.primary,
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
    this.color = AarastV3Color.primary,
  });

  final AarastNavigationItem item;
  final bool active;
  final VoidCallback onTap;

  /// The tab's section colour: the active tab is a pill in it (b02).
  final Color color;

  @override
  Widget build(BuildContext context) {
    // b02: the active tab is a pill with a 19 icon and its 14 bold name;
    // the others a faint 21 icon over an 11.5 regular muted name.
    final foreground = active
        ? AarastV3Color.onPrimary
        : AarastV3Color.textMuted;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          item.icon,
          color: active ? AarastV3Color.onPrimary : AarastV3Color.textFaint,
          size: active ? 19 : 21,
        ),
        if (item.badge > 0)
          PositionedDirectional(
            start: -7,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 3),
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
          ? '${item.label}، إشعارات غير مقروءة: ${item.badge}'
          : item.label,
      selected: active,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        key: ValueKey('${item.label}-$active'),
        duration: AppTheme.motionFast,
        curve: AppTheme.motionCurve,
        // Fills the bar, which grows with the person's text size.
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: active
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Flexible(child: label),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [icon, const SizedBox(height: 3), label],
              ),
      ),
    );
  }
}
