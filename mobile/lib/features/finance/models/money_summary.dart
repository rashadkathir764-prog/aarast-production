import 'wedding_cost.dart';

class MoneySummary {
  const MoneySummary({
    required this.planId,
    this.currency = 'YER',
    this.budget = const MoneyBudgetSummary(),
    this.costs = const MoneyCostsSummary(),
    this.paymentSchedules = const MoneySchedulesSummary(),
    this.categories = const [],
    this.warnings = const [],
    this.permissions = const MoneyPermissions(),
  });

  factory MoneySummary.empty(String planId, {String currency = 'YER'}) {
    return MoneySummary(planId: planId, currency: currency);
  }

  factory MoneySummary.fromJson(Map<String, dynamic> json) {
    return MoneySummary(
      planId:
          json['planId']?.toString() ?? json['weddingPlanId']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'YER',
      budget: MoneyBudgetSummary.fromJson(_map(json['budget'])),
      costs: MoneyCostsSummary.fromJson(_map(json['costs'])),
      paymentSchedules: MoneySchedulesSummary.fromJson(
        _map(json['paymentSchedules']),
      ),
      categories: _listOfMaps(
        json['categories'],
      ).map(MoneyCategorySummary.fromJson).toList(),
      warnings: _listOfMaps(
        json['warnings'],
      ).map(MoneyWarning.fromJson).toList(),
      permissions: MoneyPermissions.fromJson(_map(json['permissions'])),
    );
  }

  final String planId;
  final String currency;
  final MoneyBudgetSummary budget;
  final MoneyCostsSummary costs;
  final MoneySchedulesSummary paymentSchedules;
  final List<MoneyCategorySummary> categories;
  final List<MoneyWarning> warnings;
  final MoneyPermissions permissions;

  String get weddingPlanId => planId;
  bool get hasAnyData =>
      moneyValue(budget.total) > 0 ||
      moneyValue(costs.total) > 0 ||
      categories.isNotEmpty ||
      paymentSchedules.upcomingCount > 0 ||
      paymentSchedules.overdueCount > 0;
  bool get hasBudget => budget.total != null;
  double get confirmedRatio {
    final total = moneyValue(budget.total);
    if (total <= 0) return 0;
    return (moneyValue(budget.confirmedCost) / total).clamp(0.0, 10.0);
  }

  String get healthStatus {
    if (!hasBudget) return 'UNSET';
    if (moneyValue(budget.remaining) < 0) return 'OVER_BUDGET';
    if (warnings.any((warning) => warning.severity == 'DANGER')) {
      return 'DANGER';
    }
    if (confirmedRatio >= .85 ||
        warnings.any((warning) => warning.severity == 'WARNING')) {
      return 'WARNING';
    }
    return 'SAFE';
  }
}

class MoneyBudgetSummary {
  const MoneyBudgetSummary({
    this.total,
    this.allocated = '0',
    this.unallocated,
    this.confirmedCost = '0',
    this.remaining,
  });

  factory MoneyBudgetSummary.fromJson(Map<String, dynamic> json) {
    return MoneyBudgetSummary(
      total: _nullableString(json['total'] ?? json['amount']),
      allocated: json['allocated']?.toString() ?? '0',
      unallocated: _nullableString(json['unallocated']),
      confirmedCost: json['confirmedCost']?.toString() ?? '0',
      remaining: _nullableString(json['remaining']),
    );
  }

  final String? total;
  final String allocated;
  final String? unallocated;
  final String confirmedCost;
  final String? remaining;
}

class MoneyCostsSummary {
  const MoneyCostsSummary({
    this.total = '0',
    this.paid = '0',
    this.outstanding = '0',
    this.count = 0,
  });

  factory MoneyCostsSummary.fromJson(Map<String, dynamic> json) {
    return MoneyCostsSummary(
      total: json['total']?.toString() ?? '0',
      paid: json['paid']?.toString() ?? '0',
      outstanding: json['outstanding']?.toString() ?? '0',
      count: intOrNull(json['count']) ?? 0,
    );
  }

  final String total;
  final String paid;
  final String outstanding;
  final int count;
}

class MoneySchedulesSummary {
  const MoneySchedulesSummary({
    this.upcomingCount = 0,
    this.overdueCount = 0,
    this.next,
  });

  factory MoneySchedulesSummary.fromJson(Map<String, dynamic> json) {
    return MoneySchedulesSummary(
      upcomingCount: intOrNull(json['upcomingCount']) ?? 0,
      overdueCount: intOrNull(json['overdueCount']) ?? 0,
      next: json['next'] is Map
          ? PaymentSchedule.fromJson(
              Map<String, dynamic>.from(json['next'] as Map),
            )
          : null,
    );
  }

  final int upcomingCount;
  final int overdueCount;
  final PaymentSchedule? next;
}

class MoneyCategorySummary {
  const MoneyCategorySummary({
    required this.categoryId,
    required this.name,
    this.allocatedAmount,
    this.confirmedCost = '0',
    this.paid = '0',
    this.outstanding = '0',
    this.remainingAllocation,
    this.costsCount = 0,
  });

  factory MoneyCategorySummary.fromJson(Map<String, dynamic> json) {
    return MoneyCategorySummary(
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      allocatedAmount: _nullableString(json['allocatedAmount']),
      confirmedCost: json['confirmedCost']?.toString() ?? '0',
      paid: json['paid']?.toString() ?? '0',
      outstanding: json['outstanding']?.toString() ?? '0',
      remainingAllocation: _nullableString(json['remainingAllocation']),
      costsCount: intOrNull(json['costsCount']) ?? 0,
    );
  }

  final String categoryId;
  final String name;
  final String? allocatedAmount;
  final String confirmedCost;
  final String paid;
  final String outstanding;
  final String? remainingAllocation;
  final int costsCount;
}

class MoneyWarning {
  const MoneyWarning({
    required this.type,
    required this.severity,
    this.categoryId,
    this.amount,
    this.count,
    this.message,
  });

  factory MoneyWarning.fromJson(Map<String, dynamic> json) {
    return MoneyWarning(
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'WARNING',
      categoryId: _nullableString(json['categoryId']),
      amount: _nullableString(json['amount']),
      count: intOrNull(json['count']),
      message: _nullableString(json['message']),
    );
  }

  final String type;
  final String severity;
  final String? categoryId;
  final String? amount;
  final int? count;
  final String? message;
}

class MoneyPermissions {
  const MoneyPermissions({
    this.canViewMoney = false,
    this.canManageMoney = false,
  });

  factory MoneyPermissions.fromJson(Map<String, dynamic> json) {
    return MoneyPermissions(
      canViewMoney: json['canViewMoney'] == true,
      canManageMoney: json['canManageMoney'] == true,
    );
  }

  final bool canViewMoney;
  final bool canManageMoney;
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
