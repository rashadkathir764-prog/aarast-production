import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_journey.dart';
import '../../../core/routing/app_router.dart';
import '../../finance/finance_api.dart'
    show MoneyCostActionIntent, openMoneyCostAction;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummary, WeddingPlanStage, resolveWeddingPlanStage;

// The plan's floating «+» (D33): which tabs show it, what it is called on
// each, what its sheet offers and in which order, and where each choice
// goes. Kept by the owner's explicit instruction; every choice opens a
// screen or sheet that exists today.

/// The plan's tabs as both shells number them; 0 is the home.
const _moneyTab = 1;
const _tasksTab = 2;
const _guestsTab = 3;
const _providersTab = 4;

/// One thing the «+» can add. Its section gives the row its colour.
enum PlanQuickAddKind {
  cost(
    'إضافة اتفاق',
    'سجّل اللي اتفقت عليه وقيمته، والدفعات بعدين.',
    LucideIcons.receipt,
    JourneySection.money,
  ),
  payment(
    'تسجيل دفعة',
    'اختر الاتفاق وسجّل اللي دفعته فعلًا.',
    LucideIcons.badgeDollarSign,
    JourneySection.money,
  ),
  schedule(
    'إضافة موعد دفع',
    'تذكير بدفعة جاية على اتفاق، والفلوس ما تنحجز.',
    LucideIcons.calendarPlus,
    JourneySection.money,
  ),
  category(
    'إضافة بند',
    'قسّم ميزانيتك لبنود واضحة تتابعها.',
    LucideIcons.folderPlus,
    JourneySection.money,
  ),
  task(
    'إضافة مهمة',
    'حوّل الخطوة الجاية لمهمة بموعد ولمين.',
    LucideIcons.listPlus,
    JourneySection.tasks,
  ),
  guest(
    'إضافة ضيف',
    'الاسم أول، والتفاصيل بعدين.',
    LucideIcons.userPlus,
    JourneySection.guests,
  ),
  quote(
    'طلب عرض سعر',
    'دوّر على مزود واطلب منه عرض واضح.',
    LucideIcons.filePlus2,
    JourneySection.providers,
  );

  const PlanQuickAddKind(this.label, this.description, this.icon, this.section);

  final String label;
  final String description;
  final IconData icon;
  final JourneySection section;

  /// Adds to the plan's money, so it needs the right to manage money.
  bool get isMoney => section == JourneySection.money;
}

/// A row of the «+» sheet; the first one is marked «الأنسب الآن».
@immutable
class PlanQuickAction {
  const PlanQuickAction(this.kind, {this.recommended = false});

  final PlanQuickAddKind kind;
  final bool recommended;
}

/// What the plan needs now, from its home summary, to rank the choices.
class PlanQuickAddSignals {
  const PlanQuickAddSignals({
    this.overdueTasks = 0,
    this.pendingGuests = 0,
    this.incompleteGuests = 0,
    this.duePaymentSchedules = 0,
    this.providerCount = 0,
    this.stage,
  });

