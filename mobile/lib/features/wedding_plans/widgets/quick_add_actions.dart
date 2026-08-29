import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../shell/shell_api.dart' show AarastQuickAction;
import '../models/dashboard_summary.dart';
import '../models/wedding_plan_stage.dart';

enum QuickAddContext { dashboard, money, tasks, guests, providers }

class QuickAddSignals {
  const QuickAddSignals({
    this.overdueTasks = 0,
    this.pendingGuests = 0,
    this.incompleteGuests = 0,
    this.duePaymentSchedules = 0,
    this.providerCount = 0,
    this.stage,
  });

  factory QuickAddSignals.fromDashboard(DashboardSummary summary) {
    return QuickAddSignals(
      overdueTasks: summary.overdueTasks,
      pendingGuests: summary.pendingGuests,
      incompleteGuests: summary.incompleteGuestsCount,
      duePaymentSchedules: summary.duePaymentSchedulesCount ?? 0,
      providerCount: summary.providerCount,
      stage: resolveWeddingPlanStage(summary.weddingDate).stage,
    );
  }

  final int overdueTasks;
  final int pendingGuests;
  final int incompleteGuests;
  final int duePaymentSchedules;
  final int providerCount;
  final WeddingPlanStage? stage;
}

final Map<String, String> _lastQuickActionByPlan = <String, String>{};

String? lastCanonicalQuickAddActionId(String planId) {
  return _lastQuickActionByPlan[planId];
}

void rememberCanonicalQuickAddAction(String planId, String actionId) {
  _lastQuickActionByPlan[planId] = actionId;
}

/// Returns the last real creation action used for this plan during the current
/// app session. The result remains permission- and context-safe because it is
/// resolved from the actions currently available to the caller.
AarastQuickAction? lastCanonicalQuickAddAction(
  String planId,
  List<AarastQuickAction> availableActions,
) {
  final lastId = _lastQuickActionByPlan[planId];
  if (lastId == null) return null;
  for (final action in availableActions) {
    if (action.id == lastId) return action;
  }
  return null;
}

IconData planQuickAddIconForTab(int tabIndex) {
  return switch (tabIndex) {
    1 => LucideIcons.wallet,
    2 => LucideIcons.listPlus,
    3 => LucideIcons.userPlus,
    4 => LucideIcons.store,
    _ => LucideIcons.plus,
  };
}

String planQuickAddLabelForTab(int tabIndex) {
  return switch (tabIndex) {
    1 => 'إضافة تكلفة',
    2 => 'إضافة مهمة',
    3 => 'إضافة ضيف',
    _ => 'إضافة',
  };
}

/// Keeps quick-add visibility identical across the production home shell and
/// the plan-scoped shell. Money shows it only at the tab root; providers never
/// shows it because its primary action lives inside the marketplace flow.
bool shouldShowPlanQuickAdd({
  required int tabIndex,
  bool isRootDestination = true,
  bool canManageMoney = false,
}) {
  const moneyTabIndex = 1;
  const providersTabIndex = 4;
  return tabIndex != providersTabIndex &&
      (tabIndex != moneyTabIndex || canManageMoney) &&
      (tabIndex != moneyTabIndex || isRootDestination);
}

