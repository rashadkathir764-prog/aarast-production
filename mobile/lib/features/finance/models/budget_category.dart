class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.weddingPlanId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.targetAmount,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      name: json['name'].toString(),
      targetAmount: json['targetAmount']?.toString(),
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String name;
  final String? targetAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasTargetAmount =>
      targetAmount != null && targetAmount!.trim().isNotEmpty;
}

DateTime _dateTimeOrNow(Object? value) {
  if (value == null) {
    return DateTime.now();
  }
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}
