part of 'finance_local_data_source.dart';

/// The money picture of a plan kept on the phone: the money tab's answers
/// worked out as the server works them out (finance_local_money_plan.dart,
/// held to the server's by its fixtures), and the ledger's sums from the
/// same rows. The money tab and the home both read it, so the phone has one
/// formula (D59). An account plan never comes here: it reads the server's
/// (C2).
///
/// [plan] is what the plan's questions recorded: the budget (when the money
/// tab never saved one), the persona, the mahr (RA-MO-89) and whether the
/// groom counts it inside the budget (D114; the money tab's own save of the
/// budget comes first).
Future<MoneySummary> localPlanMoneySummary(
  LocalDatabase? database,
  String planId, {
  LocalFinancePlanContext? plan,
  MoneyFundingSummary? funding,

  /// The plan's agreements and payment dates when the caller has read them
  /// already (the home reads them for its own lists): not read a second
  /// time here.
  List<Map<String, dynamic>>? costRows,
  List<Map<String, dynamic>>? scheduleRows,
}) async {
  Future<List<Map<String, dynamic>>> rows(String table) async =>
      await database?.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: planId,
      ) ??
      const [];
  final rawBudget = await database?.getMeta(
    FinanceLocalDataSource.budgetMetaKey(planId),
  );
  final decodedBudget = rawBudget == null || rawBudget.isEmpty
      ? null
      : jsonDecode(rawBudget);
  final budget = decodedBudget is Map
      ? Map<String, dynamic>.from(decodedBudget)
      : null;
  final persona = plan?.persona;
  final totalBudget = _nullableMoney(
    budget?['totalBudget'] ?? plan?.estimatedBudget,
  );
  final resolvedCurrency =
      stringOrNull(budget?['currency']) ??
      stringOrNull(plan?.currency)?.toUpperCase() ??
      'YER';
  // D114: the money tab's save of the budget, else the plan's questions.
  final budgetIncludesMahr = switch (budget?['budgetIncludesMahr']) {
    final bool saved => saved,
    _ => plan?.budgetIncludesMahr == true,
  };
  final rawCategories = await rows(OfflineTables.cachedBudgetCategories);
  final costs = (costRows ?? await rows(OfflineTables.cachedCosts))
      .where((cost) => cost['status']?.toString() != 'CANCELLED')
      .toList();
  final activeCostIds = costs
      .map((cost) => cost['id']?.toString())
      .whereType<String>()
      .toSet();
  final payments = (await rows(
    OfflineTables.cachedCostPayments,
  )).where((payment) => activeCostIds.contains(payment['costId']?.toString()));
  final schedules =
      (scheduleRows ?? await rows(OfflineTables.cachedPaymentSchedules))
          .where(
            (schedule) =>
                activeCostIds.contains(schedule['costId']?.toString()),
          )
          .toList();

  // What each agreement was paid, from the payments ledger net of its
  // reversals, as the server reads it (D59).
  final paidByCost = localNetPaidByCost(payments);
  // D102-D109: the money tab's answers, as the server composes them
  // (finance_local_money_plan.dart, held to the server's by its fixtures).
  final planInput = _localPlanInput(
    persona: persona,
    totalBudget: totalBudget,
    budgetIncludesMahr: budgetIncludesMahr,
    categories: rawCategories,
    costs: costs,
    paidByCost: paidByCost,
    payments: payments,
    schedules: schedules,
    sources: await rows(OfflineTables.cachedFundingSources),
  );
  _addDraftMahr(planInput, plan, persona: persona);
  final answer = localMoneyPlan(planInput);
  final planItems = {
    for (final item in answer['items'] as List)
      (item as Map)['id'].toString(): Map<String, dynamic>.from(item),
  };
  final categorySummaries = rawCategories.map((raw) {
    final id = raw['id']?.toString() ?? '';
    final categoryCosts = costs
        .where((cost) => cost['budgetCategoryId']?.toString() == id)
        .toList();
    final confirmed = categoryCosts.fold<num>(
      0,
      (sum, cost) => sum + FinanceMoneyRules.value(cost['totalAmount']),
    );
    final paid = categoryCosts.fold<num>(
      0,
      (sum, cost) => sum + (paidByCost[cost['id']?.toString()] ?? 0),
    );
    final allocation = _nullableMoney(raw['allocatedAmount']);
    return MoneyCategorySummary(
      categoryId: id,
      name: raw['name']?.toString() ?? '',
      allocatedAmount: allocation,
      confirmedCost: FinanceMoneyRules.asMoney(confirmed) ?? '0',
      paid: FinanceMoneyRules.asMoney(paid) ?? '0',
      outstanding:
          FinanceMoneyRules.asMoney((confirmed - paid).clamp(0, confirmed)) ??
          '0',
      remainingAllocation: allocation == null
          ? null
          : FinanceMoneyRules.asMoney(
              FinanceMoneyRules.value(allocation) - confirmed,
            ),
      costsCount: categoryCosts.length,
      isMahr: raw['kind']?.toString() == 'MAHR',
      estimatedAmount: _nullableMoney(raw['estimatedAmount']),
      estimate: planItems[id]?['estimate']?.toString(),
      estimateFromAllocation: planItems[id]?['estimateSource'] == 'ALLOCATION',
      expectedCost: planItems[id]?['expectedCost']?.toString(),
      estimateLeft: planItems[id]?['estimateLeft']?.toString(),
      costKnown: planItems[id]?['costKnown'] as bool?,
    );
  }).toList();

  final scheduleSummary = LocalPaymentScheduleSummary.from(schedules, _today());

  final expected = MoneyExpected.fromJson(
    Map<String, dynamic>.from(answer['expected'] as Map),
  );
  final coverage = MoneyCoverage.fromJson(answer['coverage']);
  final warnings = <MoneyWarning>[
    // D105: by the expected cost (agreements and the estimates they have
    // not settled), as the server warns; D114: the mahr's with it when it
    // counts inside the budget.
    if (totalBudget != null && FinanceMoneyRules.value(expected.budgetLeft) < 0)
      MoneyWarning(
        type: 'BUDGET_EXCEEDED',
        severity: 'DANGER',
        amount: FinanceMoneyRules.asMoney(
          -FinanceMoneyRules.value(expected.budgetLeft),
        ),
      ),
    for (final category in categorySummaries)
      if (category.allocatedAmount != null &&
          FinanceMoneyRules.value(category.expectedCost) >
              FinanceMoneyRules.value(category.allocatedAmount))
        MoneyWarning(
          type: 'CATEGORY_EXCEEDED',
          severity: 'DANGER',
          categoryId: category.categoryId,
          count: category.costsCount,
          amount: FinanceMoneyRules.asMoney(
            FinanceMoneyRules.value(category.expectedCost) -
                FinanceMoneyRules.value(category.allocatedAmount),
          ),
        ),
    if (coverage?.shortfall case final short?)
      MoneyWarning(
        type: 'FUNDING_SHORTFALL',
        severity: 'WARNING',
        amount: short.amount,
      ),
    if (scheduleSummary.overdueCount > 0)
      MoneyWarning(
        type: 'PAYMENT_SCHEDULE_OVERDUE',
        severity: 'DANGER',
        count: scheduleSummary.overdueCount,
      ),
    if (scheduleSummary.dueSoonCount > 0)
      MoneyWarning(
        type: 'PAYMENT_SCHEDULE_DUE_SOON',
        severity: 'WARNING',
        count: scheduleSummary.dueSoonCount,
      ),
  ];

  // Every agreement, the mahr's included (the draft mahr's too, as the
  // account makes it), from the same rows the plan's answers read.
  final allCosts = [
    for (final cost in planInput['costs'] as List)
      Map<String, dynamic>.from(cost as Map),
  ];
  num sumOf(Iterable<Map<String, dynamic>> rows, String key) =>
      rows.fold<num>(0, (sum, row) => sum + FinanceMoneyRules.value(row[key]));
  final costTotal = sumOf(allCosts, 'totalAmount');
  final paidTotal = sumOf(allCosts, 'paid');
  final paidByOwner = sumOf(
    allCosts.where((cost) => cost['ownerMoney'] == true),
    'paid',
  );

  return MoneySummary(
    planId: planId,
    currency: resolvedCurrency,
    budget: MoneyBudgetSummary.fromJson(
      Map<String, dynamic>.from(answer['budget'] as Map),
    ),
    costs: MoneyCostsSummary(
      total: FinanceMoneyRules.asMoney(costTotal) ?? '0',
      paid: FinanceMoneyRules.asMoney(paidTotal) ?? '0',
      paidByOwner: FinanceMoneyRules.asMoney(paidByOwner) ?? '0',
      paidByOthers: FinanceMoneyRules.asMoney(paidTotal - paidByOwner) ?? '0',
      outstanding: FinanceMoneyRules.asMoney(costTotal - paidTotal) ?? '0',
      count: allCosts.length,
    ),
    paymentSchedules: MoneySchedulesSummary(
      totalCount: schedules.length,
      upcomingCount: scheduleSummary.upcomingCount,
      overdueCount: scheduleSummary.overdueCount,
      paidCount: scheduleSummary.paidCount,
      next: scheduleSummary.pending.isEmpty
          ? null
          : PaymentSchedule.fromJson(scheduleSummary.pending.first),
    ),
    categories: categorySummaries,
    warnings: warnings,
    funding: funding ?? _localFunding(planInput, coverage),
    mahr: _localMahr(planInput, plan, persona: persona),
    expected: expected,
    outstanding: MoneyOutstanding.fromJson(
      Map<String, dynamic>.from(answer['outstanding'] as Map),
    ),
    obligations: [
      for (final line in answer['obligations'] as List)
        ?MoneyObligation.fromJson(Map<String, dynamic>.from(line as Map)),
    ],
    duesByMonth: MoneyDuesByMonth.fromJson(
      Map<String, dynamic>.from(answer['duesByMonth'] as Map),
    ),
    coverage: coverage,
    family: answer['family'] is List
        ? [
            for (final person in answer['family'] as List)
              MoneyContributor.fromJson(
                Map<String, dynamic>.from(person as Map),
              ),
          ]
        : null,
    permissions: const MoneyPermissions(
      canViewMoney: true,
      canManageMoney: true,
    ),
  );
}

