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
    required this.incompleteGuestCount,
    required this.providerCount,
    required this.spentTotal,
    required this.debtTotal,
    required this.paidDebtTotal,
    required this.unpaidDebtTotal,
    required this.dueInstallmentsCount,
    required this.localImportantItems,
    required this.localRecentActivity,
    required this.financialWarnings,
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
  final int incompleteGuestCount;
  final int providerCount;
  final String spentTotal;
  final String debtTotal;
  final String paidDebtTotal;
  final String unpaidDebtTotal;
  final int dueInstallmentsCount;
  final List<DashboardImportantItem> localImportantItems;
  final List<DashboardImportantItem> localRecentActivity;
  final List<DashboardFinancialWarning> financialWarnings;

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
      incompleteGuestCount: metrics.incompleteGuestCount,
      providerCount: 0,
      spentTotal: _amountString(metrics.spentTotal),
      debtTotal: _amountString(metrics.debtTotal),
      paidDebtTotal: _amountString(metrics.paidDebtTotal),
      unpaidDebtTotal: _amountString(metrics.unpaidDebtTotal),
      dueInstallmentsCount: metrics.dueInstallmentsCount,
      localImportantItems: metrics.importantItems,
      localRecentActivity: metrics.recentActivity,
      financialWarnings: metrics.financialWarnings(
        budget: _cleanAmount(plan.estimatedBudget),
        hasLocation: plan.weddingLocation.shortLabel != null,
      ),
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
    return DashboardSummary(
      dataScope: 'LOCAL',
      accountBacked: false,
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
      incompleteGuestsCount: incompleteGuestCount,
      providerCount: providerCount,
      quoteRequestsCount: 0,
      pendingQuoteRequests: 0,
      receivedQuotes: 0,
      acceptedProviders: 0,
      quoteStatusBreakdown: const {
        'pending': 0,
        'offered': 0,
        'accepted': 0,
        'rejectedClosed': 0,
      },
      participantCount: 1,
      pendingInvites: 0,
      unreadNotificationsCount: 0,
      importantItems: localImportantItems,
      recentActivity: localRecentActivity,
      planProviders: const [],
      importantNotifications: const [],
      moneySummary: DashboardMoneySummary(
        totalBudget: budget,
        totalSpent: spentTotal,
        remainingBudget: remainingBudget ?? budget,
        totalDebts: debtTotal,
        overBudget: budget == null
            ? null
            : _moneyValue(spentTotal) > _moneyValue(budget),
      ),
      financialWarnings: financialWarnings,
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

  // ignore: unused_element
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
    required this.incompleteGuestCount,
    required this.spentTotal,
    required this.debtTotal,
    required this.paidDebtTotal,
    required this.unpaidDebtTotal,
    required this.dueInstallmentsCount,
    required this.importantItems,
    required this.recentActivity,
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
    incompleteGuestCount: 0,
    spentTotal: 0,
    debtTotal: 0,
    paidDebtTotal: 0,
    unpaidDebtTotal: 0,
    dueInstallmentsCount: 0,
    importantItems: [],
    recentActivity: [],
  );

  final int taskCount;
  final int completedTaskCount;
  final int overdueTaskCount;
  final int todayTaskCount;
  final int guestCount;
  final int confirmedGuestCount;
  final int pendingGuestCount;
  final int declinedGuestCount;
  final int incompleteGuestCount;
  final num spentTotal;
  final num debtTotal;
  final num paidDebtTotal;
  final num unpaidDebtTotal;
  final int dueInstallmentsCount;
  final List<DashboardImportantItem> importantItems;
  final List<DashboardImportantItem> recentActivity;

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
    final dueInstallments = installments.where((installment) {
      final status = _statusOf(installment);
      return status != 'PAID' &&
          status != 'CANCELLED' &&
          _dateTimeOrNull(installment['dueDate']) != null;
    }).toList();
    final dueInstallmentsCount = dueInstallments.length;
    final incompleteGuestCount = guests.where(_isIncompleteGuest).length;

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
      incompleteGuestCount: incompleteGuestCount,
      spentTotal: spentTotal,
      debtTotal: debtTotal,
      paidDebtTotal: paidDebtTotal,
      unpaidDebtTotal: unpaidDebtTotal,
      dueInstallmentsCount: dueInstallmentsCount,
      importantItems: _localPriorityItems(
        guests: guests,
        tasks: activeTasks,
        installments: dueInstallments,
      ),
      recentActivity: _localActivityItems(
        guests: guests,
        tasks: activeTasks,
        expenses: activeExpenses,
        debts: activeDebts,
      ),
    );
  }

  List<DashboardFinancialWarning> financialWarnings({
    required String? budget,
    required bool hasLocation,
  }) {
    final warnings = <DashboardFinancialWarning>[];
    final budgetValue = _moneyValue(budget);
    if (!hasLocation) {
      warnings.add(
        const DashboardFinancialWarning(
          type: 'MISSING_LOCATION',
          severity: 'WARNING',
          message: 'أضف موقع الزفاف حتى تصبح الخطة أوضح للمشاركين.',
        ),
      );
    }
    if (budget == null || budgetValue == 0) {
      warnings.add(
        const DashboardFinancialWarning(
          type: 'MISSING_BUDGET',
          severity: 'WARNING',
          message: 'أضف الميزانية المتوقعة حتى نعرض المتبقي بدقة.',
        ),
      );
    } else if (spentTotal > budgetValue) {
      warnings.add(
        DashboardFinancialWarning(
          type: 'BUDGET_EXCEEDED',
          severity: 'DANGER',
          message: 'المصروفات أعلى من الميزانية الحالية.',
          amount: _amountString(spentTotal - budgetValue),
        ),
      );
    }
    if (overdueTaskCount > 0) {
      warnings.add(
        DashboardFinancialWarning(
          type: 'TASK_OVERDUE',
          severity: 'WARNING',
          message: 'لديك مهام متأخرة تحتاج مراجعة.',
          count: overdueTaskCount,
        ),
      );
    }
    if (dueInstallmentsCount > 0) {
      warnings.add(
        DashboardFinancialWarning(
          type: 'INSTALLMENT_DUE_SOON',
          severity: 'WARNING',
          message: 'هناك أقساط قادمة ضمن الخطة.',
          count: dueInstallmentsCount,
        ),
      );
    }
    if (incompleteGuestCount > 0) {
      warnings.add(
        DashboardFinancialWarning(
          type: 'INCOMPLETE_GUESTS',
          severity: 'WARNING',
          message: 'بعض الضيوف ينقصهم رقم هاتف أو بيانات تواصل.',
          count: incompleteGuestCount,
        ),
      );
    }
    return warnings;
  }
}

