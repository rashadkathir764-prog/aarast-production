class Installment {
  const Installment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.paidAt,
    this.note,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: json['id'].toString(),
      debtId: json['debtId'].toString(),
      amount: json['amount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      paidAt: _dateTimeOrNull(json['paidAt']),
      status: json['status']?.toString() ?? 'PENDING',
      note: json['note']?.toString(),
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String debtId;
  final String amount;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String status;
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
