class MoneySummary {
  const MoneySummary({
    required this.weddingPlanId,
    this.currency = 'YER',
    this.totalBudget,
    this.totalSpent,
    this.remainingBudget,
    this.confirmedCostTotal,
    this.paidTotal,
    this.outstandingTotal,
    this.commitmentTotal,
    this.commitmentPaidTotal,
    this.commitmentRemainingTotal,
    this.providerCommitmentTotal,
    this.manualDebtCommitmentTotal,
    this.deficitOrSurplus,
    this.totalDebts,
    this.debtRemaining,
    this.paidInstallmentsCount,
    this.remainingInstallmentsCount,
    this.overdueInstallmentsCount,
    this.dueInstallmentsCount,
    this.financialInstallmentsCount,
    this.financialDueInstallmentsCount,
    this.financialOverdueInstallmentsCount,
    this.financialRemainingInstallmentsCount,
    this.nextInstallment,
    this.nextFinancialInstallment,
    this.categorySummaries = const [],
    this.financialWarnings = const [],
    this.categoriesCount,
    this.expensesCount,
    this.debtsCount,
    this.commitmentsCount,
    this.installmentsCount,
  });

  factory MoneySummary.empty(String weddingPlanId) {
    return MoneySummary(weddingPlanId: weddingPlanId);
  }

  factory MoneySummary.fromJson(Map<String, dynamic> json) {
    return MoneySummary(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'YER',
      totalBudget: _nullableString(json['totalBudget'] ?? json['budgetTotal']),
      totalSpent: _nullableString(json['totalSpent'] ?? json['spentTotal']),
      remainingBudget: _nullableString(json['remainingBudget']),
      confirmedCostTotal: _nullableString(
        json['confirmedCostTotal'] ?? json['totalConfirmedCost'],
      ),
      paidTotal: _nullableString(json['paidTotal']),
      outstandingTotal: _nullableString(json['outstandingTotal']),
      commitmentTotal: _nullableString(json['commitmentTotal']),
      commitmentPaidTotal: _nullableString(json['commitmentPaidTotal']),
      commitmentRemainingTotal: _nullableString(
        json['commitmentRemainingTotal'],
      ),
      providerCommitmentTotal: _nullableString(json['providerCommitmentTotal']),
      manualDebtCommitmentTotal: _nullableString(
        json['manualDebtCommitmentTotal'],
      ),
      deficitOrSurplus: _nullableString(json['deficitOrSurplus']),
      totalDebts: _nullableString(json['totalDebts'] ?? json['debtTotal']),
      debtRemaining: _nullableString(
        json['debtRemaining'] ?? json['unpaidDebtTotal'],
      ),
      paidInstallmentsCount: _intOrNull(json['paidInstallmentsCount']),
      remainingInstallmentsCount: _intOrNull(
        json['remainingInstallmentsCount'],
      ),
      overdueInstallmentsCount: _intOrNull(json['overdueInstallmentsCount']),
      dueInstallmentsCount: _intOrNull(json['dueInstallmentsCount']),
      financialInstallmentsCount: _intOrNull(
        json['financialInstallmentsCount'],
      ),
      financialDueInstallmentsCount: _intOrNull(
        json['financialDueInstallmentsCount'],
      ),
      financialOverdueInstallmentsCount: _intOrNull(
        json['financialOverdueInstallmentsCount'],
      ),
      financialRemainingInstallmentsCount: _intOrNull(
        json['financialRemainingInstallmentsCount'],
      ),
      nextInstallment: MoneyNextInstallment.fromJsonOrNull(
        json['nextInstallment'],
      ),
      nextFinancialInstallment: MoneyNextInstallment.fromJsonOrNull(
        json['nextFinancialInstallment'],
      ),
      categorySummaries: _listOfMaps(
        json['categorySummaries'],
      ).map(MoneyCategorySummary.fromJson).toList(),
      financialWarnings: _listOfMaps(
        json['financialWarnings'],
      ).map(MoneyFinancialWarning.fromJson).toList(),
      categoriesCount: _intOrNull(json['categoriesCount']),
      expensesCount: _intOrNull(json['expensesCount']),
      debtsCount: _intOrNull(json['debtsCount']),
      commitmentsCount: _intOrNull(json['commitmentsCount']),
      installmentsCount: _intOrNull(json['installmentsCount']),
    );
  }

  final String weddingPlanId;
  final String currency;
  final String? totalBudget;
  final String? totalSpent;
  final String? remainingBudget;
  final String? confirmedCostTotal;
  final String? paidTotal;
  final String? outstandingTotal;
  final String? commitmentTotal;
  final String? commitmentPaidTotal;
  final String? commitmentRemainingTotal;
  final String? providerCommitmentTotal;
  final String? manualDebtCommitmentTotal;
  final String? deficitOrSurplus;
  final String? totalDebts;
  final String? debtRemaining;
  final int? paidInstallmentsCount;
  final int? remainingInstallmentsCount;
  final int? overdueInstallmentsCount;
  final int? dueInstallmentsCount;
  final int? financialInstallmentsCount;
  final int? financialDueInstallmentsCount;
  final int? financialOverdueInstallmentsCount;
  final int? financialRemainingInstallmentsCount;
  final MoneyNextInstallment? nextInstallment;
  final MoneyNextInstallment? nextFinancialInstallment;
  final List<MoneyCategorySummary> categorySummaries;
  final List<MoneyFinancialWarning> financialWarnings;
  final int? categoriesCount;
  final int? expensesCount;
  final int? debtsCount;
  final int? commitmentsCount;
  final int? installmentsCount;