/// RA-MO-89: on a plan kept on the phone the mahr lived in the plan's
/// answers alone, outside the money worked out here, so «عليك» left out
/// what remained of it and the cover could say enough where the account,
/// once saved, said short. The groom's mahr goes in as the account makes
/// it: an item of its own, its agreement, what was handed over paid, and
/// the rest due on its day. Only while the phone has no mahr item of its
/// own; the bride's mahr is money coming in, not this.
void _addDraftMahr(
  Map<String, dynamic> input,
  LocalFinancePlanContext? draft, {
  required String? persona,
}) {
  final total = FinanceMoneyRules.value(draft?.mahrTotal);
  if (persona != 'GROOM' || total <= 0) return;
  final items = input['items'] as List;
  if (items.any((item) => (item as Map)['kind'] == 'MAHR')) return;
  final settled = FinanceMoneyRules.value(draft?.mahrSettled);
  final paid = settled > total ? total : settled;
  const itemId = 'local-draft-mahr';
  const costId = 'local-draft-mahr-agreement';
  items.add({
    'id': itemId,
    'kind': 'MAHR',
    'allocatedAmount': null,
    'estimatedAmount': null,
    'notNeeded': false,
  });
  (input['costs'] as List).add({
    'id': costId,
    'budgetCategoryId': itemId,
    'title': 'المهر',
    'totalAmount': FinanceMoneyRules.asMoney(total),
    'paid': FinanceMoneyRules.asMoney(paid),
    'payer': null,
    'payerName': null,
    'ownerMoney': true,
    'estimateCover': null,
    'estimatePart': null,
  });
  final due = draft?.mahrDueDate;
  if (due != null && total > paid) {
    (input['schedules'] as List).add({
      'id': 'local-draft-mahr-date',
      'weddingCostId': costId,
      'amount': FinanceMoneyRules.asMoney(total - paid),
      'dueDate': planDayToJson(due),
      'status': 'PENDING',
      'note': null,
      'remindAt': null,
      'rescheduledFrom': null,
      'partlyPaid': '0',
      'createdAt': '',
    });
  }
}