  factory PlanQuickAddSignals.fromDashboard(DashboardSummary summary) {
    return PlanQuickAddSignals(
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

final Map<String, PlanQuickAddKind> _lastByPlan = <String, PlanQuickAddKind>{};

/// The last choice used on this plan in this app session; a long press on
/// the «+» repeats it.
PlanQuickAddKind? lastPlanQuickAdd(String planId) => _lastByPlan[planId];

void rememberPlanQuickAdd(String planId, PlanQuickAddKind kind) {
  _lastByPlan[planId] = kind;
}

/// The same visibility in both shells. Money shows it only at the tab root
/// and only to whoever manages the money; the providers tab never shows it
/// because its own search is the way to a quote. The guests hide it while
/// an account plan has no connection, since a new guest is sent at once
/// (w29).
bool shouldShowPlanQuickAdd({
  required int tabIndex,
  bool isRootDestination = true,
  bool canManageMoney = false,
  bool guestsWaitForConnection = false,
}) {
  return tabIndex != _providersTab &&
      (tabIndex != _guestsTab || !guestsWaitForConnection) &&
      (tabIndex != _moneyTab || canManageMoney) &&
      (tabIndex != _moneyTab || isRootDestination);
}

IconData planQuickAddIconForTab(int tabIndex) {
  return switch (tabIndex) {
    _moneyTab => LucideIcons.wallet,
    _tasksTab => LucideIcons.listPlus,
    _guestsTab => LucideIcons.userPlus,
    _ => LucideIcons.plus,
  };
}

String planQuickAddLabelForTab(int tabIndex) {
  return switch (tabIndex) {
    _moneyTab => PlanQuickAddKind.cost.label,
    _tasksTab => PlanQuickAddKind.task.label,
    _guestsTab => PlanQuickAddKind.guest.label,
    _ => 'إضافة',
  };
}

/// On the tasks and the guests the «+» adds a task or a guest straight away
/// (d01, e01); elsewhere it opens the sheet.
PlanQuickAddKind? planQuickAddDirectKind(int tabIndex) {
  return switch (tabIndex) {
    _tasksTab => PlanQuickAddKind.task,
    _guestsTab => PlanQuickAddKind.guest,
    _ => null,
  };
}

/// The «+» sheet on a tab, best first. On the tasks and the guests the «+»
/// adds a task or a guest straight away, so their order only matters for
/// the long press. Money choices need [canManageMoney]; «تسجيل دفعة» and
/// «إضافة موعد دفع» are offered on the money tab when [offerAgreementActions].
/// The plan's state and stage move the most useful choice up, and the last
/// one used comes next.
List<PlanQuickAction> planQuickAddActions({
  required String planId,
  required int tabIndex,
  required bool canManageMoney,
  bool offerAgreementActions = false,
  PlanQuickAddSignals? signals,
}) {
  const cost = PlanQuickAddKind.cost;
  const task = PlanQuickAddKind.task;
  const guest = PlanQuickAddKind.guest;
  const quote = PlanQuickAddKind.quote;
  final money = canManageMoney
      ? [
          cost,
          if (offerAgreementActions) ...[
            PlanQuickAddKind.payment,
            PlanQuickAddKind.schedule,
          ],
          PlanQuickAddKind.category,
        ]
      : const <PlanQuickAddKind>[];

  final ordered = switch (tabIndex) {
    _moneyTab => money,
    _tasksTab => [task, if (canManageMoney) cost, guest, quote],
    _guestsTab => [guest, task, if (canManageMoney) cost, quote],
    _providersTab => [quote, if (canManageMoney) cost, task, guest],
    _ => [if (canManageMoney) cost, task, guest, quote],
  };
  if (ordered.isEmpty) return const [];

  final last = _lastByPlan[planId];
  final ranked =
      [
        for (final (index, kind) in ordered.indexed)
          (
            index: index,
            kind: kind,
            score:
                100 -
                index * 10 +
                (signals == null ? 0 : _signalBoost(signals, kind)) +
                (kind == last ? 45 : 0),
          ),
      ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.index.compareTo(b.index);
      });

  return [
    for (final (index, entry) in ranked.indexed)
      PlanQuickAction(entry.kind, recommended: index == 0),
  ];
}

int _signalBoost(PlanQuickAddSignals signals, PlanQuickAddKind kind) {
  final state = switch (kind) {
    PlanQuickAddKind.cost when signals.duePaymentSchedules > 0 => 110,
    PlanQuickAddKind.task when signals.overdueTasks > 0 => 100,
    PlanQuickAddKind.guest when signals.incompleteGuests > 0 => 90,
    PlanQuickAddKind.guest when signals.pendingGuests > 0 => 75,
    PlanQuickAddKind.quote when signals.providerCount == 0 => 65,
    _ => 0,
  };
  return state + _stageBoost(signals.stage, kind);
}

int _stageBoost(WeddingPlanStage? stage, PlanQuickAddKind kind) {
  return switch ((stage, kind)) {
    (WeddingPlanStage.foundation, PlanQuickAddKind.task) => 25,
    (WeddingPlanStage.foundation, PlanQuickAddKind.guest) => 15,
    (WeddingPlanStage.planning, PlanQuickAddKind.quote) => 35,
    (WeddingPlanStage.planning, PlanQuickAddKind.task) => 10,
    (WeddingPlanStage.finalMonth, PlanQuickAddKind.guest) => 40,
    (WeddingPlanStage.finalMonth, PlanQuickAddKind.quote) => 20,
    (WeddingPlanStage.finalMonth, PlanQuickAddKind.cost) => 10,
    (WeddingPlanStage.finalWeek, PlanQuickAddKind.task) => 70,
    (WeddingPlanStage.finalWeek, PlanQuickAddKind.guest) => 20,
    (WeddingPlanStage.finalWeek, PlanQuickAddKind.cost) => 15,
    (WeddingPlanStage.weddingDay, PlanQuickAddKind.task) => 80,
    (WeddingPlanStage.weddingDay, PlanQuickAddKind.quote) => -100,
    (WeddingPlanStage.wrapUp, PlanQuickAddKind.cost) => 25,
    (WeddingPlanStage.wrapUp, PlanQuickAddKind.task) => 10,
    _ => 0,
  };
}

/// Opens what [kind] names. The new agreement, item and task forms are
/// pushed; a payment or a payment date asks for its agreement first. The
/// guest sheet and the providers live inside the shell, which opens them
/// through [onAddGuest] and [onFindProviders]. [onChanged] runs when the
/// plan changed, so the home numbers follow; with [refreshOnReturn] it runs
/// on every return (a plan kept on the phone rereads its own summary, which
/// a new task does not report back).
Future<void> openPlanQuickAdd(
  BuildContext context, {
  required String planId,
  required PlanQuickAddKind kind,
  required VoidCallback onAddGuest,
  required VoidCallback onFindProviders,
  required Future<void> Function() onChanged,
  bool refreshOnReturn = false,
}) async {
  rememberPlanQuickAdd(planId, kind);
  final bool changed;
  switch (kind) {
    case PlanQuickAddKind.guest:
      onAddGuest();
      return;
    case PlanQuickAddKind.quote:
      onFindProviders();
      return;
    case PlanQuickAddKind.payment || PlanQuickAddKind.schedule:
      changed = await openMoneyCostAction(
        context,
        planId: planId,
        intent: kind == PlanQuickAddKind.payment
            ? MoneyCostActionIntent.payment
            : MoneyCostActionIntent.schedule,
      );
    case PlanQuickAddKind.cost ||
        PlanQuickAddKind.category ||
        PlanQuickAddKind.task:
      final route = switch (kind) {
        PlanQuickAddKind.cost => AppRouter.moneyCostCreate(planId),
        PlanQuickAddKind.category => AppRouter.moneyCategoryCreate(planId),
        _ => AppRouter.createTask(planId),
      };
      // The item form answers with the new item's id, the others with true.
      final result = await context.push<Object?>(route);
      changed = result != null && result != false;
  }
  if ((changed || refreshOnReturn) && context.mounted) await onChanged();
}
