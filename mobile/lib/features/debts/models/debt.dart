class Debt {
  const Debt({
    required this.id,
    required this.weddingPlanId,
    required this.creditorName,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.creditorPhone,
    this.dueDate,
    this.note,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      creditorName: json['creditorName'].toString(),
      creditorPhone: json['creditorPhone']?.toString(),
      title: json['title'].toString(),
      totalAmount: json['totalAmount'].toString(),
      paidAmount: json['paidAmount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'OPEN',
      note: json['note']?.toString(),
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String creditorName;
  final String? creditorPhone;
  final String title;
  final String totalAmount;
  final String paidAmount;
  final DateTime? dueDate;
  final String status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasNote => note != null && note!.trim().isNotEmpty;

  String get remainingAmount {
    final total = num.tryParse(totalAmount) ?? 0;
    final paid = num.tryParse(paidAmount) ?? 0;
    final remaining = total - paid;
    return remaining < 0 ? '0' : remaining.toStringAsFixed(2);
  }
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