/// The plan's mahr as the server reads it (backend `summarizeMahr`): the
/// groom's from his mahr item's agreements (the draft's among them), the
/// bride's from her mahr money coming in, else from the plan's questions,
/// which the account makes her mahr sources when the plan is saved. Null
/// before it is recorded and on a plan without a mahr side.
MoneyMahrSummary? _localMahr(
  Map<String, dynamic> input,
  LocalFinancePlanContext? draft, {
  required String? persona,
}) {
  MoneyMahrSummary picture(MahrSide side, num total, num settled, Object? due) {
    final remaining = total - settled;
    return MoneyMahrSummary(
      side: side,
      total: FinanceMoneyRules.asMoney(total) ?? '0',
      settled: FinanceMoneyRules.asMoney(settled) ?? '0',
      remaining: FinanceMoneyRules.asMoney(remaining) ?? '0',
      nextDueAt: remaining > 0 ? planDayFromJson(due) : null,
      complete: total > 0 && remaining <= 0,
    );
  }

  if (persona == 'GROOM') {
    final mahrItems = {
      for (final item in input['items'] as List)
        if ((item as Map)['kind'] == 'MAHR') item['id']?.toString(),
    };
    final costs = [
      for (final cost in input['costs'] as List)
        if (mahrItems.contains((cost as Map)['budgetCategoryId']?.toString()))
          cost,
    ];
    if (costs.isEmpty) return null;
    final costIds = {for (final cost in costs) cost['id']?.toString()};
    final pending = [
      for (final schedule in input['schedules'] as List)
        if ((schedule as Map)['status'] == 'PENDING' &&
            costIds.contains(schedule['weddingCostId']?.toString()))
          _summaryDay(schedule['dueDate']),
    ].whereType<String>().toList()..sort();
    return picture(
      MahrSide.pays,
      costs.fold<num>(
        0,
        (sum, cost) => sum + FinanceMoneyRules.value(cost['totalAmount']),
      ),
      costs.fold<num>(
        0,
        (sum, cost) => sum + FinanceMoneyRules.value(cost['paid']),
      ),
      pending.firstOrNull,
    );
  }
  if (persona == 'BRIDE') {
    final sources = [
      for (final source in input['sources'] as List)
        if ((source as Map)['kind'] == 'MAHR') source,
    ];
    if (sources.isNotEmpty) {
      final expected = [
        for (final source in sources)
          if (source['status'] == 'PLEDGED') _summaryDay(source['expectedAt']),
      ].whereType<String>().toList()..sort();
      return picture(
        MahrSide.receives,
        sources.fold<num>(
          0,
          (sum, source) => sum + FinanceMoneyRules.value(source['amount']),
        ),
        sources
            .where((source) => source['status'] != 'PLEDGED')
            .fold<num>(
              0,
              (sum, source) => sum + FinanceMoneyRules.value(source['amount']),
            ),
        expected.firstOrNull,
      );
    }
    final total = FinanceMoneyRules.value(draft?.mahrTotal);
    if (total <= 0) return null;
    final settled = FinanceMoneyRules.value(draft?.mahrSettled);
    return picture(
      MahrSide.receives,
      total,
      settled > total ? total : settled,
      draft?.mahrDueDate == null ? null : planDayToJson(draft!.mahrDueDate!),
    );
  }
  return null;
}

