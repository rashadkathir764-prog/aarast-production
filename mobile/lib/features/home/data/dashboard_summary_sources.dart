import '../../../core/offline/local_database.dart';
import '../../../core/offline/offline_tables.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/generated_dashboard_seed.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../wedding_plans/models/active_wedding_plan.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';

class BackendDashboardSummarySource {
  const BackendDashboardSummarySource(this._provider);

  final WeddingPlansProvider _provider;

  Future<ActiveWeddingPlan?> loadActivePlan() async {
    await _provider.loadActiveWeddingPlan();
    return _provider.activePlan;
  }
}

class LocalGuestDashboardSummarySource {
  const LocalGuestDashboardSummarySource(
    this._storage, {
    LocalDatabase? database,
  }) : _database = database;

  final GuestOnboardingStorage _storage;
  final LocalDatabase? _database;

  Future<LocalGuestDashboardSummary?> loadSummary() async {
    final plan = await _storage.loadGuestPlan();
    if (plan == null) return null;
    final database = _database;
    if (database == null) return LocalGuestDashboardSummary.fromPlan(plan);
    final planId = plan.guestPlanId ?? 'local-guest-plan';
    final metrics = await LocalDashboardMetrics.load(
      database: database,
      planId: planId,
    );
    return LocalGuestDashboardSummary.fromPlan(plan, metrics: metrics);
  }
}

class LocalGuestDashboardSummary {
  const LocalGuestDashboardSummary({
    required this.plan,
    required this.seed,
    required this.daysRemaining,
    required this.progressPercent,
    required this.taskCount,
    required this.completedTaskCount,
    required this.overdueTaskCount,
    required this.todayTaskCount,
    required this.guestCount,
    required this.confirmedGuestCount,
    required this.pendingGuestCount,
    required this.declinedGuestCount,
    required this.providerCount,
    required this.spentTotal,
    required this.debtTotal,
    required this.paidDebtTotal,
    required this.unpaidDebtTotal,
    required this.dueInstallmentsCount,
    required this.localImportantItems,
  });

  final GuestOnboardingDraft plan;
  final GeneratedDashboardSeed seed;
  final int? daysRemaining;
  final int progressPercent;
  final int taskCount;
  final int completedTaskCount;
  final int overdueTaskCount;
  final int todayTaskCount;
  final int guestCount;
  final int confirmedGuestCount;
  final int pendingGuestCount;
  final int declinedGuestCount;
  final int providerCount;
  final String spentTotal;
  final String debtTotal;
  final String paidDebtTotal;
  final String unpaidDebtTotal;
  final int dueInstallmentsCount;
  final List<DashboardImportantItem> localImportantItems;

  factory LocalGuestDashboardSummary.fromPlan(
    GuestOnboardingDraft plan, {
    DateTime? now,
    LocalDashboardMetrics metrics = LocalDashboardMetrics.empty,
  }) {
    final today = now ?? DateTime.now();
    final weddingDate = plan.weddingDate;
    final daysRemaining = weddingDate == null
        ? null
        : DateTime(
            weddingDate.year,
            weddingDate.month,
            weddingDate.day,
          ).difference(DateTime(today.year, today.month, today.day)).inDays;

    return LocalGuestDashboardSummary(
      plan: plan,
      seed: GeneratedDashboardSeed.fromDraft(plan),
      daysRemaining: daysRemaining?.clamp(0, 100000),
      progressPercent: metrics.progressPercent,
      taskCount: metrics.taskCount,
      completedTaskCount: metrics.completedTaskCount,
      overdueTaskCount: metrics.overdueTaskCount,
      todayTaskCount: metrics.todayTaskCount,
      guestCount: metrics.guestCount,
      confirmedGuestCount: metrics.confirmedGuestCount,
      pendingGuestCount: metrics.pendingGuestCount,
      declinedGuestCount: metrics.declinedGuestCount,
      providerCount: 0,
      spentTotal: _amountString(metrics.spentTotal),
      debtTotal: _amountString(metrics.debtTotal),
      paidDebtTotal: _amountString(metrics.paidDebtTotal),
      unpaidDebtTotal: _amountString(metrics.unpaidDebtTotal),
      dueInstallmentsCount: metrics.dueInstallmentsCount,
      localImportantItems: metrics.importantItems,
    );
  }