/// Canonical quick-add actions for any active wedding plan.
///
/// Used by:
/// - [MainShell] floating "+" button (the production bottom-nav shell).
/// - [LocalGuestDashboardScreen] floating "+" button (guest draft plan).
///
/// Keep this list aligned with the navigation blueprint so every duplicate
/// shortcut opens the same canonical flow with the same Arabic label.
List<AarastQuickAction> buildCanonicalQuickAddActions(
  BuildContext context, {
  required String planId,
  required bool canManageMoney,
  QuickAddContext contextOrder = QuickAddContext.dashboard,
  bool refreshDashboardOnMoney = false,
  VoidCallback? onRequestQuote,
  VoidCallback? onRecordPayment,
  VoidCallback? onAddPaymentSchedule,
  QuickAddSignals? signals,
  required Future<void> Function(String route, {bool refreshDashboard})
  openRoute,
}) {
  final cost = AarastQuickAction(
    id: 'cost',
    icon: LucideIcons.receipt,
    label: 'إضافة تكلفة',
    description: 'سجّل الاتفاق وقيمته، ثم أضف دفعاته عند الحاجة.',
    onTap: () => openRoute(
      AppRouter.moneyCostCreate(planId),
      refreshDashboard: refreshDashboardOnMoney,
    ),
  );
  final payment = AarastQuickAction(
    id: 'payment',
    icon: LucideIcons.badgeDollarSign,
    label: 'تسجيل دفعة',
    description: 'اختر التكلفة ثم سجّل ما دُفع فعليًا.',
    onTap: onRecordPayment ?? () {},
  );
  final schedule = AarastQuickAction(
    id: 'schedule',
    icon: LucideIcons.calendarPlus,
    label: 'إضافة موعد دفع',
    description: 'اربط تذكير الدفع بتكلفة قائمة، دون حجز المبلغ.',
    onTap: onAddPaymentSchedule ?? () {},
  );
  final category = AarastQuickAction(
    id: 'category',
    icon: LucideIcons.folderPlus,
    label: 'إضافة تصنيف',
    description: 'قسّم ميزانيتك إلى بنود واضحة يسهل تتبعها.',
    onTap: () => openRoute(
      AppRouter.moneyCategoryCreate(planId),
      refreshDashboard: refreshDashboardOnMoney,
    ),
  );
  final task = AarastQuickAction(
    id: 'task',
    icon: LucideIcons.listPlus,
    label: 'إضافة مهمة',
    description: 'حوّل الخطوة التالية إلى مهمة بموعد ومسؤول.',
    onTap: () => openRoute(AppRouter.createTask(planId)),
  );
  final guest = AarastQuickAction(
    id: 'guest',
    icon: LucideIcons.userPlus,
    label: 'إضافة ضيف',
    description: 'أضف الاسم أولاً وأكمل التفاصيل لاحقًا.',
    onTap: () => openRoute(AppRouter.guestListAdd(planId)),
  );
  final quote = AarastQuickAction(
    id: 'quote',
    icon: LucideIcons.filePlus2,
    label: 'طلب عرض سعر',
    description: 'استكشف مزوّدًا حقيقيًا وابدأ طلب عرض واضحًا.',
    onTap: onRequestQuote ?? () => openRoute(AppRouter.planProviders(planId)),
  );

  final financialActions = canManageMoney
      ? <AarastQuickAction>[
          cost,
          if (onRecordPayment != null) payment,
          if (onAddPaymentSchedule != null) schedule,
          category,
        ]
      : const <AarastQuickAction>[];

  final ordered = switch (contextOrder) {
    QuickAddContext.money => financialActions,
    QuickAddContext.tasks => [task, if (canManageMoney) cost, guest, quote],
    QuickAddContext.guests => [guest, task, if (canManageMoney) cost, quote],
    QuickAddContext.providers => [quote, if (canManageMoney) cost, task, guest],
    QuickAddContext.dashboard => [if (canManageMoney) cost, task, guest, quote],
  };

  if (ordered.isEmpty) return ordered;
  final lastAction = _lastQuickActionByPlan[planId];
  final ranked =
      ordered.indexed.map((entry) {
        final (index, action) = entry;
        var score = 100 - (index * 10);
        if (signals != null) {
          score += switch (action.id) {
            'cost' when signals.duePaymentSchedules > 0 => 110,
            'task' when signals.overdueTasks > 0 => 100,
            'guest' when signals.incompleteGuests > 0 => 90,
            'guest' when signals.pendingGuests > 0 => 75,
            'quote' when signals.providerCount == 0 => 65,
            _ => 0,
          };
          score += _stageActionBoost(signals.stage, action.id);
        }
        if (action.id == lastAction) score += 45;
        return (index: index, action: action, score: score);
      }).toList()..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.index.compareTo(b.index);
      });

  return [
    for (var index = 0; index < ranked.length; index++)
      ranked[index].action.copyWith(
        recommended: index == 0,
        onTap: () {
          final id = ranked[index].action.id;
          if (id != null) rememberCanonicalQuickAddAction(planId, id);
          ranked[index].action.onTap();
        },
      ),
  ];
}

int _stageActionBoost(WeddingPlanStage? stage, String? actionId) {
  return switch ((stage, actionId)) {
    (WeddingPlanStage.foundation, 'task') => 25,
    (WeddingPlanStage.foundation, 'guest') => 15,
    (WeddingPlanStage.planning, 'quote') => 35,
    (WeddingPlanStage.planning, 'task') => 10,
    (WeddingPlanStage.finalMonth, 'guest') => 40,
    (WeddingPlanStage.finalMonth, 'quote') => 20,
    (WeddingPlanStage.finalMonth, 'cost') => 10,
    (WeddingPlanStage.finalWeek, 'task') => 70,
    (WeddingPlanStage.finalWeek, 'guest') => 20,
    (WeddingPlanStage.finalWeek, 'cost') => 15,
    (WeddingPlanStage.weddingDay, 'task') => 80,
    (WeddingPlanStage.weddingDay, 'quote') => -100,
    (WeddingPlanStage.wrapUp, 'cost') => 25,
    (WeddingPlanStage.wrapUp, 'task') => 10,
    _ => 0,
  };
}