/// The plan as `localMoneyPlan` reads it: the server's fixtures' shape.
Map<String, dynamic> _localPlanInput({
  required String? persona,
  required String? totalBudget,
  required bool budgetIncludesMahr,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> costs,
  required Map<String, num> paidByCost,
  required Iterable<Map<String, dynamic>> payments,
  required List<Map<String, dynamic>> schedules,
  required List<Map<String, dynamic>> sources,
}) {
  final reversed = {
    for (final payment in payments)
      if (payment['entryType']?.toString() == 'REVERSAL')
        payment['reversalOfId']?.toString(),
  };
  final partlyPaid = <String, num>{};
  for (final payment in payments) {
    final scheduleId = payment['lowersScheduleId']?.toString();
    if (scheduleId == null ||
        payment['entryType']?.toString() == 'REVERSAL' ||
        payment['reversedById'] != null ||
        reversed.contains(payment['id']?.toString())) {
      continue;
    }
    partlyPaid[scheduleId] =
        (partlyPaid[scheduleId] ?? 0) +
        FinanceMoneyRules.value(payment['amount']);
  }
  return {
    'today': planDayToJson(sanaaToday()),
    'budget': totalBudget,
    // The groom pays the mahr; the bride's comes in (backend mahrSideOf).
    'mahrPays': persona == 'GROOM',
    // D114: read only where the owner pays the mahr.
    'budgetIncludesMahr': budgetIncludesMahr,
    'items': [
      for (final category in categories)
        {
          'id': category['id']?.toString(),
          'kind': category['kind']?.toString() == 'MAHR' ? 'MAHR' : 'WEDDING',
          'allocatedAmount': _nullableMoney(category['allocatedAmount']),
          'estimatedAmount': _nullableMoney(category['estimatedAmount']),
          'notNeeded': false,
        },
    ],
    'costs': [
      for (final cost in costs)
        {
          'id': cost['id']?.toString(),
          'budgetCategoryId': cost['budgetCategoryId']?.toString(),
          'title': cost['title']?.toString() ?? '',
          'totalAmount': cost['totalAmount']?.toString() ?? '0',
          'paid': FinanceMoneyRules.asMoney(
            paidByCost[cost['id']?.toString()] ?? 0,
          ),
          'payer': cost['payer'],
          'payerName': cost['payerName'],
          'ownerMoney': _ownerMoney(cost['payer']?.toString(), persona),
          'estimateCover': cost['estimateCover'],
          'estimatePart': cost['estimatePart'],
        },
    ],
    'schedules': [
      for (final schedule in schedules)
        {
          'id': schedule['id']?.toString(),
          'weddingCostId': schedule['costId']?.toString(),
          'amount': schedule['amount']?.toString() ?? '0',
          'dueDate': schedule['dueDate'],
          'status': schedule['status']?.toString() ?? 'PENDING',
          'note': schedule['note'],
          'remindAt': schedule['remindAt'],
          'rescheduledFrom': schedule['rescheduledFrom'],
          'partlyPaid': FinanceMoneyRules.asMoney(
            partlyPaid[schedule['id']?.toString()] ?? 0,
          ),
          'createdAt': schedule['createdAt']?.toString() ?? '',
        },
    ],
    'sources': [
      for (final source in sources)
        {
          'id': source['id']?.toString(),
          'kind': source['kind']?.toString(),
          'sourceName': source['sourceName']?.toString() ?? '',
          'contributorName': source['contributorName'],
          'amount': source['amount']?.toString() ?? '0',
          'status': source['status']?.toString() ?? 'RECEIVED',
          'expectedAt': source['expectedAt'],
          'repayments': source['repayments'] is List
              ? source['repayments']
              : const [],
        },
    ],
  };
}