  DashboardSummary toDashboardSummary() {
    final budget = _cleanAmount(plan.estimatedBudget);
    final remainingBudget = budget == null
        ? null
        : _amountString(
            (_moneyValue(budget) - _moneyValue(spentTotal)).clamp(
              0,
              double.infinity,
            ),
          );
    final fallbackImportantItem = _localImportantItem();
    final importantItems = localImportantItems.isEmpty
        ? fallbackImportantItem == null
              ? const <DashboardImportantItem>[]
              : [fallbackImportantItem]
        : localImportantItems;

    return DashboardSummary(
      planId: plan.guestPlanId ?? 'local-guest-plan',
      title: seed.title,
      weddingDate: plan.weddingDate,
      city: plan.weddingLocation.shortLabel ?? seed.shortLocationLabel,
      location: plan.weddingLocation.toJson(),
      status: 'PLANNING',
      daysRemaining: daysRemaining,
      progressPercentage: progressPercent,
      budgetTotal: budget,
      spentTotal: spentTotal,
      remainingBudget: remainingBudget ?? budget,
      debtTotal: debtTotal,
      paidDebtTotal: paidDebtTotal,
      unpaidDebtTotal: unpaidDebtTotal,
      dueInstallmentsCount: dueInstallmentsCount,
      totalTasks: taskCount,
      completedTasks: completedTaskCount,
      overdueTasks: overdueTaskCount,
      todayTasks: todayTaskCount,
      guestCount: guestCount,
      confirmedGuests: confirmedGuestCount,
      pendingGuests: pendingGuestCount,
      declinedGuests: declinedGuestCount,
      providerCount: providerCount,
      quoteRequestsCount: 0,
      unreadNotificationsCount: 0,
      importantItems: importantItems,
      planProviders: const [],
      importantNotifications: const [],
      generatedAt: plan.createdAt,
      currentUserRole: 'GUEST',
      permissions: const DashboardPermissionSummary(
        isOwner: true,
        role: 'GUEST_LOCAL',
        canViewBudget: true,
        canViewExpenses: true,
        canViewDebts: true,
        canManageTasks: true,
        canManageGuests: true,
        canManageFinancialRecords: true,
        canManagePlan: true,
      ),
    );
  }

  DashboardImportantItem? _localImportantItem() {
    final title = seed.nextBestAction.trim();
    if (title.isEmpty) return null;
    return DashboardImportantItem(
      id: 'local-next-step',
      type: 'LOCAL_NEXT_STEP',
      title: title,
      subtitle: 'خطة محلية',
      icon: 'calendar',
      tone: 'info',
      actionLabel: 'متابعة',
      data: {
        'source': 'guest_local',
        'selectedCategories': seed.selectedCategories.join(','),
      },
    );
  }
}

