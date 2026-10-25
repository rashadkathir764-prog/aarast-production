import '../../../core/utils/plan_day.dart';
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
    this.funding,
    this.mahr,
    this.payers = const [],
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
      funding: json['funding'] is Map
          ? MoneyFundingSummary.fromJson(_map(json['funding']))
          : null,
      mahr: json['mahr'] is Map
          ? MoneyMahrSummary.fromJson(_map(json['mahr']))
          : null,
      payers: _listOfMaps(
        json['payers'],
      ).map(MoneyPayerSummary.fromJson).toList(),
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

  /// Money in versus money committed. Only the plan owner receives it.
  final MoneyFundingSummary? funding;

  /// The plan's mahr as the server reads it (a06, C1): the groom's agreement
  /// with the bride's family, or the bride's mahr coming in. Null before it
  /// is recorded, or for a reader who may not see it.
  final MoneyMahrSummary? mahr;

  /// G14: what each payer agreed to and paid, by each item's payer.
  final List<MoneyPayerSummary> payers;

  /// The groom's mahr item (outside the budget), if the plan has one.
  MoneyCategorySummary? get mahrCategory =>
      categories.where((category) => category.isMahr).firstOrNull;

  /// The wedding's own items: every item but the mahr's (C1).
  List<MoneyCategorySummary> get weddingCategories => [
    for (final category in categories)
      if (!category.isMahr) category,
  ];

  String get weddingPlanId => planId;
  bool get hasAnyData =>
      moneyValue(budget.total) > 0 ||
      moneyValue(costs.total) > 0 ||
      categories.isNotEmpty ||
      paymentSchedules.upcomingCount > 0 ||
      paymentSchedules.overdueCount > 0;
  bool get hasBudget => budget.total != null;

  /// Categories whose confirmed costs passed their allocation, from the
  /// server's CATEGORY_EXCEEDED warnings, with the overrun amount.
  List<({String name, String? overrun})> get exceededCategories => [
    for (final warning in warnings)
      if (warning.type == 'CATEGORY_EXCEEDED')
        (
          name: categories
                  .where((category) => category.categoryId == warning.categoryId)
                  .firstOrNull
                  ?.name ??
              'بند',
          overrun: warning.amount,
        ),
  ];

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

class MoneyFundingSummary {
  const MoneyFundingSummary({
    this.total = '0',
    this.received = '0',
    this.pledged = '0',
    this.availableCash = '0',
    this.shortfall,
    this.loanTotal = '0',
    this.loanOutstanding = '0',
    this.overdueLoanRepayments = 0,
    this.sourcesCount = 0,
  });

  factory MoneyFundingSummary.fromJson(Map<String, dynamic> json) {
    return MoneyFundingSummary(
      total: json['total']?.toString() ?? '0',
      received: json['received']?.toString() ?? '0',
      pledged: json['pledged']?.toString() ?? '0',
      availableCash: json['availableCash']?.toString() ?? '0',
      shortfall: _nullableString(json['shortfall']),
      loanTotal: json['loanTotal']?.toString() ?? '0',
      loanOutstanding: json['loanOutstanding']?.toString() ?? '0',
      overdueLoanRepayments:
          int.tryParse(json['overdueLoanRepayments']?.toString() ?? '') ?? 0,
      sourcesCount: int.tryParse(json['sourcesCount']?.toString() ?? '') ?? 0,
    );
  }

  /// Pledged plus received.
  final String total;
  final String received;
  final String pledged;

  /// Received minus what was already paid out.
  final String availableCash;

  /// Confirmed cost not yet covered by any source; null once covered.
  final String? shortfall;
  final String loanTotal;
  final String loanOutstanding;
  final int overdueLoanRepayments;
  final int sourcesCount;
}

/// The plan's mahr (a06, C1), one shape for both sides.
class MoneyMahrSummary {
  const MoneyMahrSummary({
    required this.side,
    required this.total,
    required this.settled,
    required this.remaining,
    this.nextDueAt,
    this.complete = false,
  });

  factory MoneyMahrSummary.fromJson(Map<String, dynamic> json) {
    return MoneyMahrSummary(
      side: json['side']?.toString() == 'RECEIVES'
          ? MahrSide.receives
          : MahrSide.pays,
      total: json['total']?.toString() ?? '0',
      settled: json['settled']?.toString() ?? '0',
      remaining: json['remaining']?.toString() ?? '0',
      // A day, read as the server keeps it (Sana'a).
      nextDueAt: planDayFromJson(json['nextDueAt']),
      complete: json['complete'] == true,
    );
  }

