import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_pressable.dart';
import 'plan_quick_add.dart';

/// The «+» on one tab of one plan, the same in both shells and on the home
/// of a plan kept on the phone. The shell gives what only it knows: whether
/// the money may be managed, the plan's signals, how it opens its guest
/// sheet and its providers, and what to refresh when the plan changed.
class PlanQuickAddFlow {
  const PlanQuickAddFlow({
    required this.planId,
    required this.tabIndex,
    required this.canManageMoney,
    required this.onAddGuest,
    required this.onFindProviders,
    required this.onChanged,
    this.canManageBudget = true,
    this.offerAgreementActions = false,
    this.refreshOnReturn = false,
    this.signals,
  });

  final String planId;
  final int tabIndex;
  final bool canManageMoney;
  final bool canManageBudget;
  final VoidCallback onAddGuest;
  final VoidCallback onFindProviders;
  final Future<void> Function() onChanged;
  final bool offerAgreementActions;
  final bool refreshOnReturn;
  final PlanQuickAddSignals? signals;

  List<PlanQuickAction> get actions => planQuickAddActions(
    planId: planId,
    tabIndex: tabIndex,
    canManageMoney: canManageMoney,
    canManageBudget: canManageBudget,
    offerAgreementActions: offerAgreementActions,
    signals: signals,
  );

  /// The tap: a task or a guest straight away on their tabs, the sheet
  /// elsewhere.
  Future<void> open(BuildContext context) async {
    final direct = planQuickAddDirectKind(tabIndex);
    if (direct != null) return _run(context, direct);
    final kind = await showPlanQuickAddSheet(context, actions: actions);
    if (kind != null && context.mounted) await _run(context, kind);
  }

  /// The long press: the last choice used on the plan again, while this tab
  /// still offers it (a choice the money rights no longer allow is not
  /// repeated); otherwise the same as a tap.
  Future<void> repeatLast(BuildContext context) async {
    final last = lastPlanQuickAdd(planId);
    if (last != null && actions.any((action) => action.kind == last)) {
      return _run(context, last);
    }
    return open(context);
  }

  Future<void> _run(BuildContext context, PlanQuickAddKind kind) {
    return openPlanQuickAdd(
      context,
      planId: planId,
      kind: kind,
      onAddGuest: onAddGuest,
      onFindProviders: onFindProviders,
      onChanged: onChanged,
      refreshOnReturn: refreshOnReturn,
    );
  }
}

/// The «+» sheet (D33): one row per choice in its section's colour, the
/// best one first and marked «الأنسب الآن». Returns the choice picked, or
/// null when the sheet is closed.
Future<PlanQuickAddKind?> showPlanQuickAddSheet(
  BuildContext context, {
  required List<PlanQuickAction> actions,
}) {
  return showJourneySheet<PlanQuickAddKind>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => JourneySheetBody(
      title: 'ايش تضيف؟',
      subtitle: 'الأنسب لخطتك الحين أول وحدة.',
      children: [
        JourneyList(
          children: [
            for (final action in actions)
              JourneyListRow(
                key: ValueKey('plan-quick-add-${action.kind.name}'),
                icon: action.kind.icon,
                color: action.kind.section.colorOf(context),
                soft: action.kind.section.softOf(context),
                title: action.kind.labelFor(sheetContext.journeyProfile),
                subtitle: action.kind.descriptionFor(
                  sheetContext.journeyProfile,
                ),
                trailing: action.recommended
                    ? JourneyTag(
                        label: 'الأنسب الآن',
                        color: action.kind.section.colorOf(context),
                        soft: action.kind.section.softOf(context),
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(action.kind),
              ),
          ],
        ),
      ],
    ),
  );
}

/// The floating «+» over a plan tab, in the tab's colour. [expanded] shows
/// its word beside the sign; the shell gives it only where nothing lies
/// under the button (D112, Q-23).
class PlanQuickAddButton extends StatelessWidget {
  const PlanQuickAddButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.onLongPress,
    this.expanded = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  /// Repeats the last choice used on the plan.
  final VoidCallback? onLongPress;
  final bool expanded;

  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onPressed,
      onLongPress: onLongPress,
      longPressSemanticLabel: onLongPress == null ? null : 'كرر آخر إضافة',
      semanticLabel: label,
      borderRadius: BorderRadius.circular(_radius),
      child: AnimatedContainer(
        key: const ValueKey('aarast-quick-action'),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minWidth: expanded ? 0 : 52),
        height: 52,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? AarastV3Space.x4 : 0,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AarastV3Color.onPrimary, size: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AarastV3Space.x2,
                      ),
                      child: Text(
                        label,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                          color: AarastV3Color.onPrimary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