String? _cleanAmount(String? value) {
  final trimmed = value?.replaceAll(',', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class LocalDashboardMetrics {
  const LocalDashboardMetrics({
    required this.taskCount,
    required this.completedTaskCount,
    required this.overdueTaskCount,
    required this.todayTaskCount,
    required this.guestCount,
    required this.confirmedGuestCount,
    required this.pendingGuestCount,
    required this.declinedGuestCount,
    required this.spentTotal,
    required this.debtTotal,
    required this.paidDebtTotal,
    required this.unpaidDebtTotal,
    required this.dueInstallmentsCount,
    required this.importantItems,
  });

  static const empty = LocalDashboardMetrics(
    taskCount: 0,
    completedTaskCount: 0,
    overdueTaskCount: 0,
    todayTaskCount: 0,
    guestCount: 0,
    confirmedGuestCount: 0,
    pendingGuestCount: 0,
    declinedGuestCount: 0,
    spentTotal: 0,
    debtTotal: 0,
    paidDebtTotal: 0,
    unpaidDebtTotal: 0,
    dueInstallmentsCount: 0,
    importantItems: [],
  );

  final int taskCount;
  final int completedTaskCount;
  final int overdueTaskCount;
  final int todayTaskCount;
  final int guestCount;
  final int confirmedGuestCount;
  final int pendingGuestCount;
  final int declinedGuestCount;
  final num spentTotal;
  final num debtTotal;
  final num paidDebtTotal;
  final num unpaidDebtTotal;
  final int dueInstallmentsCount;
  final List<DashboardImportantItem> importantItems;

  int get progressPercent {
    if (taskCount == 0) return 0;
    return ((completedTaskCount / taskCount) * 100).round().clamp(0, 100);
  }

  static Future<LocalDashboardMetrics> load({
    required LocalDatabase database,
    required String planId,
  }) async {
    final guests = await database.readCachedList(
      table: OfflineTables.cachedGuests,
      parentColumn: 'planId',
      parentId: planId,
    );
    final tasks = await database.readCachedList(
      table: OfflineTables.cachedTasks,
      parentColumn: 'planId',
      parentId: planId,
    );
    final expenses = await database.readCachedList(
      table: OfflineTables.cachedBudgetItems,
      parentColumn: 'planId',
      parentId: planId,
    );
    final debts = await database.readCachedList(
      table: OfflineTables.cachedDebts,
      parentColumn: 'planId',
      parentId: planId,
    );
    final installments = <Map<String, dynamic>>[];
    for (final debt in debts) {
      final debtId = debt['id']?.toString();
      if (debtId == null || debtId.isEmpty) continue;
      installments.addAll(
        await database.readCachedList(
          table: OfflineTables.cachedInstallments,
          parentColumn: 'debtId',
          parentId: debtId,
        ),
      );
    }

    final today = _dateOnly(DateTime.now());
    final activeTasks = tasks.where((task) {
      return _statusOf(task) != 'DELETED';
    }).toList();
    final completedTasks = activeTasks.where((task) {
      return _statusOf(task) == 'DONE';
    }).length;
    final overdueTasks = activeTasks.where((task) {
      final dueDate = _dateTimeOrNull(task['dueDate']);
      return _statusOf(task) != 'DONE' &&
          dueDate != null &&
          _dateOnly(dueDate).isBefore(today);
    }).length;
    final todayTasks = activeTasks.where((task) {
      final dueDate = _dateTimeOrNull(task['dueDate']);
      return _statusOf(task) != 'DONE' &&
          dueDate != null &&
          _dateOnly(dueDate) == today;
    }).length;

    final activeExpenses = expenses.where((expense) {
      return _statusOf(expense) != 'CANCELLED';
    }).toList();
    final spentTotal = activeExpenses.fold<num>(
      0,
      (sum, expense) => sum + _moneyValue(expense['amount']),
    );

    final activeDebts = debts.where((debt) {
      return _statusOf(debt) != 'CANCELLED';
    }).toList();
    final debtTotal = activeDebts.fold<num>(
      0,
      (sum, debt) => sum + _moneyValue(debt['totalAmount']),
    );
    final paidDebtTotal = activeDebts.fold<num>(
      0,
      (sum, debt) => sum + _moneyValue(debt['paidAmount']),
    );
    final unpaidDebtTotal = (debtTotal - paidDebtTotal).clamp(0, debtTotal);
    final dueInstallmentsCount = installments.where((installment) {
      final status = _statusOf(installment);
      return status != 'PAID' &&
          status != 'CANCELLED' &&
          _dateTimeOrNull(installment['dueDate']) != null;
    }).length;

    return LocalDashboardMetrics(
      taskCount: activeTasks.length,
      completedTaskCount: completedTasks,
      overdueTaskCount: overdueTasks,
      todayTaskCount: todayTasks,
      guestCount: guests.length,
      confirmedGuestCount: guests
          .where((guest) => _statusOf(guest) == 'CONFIRMED')
          .length,
      pendingGuestCount: guests
          .where((guest) => _statusOf(guest) == 'PENDING')
          .length,
      declinedGuestCount: guests
          .where((guest) => _statusOf(guest) == 'DECLINED')
          .length,
      spentTotal: spentTotal,
      debtTotal: debtTotal,
      paidDebtTotal: paidDebtTotal,
      unpaidDebtTotal: unpaidDebtTotal,
      dueInstallmentsCount: dueInstallmentsCount,
      importantItems: _localActivityItems(
        guests: guests,
        tasks: activeTasks,
        expenses: activeExpenses,
        debts: activeDebts,
      ),
    );
  }
}

List<DashboardImportantItem> _localActivityItems({
  required List<Map<String, dynamic>> guests,
  required List<Map<String, dynamic>> tasks,
  required List<Map<String, dynamic>> expenses,
  required List<Map<String, dynamic>> debts,
}) {
  final rows = <_LocalActivityRow>[
    for (final task in tasks)
      _LocalActivityRow(
        json: task,
        type: 'LOCAL_TASK',
        title: 'مهمة محفوظة: ${_textValue(task['title'], fallback: 'مهمة')}',
        subtitle: 'نشاط محلي',
        icon: 'task',
        tone: 'info',
        actionLabel: 'عرض المهام',
      ),
    for (final expense in expenses)
      _LocalActivityRow(
        json: expense,
        type: 'LOCAL_MONEY_EXPENSE',
        title:
            'مصروف محفوظ: ${_textValue(expense['title'], fallback: 'مصروف')}',
        subtitle: 'نشاط محلي',
        icon: 'wallet',
        tone: 'warning',
        actionLabel: 'عرض المال',
        amount: _amountString(_moneyValue(expense['amount'])),
      ),
    for (final debt in debts)
      _LocalActivityRow(
        json: debt,
        type: 'LOCAL_MONEY_DEBT',
        title: 'دين محفوظ: ${_textValue(debt['title'], fallback: 'دين')}',
        subtitle: 'نشاط محلي',
        icon: 'wallet',
        tone: 'danger',
        actionLabel: 'عرض الديون',
        amount: _amountString(_moneyValue(debt['totalAmount'])),
      ),
    for (final guest in guests)
      _LocalActivityRow(
        json: guest,
        type: 'LOCAL_GUEST',
        title: 'ضيف محفوظ: ${_textValue(guest['name'], fallback: 'ضيف')}',
        subtitle: 'نشاط محلي',
        icon: 'people',
        tone: 'success',
        actionLabel: 'عرض الضيوف',
      ),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return rows.take(4).map((row) => row.toImportantItem()).toList();
}

class _LocalActivityRow {
  _LocalActivityRow({
    required this.json,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.actionLabel,
    this.amount,
  });

  final Map<String, dynamic> json;
  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final String tone;
  final String actionLabel;
  final String? amount;

  DateTime get timestamp =>
      _dateTimeOrNull(json['updatedAt']) ??
      _dateTimeOrNull(json['createdAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  DashboardImportantItem toImportantItem() {
    final id =
        json['id']?.toString() ?? '$type-${timestamp.microsecondsSinceEpoch}';
    return DashboardImportantItem(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      icon: icon,
      tone: tone,
      actionLabel: actionLabel,
      entityId: id,
      amount: amount,
      data: const {'source': 'guest_local'},
    );
  }
}

String _statusOf(Map<String, dynamic> json) =>
    json['status']?.toString().trim().toUpperCase() ?? '';

String _textValue(Object? value, {required String fallback}) {
  final trimmed = value?.toString().trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

num _moneyValue(Object? value) {
  return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
}

String _amountString(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}
