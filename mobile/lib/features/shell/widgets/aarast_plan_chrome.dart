import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3_foundations.dart';
import '../../../core/theme/aarast_design_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_bottom_sheet.dart';
import '../../../core/widgets/aarast_pressable.dart';

class AarastQuickAction {
  const AarastQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.id,
    this.description,
    this.recommended = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? id;
  final String? description;
  final bool recommended;

  AarastQuickAction copyWith({VoidCallback? onTap, bool? recommended}) {
    return AarastQuickAction(
      id: id,
      icon: icon,
      label: label,
      description: description,
      recommended: recommended ?? this.recommended,
      onTap: onTap ?? this.onTap,
    );
  }
}

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

Future<void> showAarastQuickActionSheet(
  BuildContext context, {
  required List<AarastQuickAction> actions,
}) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    enableDrag: false,
    backgroundColor: AppTheme.surfaceRaised,
    barrierColor: AppTheme.textPrimary.withValues(alpha: 0.46),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusOverlay),
      ),
    ),
    builder: (sheetContext) {
      return AarastQuickActionSheet(
        actions: actions,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class AarastQuickActionSheet extends StatelessWidget {
  const AarastQuickActionSheet({
    required this.actions,
    required this.onClose,
    super.key,
  });

  final List<AarastQuickAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 420;
    return Material(
      color: AppTheme.surfaceRaised,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, compactHeight ? 12 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compactHeight)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compactHeight ? 'إضافة' : 'ماذا تريد أن تنجز؟',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (!compactHeight) ...[
                          const SizedBox(height: 2),
                          Text(
                            'مدخل واحد، والخطوة الأنسب تظهر أولاً.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'إغلاق',
                    style: IconButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      backgroundColor: AppTheme.surfaceMuted,
                      side: const BorderSide(color: AppTheme.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusControl,
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              SizedBox(
                height: compactHeight ? AppTheme.space4 : AppTheme.space8,
              ),
              for (var index = 0; index < actions.length; index++) ...[
                _QuickActionRow(action: actions[index]),
                if (index != actions.length - 1)
                  const Divider(height: 1, color: AppTheme.borderStrong),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

  static String planDestinationLabel(int index) {
    return switch (index) {
      1 => 'المال',
      2 => 'المهام',
      3 => 'الضيوف',
      4 => 'المزودين',
      _ => 'الرئيسية',
    };
  }

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
                    child: _PlanNavigationItem(
                      item: items[index],
                      active: activeIndex == index,
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

class AarastPlanContextBar extends StatelessWidget {
  const AarastPlanContextBar({
    required this.planName,
    required this.destination,
    this.stageLabel,
    super.key,
  });

  final String planName;
  final String destination;
  final String? stageLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedPlanName = planName.trim();
    final effectivePlanName = trimmedPlanName.isEmpty
        ? 'خطة الزفاف'
        : trimmedPlanName;
    final effectiveDestination = stageLabel?.trim().isNotEmpty == true
        ? '$destination · ${stageLabel!.trim()}'
        : destination;
    final semanticLabel =
        'الخطة الحالية: $effectivePlanName، القسم الحالي: $effectiveDestination';

    return Material(
      color: AppTheme.canvas,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          header: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: const BoxDecoration(color: AarastV3Color.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        effectiveDestination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AarastV3Color.primary,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        effectivePlanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

class AarastQuickActionButton extends StatelessWidget {
  const AarastQuickActionButton({
    required this.onPressed,
    this.onLongPress,
    this.icon = LucideIcons.plus,
    this.label = 'إضافة',
    this.expanded = true,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final IconData icon;
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onPressed,
      onLongPress: onLongPress,
      longPressSemanticLabel: onLongPress == null
          ? null
          : 'فتح آخر إجراء إضافة مستخدم',
      semanticLabel: label,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        key: const ValueKey('aarast-quick-action'),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minWidth: expanded ? 0 : 52),
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
        decoration: BoxDecoration(
          color: AarastV3Color.primary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: expanded
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.action});

  final AarastQuickAction action;

  @override
  Widget build(BuildContext context) {
    final hasDescription = action.description?.trim().isNotEmpty == true;
    return AarastPressable(
      onTap: action.onTap,
      semanticLabel: action.label,
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: hasDescription ? 60 : 48),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: hasDescription ? 8 : 4),
          child: Row(
            children: [
              Container(
                width: hasDescription ? 40 : 36,
                height: hasDescription ? 40 : 36,
                decoration: BoxDecoration(
                  color: AppTheme.brandMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                ),
                child: Icon(action.icon, color: AppTheme.brand, size: 20),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            action.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (action.recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AarastV3Color.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              'الأنسب الآن',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AarastV3Color.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronLeft,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
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
  });

  final AarastNavigationItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AarastV3Color.primary : AarastV3Color.textFaint;

    return AarastPressable(
      onTap: onTap,
      semanticLabel: item.badge > 0
          ? '${item.label}، إشعارات غير مقروءة: ${item.badge}'
          : item.label,
      selected: active,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        key: ValueKey('${item.label}-$active'),
        duration: AppTheme.motionFast,
        curve: AppTheme.motionCurve,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AarastV3Color.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, color: foreground, size: 20),
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
                        color: AarastSemanticTokens.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        item.badge > 9 ? '9+' : '${item.badge}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontSize: 10,
                height: 1,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