/// The calendar day a stored date falls on in Sana'a, as YYYY-MM-DD.
String? _summaryDay(Object? value) {
  final day = planDayFromJson(
    value is DateTime ? value.toIso8601String() : value,
  );
  return day == null ? null : planDayToJson(day);
}

/// D59 (backend `paidFromOwnerMoney`): no payer, a shared agreement, or
/// the owner's own side pays from the owner's money.
bool _ownerMoney(String? payer, String? persona) {
  if (payer == null || payer.isEmpty || payer == 'SHARED') return true;
  return (payer == 'GROOM' && persona == 'GROOM') ||
      (payer == 'BRIDE' && persona == 'BRIDE');
}

/// The owner's money in for a plan kept on the phone, as the server's
/// funding reads it (`summarizeFunding`; D59, D103, D104). Null before a
/// source is recorded, as before.
MoneyFundingSummary? _localFunding(
  Map<String, dynamic> input,
  MoneyCoverage? coverage,
) {
  final sources = [
    for (final source in input['sources'] as List)
      Map<String, dynamic>.from(source as Map),
  ];
  if (sources.isEmpty) return null;
  final today = input['today'] as String;
  String? dayOf(Object? value) => _summaryDay(value);
  num received = 0, pledged = 0, loanTotal = 0, loanRepaid = 0;
  var overdueRepayments = 0, overduePledges = 0;
  for (final source in sources) {
    final amount = FinanceMoneyRules.value(source['amount']);
    final isReceived = source['status'] != 'PLEDGED';
    if (isReceived) {
      received += amount;
    } else {
      pledged += amount;
      final expected = dayOf(source['expectedAt']);
      if (expected != null && expected.compareTo(today) < 0) overduePledges++;
    }
    // G33: a promised loan is owed only once it arrived.
    if (source['kind'] != 'LOAN' || !isReceived) continue;
    loanTotal += amount;
    for (final raw in source['repayments'] as List? ?? const []) {
      if (raw is! Map) continue;
      if (raw['status'] == 'PAID') {
        loanRepaid += FinanceMoneyRules.value(raw['amount']);
      } else if (raw['status'] == 'PLANNED') {
        final due = dayOf(raw['dueDate']);
        if (due != null && due.compareTo(today) < 0) overdueRepayments++;
      }
    }
  }
  final spent = [
    for (final cost in input['costs'] as List)
      if ((cost as Map)['ownerMoney'] == true)
        FinanceMoneyRules.value(cost['paid']),
  ].fold<num>(0, (sum, paid) => sum + paid);
  final inHand = received - spent - loanRepaid;
  return MoneyFundingSummary(
    total: FinanceMoneyRules.asMoney(received + pledged) ?? '0',
    received: FinanceMoneyRules.asMoney(received) ?? '0',
    pledged: FinanceMoneyRules.asMoney(pledged) ?? '0',
    spent: FinanceMoneyRules.asMoney(spent) ?? '0',
    availableCash: FinanceMoneyRules.asMoney(inHand > 0 ? inHand : 0) ?? '0',
    shortfall: coverage?.shortfall?.amount,
    loanTotal: FinanceMoneyRules.asMoney(loanTotal) ?? '0',
    loanRepaid: FinanceMoneyRules.asMoney(loanRepaid) ?? '0',
    loanOutstanding: FinanceMoneyRules.asMoney(loanTotal - loanRepaid) ?? '0',
    overdueLoanRepayments: overdueRepayments,
    overduePledges: overduePledges,
    sourcesCount: sources.length,
  );
}
