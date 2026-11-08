part of 'finance_local_data_source.dart';

/// The money picture of a plan kept on the phone: the ledger's sums, and
/// the money tab's answers worked out as the server works them out
/// (finance_local_money_plan.dart, held to the server's by its fixtures).
/// An account plan never comes here: it reads the server's (C2).
extension _LocalMoneySummary on FinanceLocalDataSource {
  Future<MoneySummary> _localMoneySummary(
    String planId, {
    String? estimatedBudget,
    String? currency,
    MoneyFundingSummary? funding,
    String? persona,
  }) async {
    final budget = await readBudget(planId);
    final totalBudget = _nullableMoney(
      budget?['totalBudget'] ?? estimatedBudget,
    );
    final resolvedCurrency =
        stringOrNull(budget?['currency']) ??
        stringOrNull(currency)?.toUpperCase() ??
        'YER';
    final rawCategories = await _readPlanList(
      OfflineTables.cachedBudgetCategories,
      planId,
    );
    final costs = (await _readPlanList(
      OfflineTables.cachedCosts,
      planId,
    )).where((cost) => cost['status']?.toString() != 'CANCELLED').toList();
    final activeCostIds = costs
        .map((cost) => cost['id']?.toString())
        .whereType<String>()
        .toSet();
    final payments =
        (await _readPlanList(OfflineTables.cachedCostPayments, planId)).where(
          (payment) => activeCostIds.contains(payment['costId']?.toString()),
        );
    final schedules =
        (await _readPlanList(OfflineTables.cachedPaymentSchedules, planId))
            .where(
              (schedule) =>
                  activeCostIds.contains(schedule['costId']?.toString()),
            )
            .toList();

    final total = FinanceMoneyRules.value(totalBudget);
    final allocated = rawCategories.fold<num>(
      0,
      (sum, category) =>
          sum + FinanceMoneyRules.value(category['allocatedAmount']),
    );
    final costTotal = costs.fold<num>(
      0,
      (sum, cost) => sum + FinanceMoneyRules.value(cost['totalAmount']),
    );
    final paidByCost = localNetPaidByCost(payments);
    final paidTotal = costs.fold<num>(
      0,
      (sum, cost) => sum + (paidByCost[cost['id']?.toString()] ?? 0),
    );
    final outstanding = (costTotal - paidTotal).clamp(0, costTotal);
    // D102-D109: the money tab's answers, as the server composes them
    // (finance_local_money_plan.dart, held to the server's by its fixtures).
    final planInput = await _planInput(
        planId,
        persona: persona,
        totalBudget: totalBudget,
        categories: rawCategories,
        costs: costs,
        paidByCost: paidByCost,
        payments: payments,
        schedules: schedules,
    );
    final plan = localMoneyPlan(planInput);
    final planItems = {
      for (final item in plan['items'] as List)
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

    final scheduleSummary = LocalPaymentScheduleSummary.from(
      schedules,
      _today(),
    );


    final expected = MoneyExpected.fromJson(
      Map<String, dynamic>.from(plan['expected'] as Map),
    );
    final coverage = MoneyCoverage.fromJson(plan['coverage']);
    final warnings = <MoneyWarning>[
      // D105: by the expected cost (agreements and the estimates they have
      // not settled), as the server warns.
      if (totalBudget != null &&
          FinanceMoneyRules.value(expected.budgetLeft) < 0)
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
      if (coverage?.withPledges.deepest case final short?)
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

    return MoneySummary(
      planId: planId,
      currency: resolvedCurrency,
      budget: MoneyBudgetSummary(
        total: totalBudget,
        allocated: FinanceMoneyRules.asMoney(allocated) ?? '0',
        unallocated: totalBudget == null
            ? null
            : FinanceMoneyRules.asMoney(total - allocated),
        confirmedCost: FinanceMoneyRules.asMoney(costTotal) ?? '0',
        remaining: totalBudget == null
            ? null
            : FinanceMoneyRules.asMoney(total - costTotal),
      ),
      costs: MoneyCostsSummary(
        total: FinanceMoneyRules.asMoney(costTotal) ?? '0',
        paid: FinanceMoneyRules.asMoney(paidTotal) ?? '0',
        outstanding: FinanceMoneyRules.asMoney(outstanding) ?? '0',
        count: costs.length,
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
      expected: expected,
      outstanding: MoneyOutstanding.fromJson(
        Map<String, dynamic>.from(plan['outstanding'] as Map),
      ),
      obligations: [
        for (final line in plan['obligations'] as List)
          ?MoneyObligation.fromJson(Map<String, dynamic>.from(line as Map)),
      ],
      duesByMonth: MoneyDuesByMonth.fromJson(
        Map<String, dynamic>.from(plan['duesByMonth'] as Map),
      ),
      coverage: coverage,
      family: plan['family'] is List
          ? [
              for (final person in plan['family'] as List)
                MoneyContributor.fromJson(Map<String, dynamic>.from(person as Map)),
            ]
          : null,
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
    );
  }

  /// The plan as `localMoneyPlan` reads it: the server's fixtures' shape.
  Future<Map<String, dynamic>> _planInput(
    String planId, {
    required String? persona,
    required String? totalBudget,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> costs,
    required Map<String, num> paidByCost,
    required Iterable<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> schedules,
  }) async {
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
    final sources = await _readPlanList(
      OfflineTables.cachedFundingSources,
      planId,
    );
    return {
      'today': planDayToJson(sanaaToday()),
      'budget': totalBudget,
      // The groom pays the mahr; the bride's comes in (backend mahrSideOf).
      'mahrPays': persona == 'GROOM',
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
    String? dayOf(Object? value) => _dayOf(value);
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
      shortfall: coverage?.withPledges.deepest?.amount,
      loanTotal: FinanceMoneyRules.asMoney(loanTotal) ?? '0',
      loanRepaid: FinanceMoneyRules.asMoney(loanRepaid) ?? '0',
      loanOutstanding: FinanceMoneyRules.asMoney(loanTotal - loanRepaid) ?? '0',
      overdueLoanRepayments: overdueRepayments,
      overduePledges: overduePledges,
      sourcesCount: sources.length,
    );
  }
}
