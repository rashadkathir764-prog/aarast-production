class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.weddingPlanId,
    required this.name,
    this.clientId,
    this.allocatedAmount,
    this.confirmedCost = '0',
    this.paid = '0',
    this.outstanding = '0',
    this.remainingAllocation,
    this.costsCount = 0,
    this.createdAt,
    this.updatedAt,
    this.isMahr = false,
    this.estimatedAmount,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isMahr: json['kind']?.toString() == 'MAHR',
      clientId: json['clientId']?.toString(),
      allocatedAmount: json['allocatedAmount']?.toString(),
      estimatedAmount: json['estimatedAmount']?.toString(),
      confirmedCost: json['confirmedCost']?.toString() ?? '0',
      paid: json['paid']?.toString() ?? '0',
      outstanding: json['outstanding']?.toString() ?? '0',
      remainingAllocation: json['remainingAllocation']?.toString(),
      costsCount: _intOrZero(json['costsCount']),
      createdAt: _dateTimeOrNull(json['createdAt']),
      updatedAt: _dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String name;
  final String? clientId;

  /// A share of the general budget: optional, never above it.
  final String? allocatedAmount;

  /// D109: what the owner expects the item to cost («تقديرك»): free, may
  /// pass the budget, needs none.
  final String? estimatedAmount;
  final String confirmedCost;
  final String paid;
  final String outstanding;
  final String? remainingAllocation;
  final int costsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The groom's mahr item (a06): outside the wedding budget (C1), so it
  /// has no allocation and is never part of the budget's items.
  final bool isMahr;

  bool get hasAllocation =>
      allocatedAmount != null && allocatedAmount!.trim().isNotEmpty;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