List<DashboardImportantItem> _localPriorityItems({
  required List<Map<String, dynamic>> guests,
  required List<Map<String, dynamic>> tasks,
  required List<Map<String, dynamic>> installments,
}) {
  final today = _dateOnly(DateTime.now());
  final priorities = <DashboardImportantItem>[];
  final overdueTask = _firstOrNull(
    tasks.where((task) {
      final dueDate = _dateTimeOrNull(task['dueDate']);
      return _statusOf(task) != 'DONE' &&
          dueDate != null &&
          _dateOnly(dueDate).isBefore(today);
    }),
  );
  if (overdueTask != null) {
    priorities.add(
      DashboardImportantItem(
        id: overdueTask['id']?.toString() ?? 'local-overdue-task',
        type: 'TASK_OVERDUE',
        title: _textValue(overdueTask['title'], fallback: 'مهمة متأخرة'),
        subtitle: 'مهمة تحتاج متابعة',
        icon: 'calendar',
        tone: 'danger',
        priority: 'URGENT',
        actionLabel: 'فتح المهام',
        data: const {'source': 'guest_local'},
      ),
    );
  }

  final nextInstallment = _firstOrNull(installments);
  if (nextInstallment != null) {
    priorities.add(
      DashboardImportantItem(
        id: nextInstallment['id']?.toString() ?? 'local-due-installment',
        type: 'INSTALLMENT_DUE',
        title: 'قسط قادم في الخطة',
        subtitle: 'استحقاق مالي',
        icon: 'wallet',
        tone: 'warning',
        priority: 'HIGH',
        actionLabel: 'عرض المال',
        amount: _amountString(_moneyValue(nextInstallment['amount'])),
        data: const {'source': 'guest_local'},
      ),
    );
  }

  final incompleteGuest = _firstOrNull(guests.where(_isIncompleteGuest));
  if (incompleteGuest != null) {
    priorities.add(
      DashboardImportantItem(
        id: incompleteGuest['id']?.toString() ?? 'local-incomplete-guest',
        type: 'GUEST_INCOMPLETE',
        title:
            'ضيف يحتاج رقم هاتف: ${_textValue(incompleteGuest['name'], fallback: 'ضيف')}',
        subtitle: 'بيانات ضيف ناقصة',
        icon: 'people',
        tone: 'info',
        priority: 'NORMAL',
        actionLabel: 'عرض الضيوف',
        data: const {'source': 'guest_local'},
      ),
    );
  }

  return priorities.take(3).toList();
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

bool _isIncompleteGuest(Map<String, dynamic> guest) {
  final phone = guest['phone']?.toString().trim();
  return phone == null || phone.isEmpty;
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

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
