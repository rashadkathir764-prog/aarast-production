class Expense {
  const Expense({
    required this.id,
    required this.weddingPlanId,
    required this.title,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.budgetCategoryId,
    this.expenseDate,
    this.note,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      budgetCategoryId: json['budgetCategoryId']?.toString(),
      title: json['title'].toString(),
      amount: json['amount'].toString(),
      status: json['status']?.toString() ?? 'PLANNED',
      expenseDate: _dateTimeOrNull(json['expenseDate']),
      note: json['note']?.toString(),
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String? budgetCategoryId;
  final String title;
  final String amount;
  final String status;
  final DateTime? expenseDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasNote => note != null && note!.trim().isNotEmpty;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

DateTime _dateTimeOrNow(Object? value) {
  return _dateTimeOrNull(value) ?? DateTime.now();
}