  bool get hasAnyData {
    return _moneyValue(totalBudget) > 0 ||
        _moneyValue(confirmedCostTotal) > 0 ||
        _moneyValue(outstandingTotal) > 0 ||
        _moneyValue(totalSpent) > 0 ||
        _moneyValue(totalDebts) > 0 ||
        categorySummaries.isNotEmpty ||
        financialWarnings.isNotEmpty ||
        nextInstallment != null ||
        nextFinancialInstallment != null;
  }

  double get spendingRatio {
    final budget = _moneyValue(totalBudget);
    if (budget <= 0) return 0;
    return (_moneyValue(totalSpent) / budget).clamp(0.0, 10.0);
  }

  double get commitmentRatio {
    final budget = _moneyValue(totalBudget);
    if (budget <= 0) return 0;
    return (_moneyValue(confirmedCostTotal) / budget).clamp(0.0, 10.0);
  }

  bool get hasUsableBudget => _moneyValue(totalBudget) > 0;

  bool get hasSpendingWithoutBudget {
    return !hasUsableBudget &&
        (_moneyValue(totalSpent) > 0 || _moneyValue(confirmedCostTotal) > 0);
  }

  bool get hasLegacyDebtData {
    return (debtsCount ?? 0) > 0 || nextInstallment != null;
  }

  String get budgetStatus {
    if (hasSpendingWithoutBudget) return 'OVER_BUDGET';
    if (commitmentRatio > 1 || spendingRatio > 1) return 'OVER_BUDGET';
    if (financialWarnings.any((warning) => warning.severity == 'DANGER')) {
      return 'DANGER';
    }
    if (commitmentRatio >= .85 ||
        spendingRatio >= .85 ||
        financialWarnings.any((warning) => warning.severity == 'WARNING')) {
      return 'WARNING';
    }
    return 'SAFE';
  }
}

class MoneyCategorySummary {
  const MoneyCategorySummary({
    required this.categoryId,
    required this.name,
    this.allocated,
    this.spent,
    this.confirmedCost,
    this.paid,
    this.outstanding,
    this.budgetRemaining,
    this.remaining,
    this.expensesCount,
    this.commitmentsCount,
    this.installmentsCount,
    this.overBudget,
  });

  factory MoneyCategorySummary.fromJson(Map<String, dynamic> json) {
    return MoneyCategorySummary(
      categoryId:
          json['categoryId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      allocated: _nullableString(json['allocated'] ?? json['targetAmount']),
      spent: _nullableString(json['spent']),
      confirmedCost: _nullableString(json['confirmedCost']),
      paid: _nullableString(json['paid']),
      outstanding: _nullableString(json['outstanding']),
      budgetRemaining: _nullableString(json['budgetRemaining']),
      remaining: _nullableString(json['remaining']),
      expensesCount: _intOrNull(json['expensesCount']),
      commitmentsCount: _intOrNull(json['commitmentsCount']),
      installmentsCount: _intOrNull(json['installmentsCount']),
      overBudget: json['overBudget'] is bool
          ? json['overBudget'] as bool
          : null,
    );
  }

  final String categoryId;
  final String name;
  final String? allocated;
  final String? spent;
  final String? confirmedCost;
  final String? paid;
  final String? outstanding;
  final String? budgetRemaining;
  final String? remaining;
  final int? expensesCount;
  final int? commitmentsCount;
  final int? installmentsCount;
  final bool? overBudget;

  double get percentUsed {
    final allocatedValue = _moneyValue(allocated);
    if (allocatedValue <= 0) return 0;
    return (_moneyValue(confirmedCost ?? spent) / allocatedValue).clamp(
      0.0,
      10.0,
    );
  }
}

class MoneyNextInstallment {
  const MoneyNextInstallment({
    required this.id,
    required this.debtId,
    required this.amount,
    this.financialCommitmentId,
    this.dueAt,
    this.status,
    this.debtTitle,
    this.creditorName,
  });

  factory MoneyNextInstallment.fromJson(Map<String, dynamic> json) {
    return MoneyNextInstallment(
      id: json['id']?.toString() ?? '',
      debtId: json['debtId']?.toString() ?? '',
      financialCommitmentId: json['financialCommitmentId']?.toString(),
      amount: json['amount']?.toString() ?? '0',
      dueAt: _dateTimeOrNull(json['dueAt'] ?? json['dueDate']),
      status: json['status']?.toString(),
      debtTitle: json['debtTitle']?.toString() ?? json['title']?.toString(),
      creditorName: json['creditorName']?.toString(),
    );
  }

  static MoneyNextInstallment? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    return MoneyNextInstallment.fromJson(Map<String, dynamic>.from(value));
  }

  final String id;
  final String debtId;
  final String? financialCommitmentId;
  final String amount;
  final DateTime? dueAt;
  final String? status;
  final String? debtTitle;
  final String? creditorName;

  bool get isPaid => status == 'PAID';
}

class MoneyFinancialWarning {
  const MoneyFinancialWarning({
    required this.type,
    required this.severity,
    required this.message,
    this.count,
    this.amount,
  });

  factory MoneyFinancialWarning.fromJson(Map<String, dynamic> json) {
    return MoneyFinancialWarning(
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'WARNING',
      message: json['message']?.toString() ?? '',
      count: _intOrNull(json['count']),
      amount: _nullableString(json['amount']),
    );
  }

  final String type;
  final String severity;
  final String message;
  final int? count;
  final String? amount;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

double _moneyValue(String? value) {
  return double.tryParse(value?.replaceAll(',', '').trim() ?? '') ?? 0;
}
