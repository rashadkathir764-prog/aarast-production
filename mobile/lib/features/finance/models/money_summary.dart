class MoneySummary {
  const MoneySummary({
    required this.weddingPlanId,
    this.currency = 'YER',
    this.totalBudget,
    this.totalSpent,
    this.remainingBudget,
    this.totalDebts,
    this.debtRemaining,
    this.paidInstallmentsCount,
    this.remainingInstallmentsCount,
    this.overdueInstallmentsCount,
    this.dueInstallmentsCount,
    this.nextInstallment,
    this.categorySummaries = const [],
    this.financialWarnings = const [],
    this.categoriesCount,
    this.expensesCount,
    this.debtsCount,
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
      nextInstallment: MoneyNextInstallment.fromJsonOrNull(
        json['nextInstallment'],
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
      installmentsCount: _intOrNull(json['installmentsCount']),
    );
  }

  final String weddingPlanId;
  final String currency;
  final String? totalBudget;
  final String? totalSpent;
  final String? remainingBudget;
  final String? totalDebts;
  final String? debtRemaining;
  final int? paidInstallmentsCount;
  final int? remainingInstallmentsCount;
  final int? overdueInstallmentsCount;
  final int? dueInstallmentsCount;
  final MoneyNextInstallment? nextInstallment;
  final List<MoneyCategorySummary> categorySummaries;
  final List<MoneyFinancialWarning> financialWarnings;
  final int? categoriesCount;
  final int? expensesCount;
  final int? debtsCount;
  final int? installmentsCount;

  bool get hasAnyData {
    return _moneyValue(totalBudget) > 0 ||
        _moneyValue(totalSpent) > 0 ||
        _moneyValue(totalDebts) > 0 ||
        categorySummaries.isNotEmpty ||
        financialWarnings.isNotEmpty ||
        nextInstallment != null;
  }

  double get spendingRatio {
    final budget = _moneyValue(totalBudget);
    if (budget <= 0) return 0;
    return (_moneyValue(totalSpent) / budget).clamp(0.0, 10.0);
  }

  bool get hasUsableBudget => _moneyValue(totalBudget) > 0;

  bool get hasSpendingWithoutBudget {
    return !hasUsableBudget && _moneyValue(totalSpent) > 0;
  }

  String get budgetStatus {
    if (hasSpendingWithoutBudget) return 'OVER_BUDGET';
    if (spendingRatio > 1) return 'OVER_BUDGET';
    if (financialWarnings.any((warning) => warning.severity == 'DANGER')) {
      return 'DANGER';
    }
    if (spendingRatio >= .85 ||
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
    this.remaining,
    this.expensesCount,
    this.overBudget,
  });

  factory MoneyCategorySummary.fromJson(Map<String, dynamic> json) {
    return MoneyCategorySummary(
      categoryId:
          json['categoryId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      allocated: _nullableString(json['allocated'] ?? json['targetAmount']),
      spent: _nullableString(json['spent']),
      remaining: _nullableString(json['remaining']),
      expensesCount: _intOrNull(json['expensesCount']),
      overBudget: json['overBudget'] is bool
          ? json['overBudget'] as bool
          : null,
    );
  }

  final String categoryId;
  final String name;
  final String? allocated;
  final String? spent;
  final String? remaining;
  final int? expensesCount;
  final bool? overBudget;

  double get percentUsed {
    final allocatedValue = _moneyValue(allocated);
    if (allocatedValue <= 0) return 0;
    return (_moneyValue(spent) / allocatedValue).clamp(0.0, 10.0);
  }
}

class MoneyNextInstallment {
  const MoneyNextInstallment({
    required this.id,
    required this.debtId,
    required this.amount,
    this.dueAt,
    this.status,
    this.debtTitle,
    this.creditorName,
  });

  factory MoneyNextInstallment.fromJson(Map<String, dynamic> json) {
    return MoneyNextInstallment(
      id: json['id']?.toString() ?? '',
      debtId: json['debtId']?.toString() ?? '',
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