  /// The groom pays it to the bride's family; the bride receives it.
  final MahrSide side;
  final String total;

  /// Handed over (the groom) or received (the bride).
  final String settled;
  final String remaining;

  /// When the rest is due (the groom) or expected (the bride).
  final DateTime? nextDueAt;
  final bool complete;
}

enum MahrSide { pays, receives }

/// G14: one payer's agreements and payments («الوالد دفع 2.2 مليون»).
class MoneyPayerSummary {
  const MoneyPayerSummary({
    this.payer,
    this.payerName,
    this.agreed = '0',
    this.paid = '0',
    this.outstanding = '0',
    this.costsCount = 0,
  });

  factory MoneyPayerSummary.fromJson(Map<String, dynamic> json) {
    return MoneyPayerSummary(
      payer: _nullableString(json['payer']),
      payerName: _nullableString(json['payerName']),
      agreed: json['agreed']?.toString() ?? '0',
      paid: json['paid']?.toString() ?? '0',
      outstanding: json['outstanding']?.toString() ?? '0',
      costsCount: intOrNull(json['costsCount']) ?? 0,
    );
  }

  /// GROOM, BRIDE, FAMILY, SHARED, OTHER, or null when no payer was set.
  final String? payer;
  final String? payerName;
  final String agreed;
  final String paid;
  final String outstanding;
  final int costsCount;
}

class MoneyBudgetSummary {
  const MoneyBudgetSummary({
    this.total,
    this.allocated = '0',
    this.unallocated,
    this.confirmedCost = '0',
    this.paid = '0',
    this.remaining,
  });

  factory MoneyBudgetSummary.fromJson(Map<String, dynamic> json) {
    return MoneyBudgetSummary(
      total: _nullableString(json['total'] ?? json['amount']),
      allocated: json['allocated']?.toString() ?? '0',
      unallocated: _nullableString(json['unallocated']),
      confirmedCost: json['confirmedCost']?.toString() ?? '0',
      paid: json['paid']?.toString() ?? '0',
      remaining: _nullableString(json['remaining']),
    );
  }

  final String? total;
  final String allocated;
  final String? unallocated;

  /// The wedding's agreements: the mahr item is outside the budget (C1).
  final String confirmedCost;

  /// What was paid of the wedding's agreements (c01 «عرسك · دفعت»).
  final String paid;
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
    this.totalCount = 0,
    this.upcomingCount = 0,
    this.overdueCount = 0,
    this.paidCount = 0,
    this.next,
  });

  factory MoneySchedulesSummary.fromJson(Map<String, dynamic> json) {
    return MoneySchedulesSummary(
      totalCount: intOrNull(json['totalCount']) ?? 0,
      upcomingCount: intOrNull(json['upcomingCount']) ?? 0,
      overdueCount: intOrNull(json['overdueCount']) ?? 0,
      paidCount: intOrNull(json['paidCount']) ?? 0,
      next: json['next'] is Map
          ? PaymentSchedule.fromJson(
              Map<String, dynamic>.from(json['next'] as Map),
            )
          : null,
    );
  }

  final int totalCount;
  final int upcomingCount;
  final int overdueCount;
  final int paidCount;
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
    this.isMahr = false,
  });

  factory MoneyCategorySummary.fromJson(Map<String, dynamic> json) {
    return MoneyCategorySummary(
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isMahr: json['kind']?.toString() == 'MAHR',
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

  /// The groom's mahr item: outside the wedding budget (C1).
  final bool isMahr;
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
    this.canRecordPrivateCost = false,
  });

  factory MoneyPermissions.fromJson(Map<String, dynamic> json) {
    return MoneyPermissions(
      canViewMoney: json['canViewMoney'] == true,
      canManageMoney: json['canManageMoney'] == true,
      canRecordPrivateCost: json['canRecordPrivateCost'] == true,
    );
  }

  final bool canViewMoney;
  final bool canManageMoney;

  /// V1 checklist 4.10: the owner or the partner may record a cost that only
  /// they see.
  final bool canRecordPrivateCost;
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
