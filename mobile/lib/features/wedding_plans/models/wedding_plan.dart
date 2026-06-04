class WeddingPlan {
  const WeddingPlan({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.city,
    this.weddingDate,
    this.estimatedBudget,
  });

  factory WeddingPlan.fromJson(Map<String, dynamic> json) {
    return WeddingPlan(
      id: json['id'].toString(),
      ownerUserId: json['ownerUserId'].toString(),
      title: json['title'].toString(),
      city: json['city']?.toString(),
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      estimatedBudget: json['estimatedBudget']?.toString(),
      currency: json['currency']?.toString() ?? 'YER',
      status: json['status']?.toString() ?? 'PLANNING',
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String ownerUserId;
  final String title;
  final String? city;
  final DateTime? weddingDate;
  final String? estimatedBudget;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasBudget =>
      estimatedBudget != null && estimatedBudget!.trim().isNotEmpty;

  int? get daysRemaining {
    if (weddingDate == null) {
      return null;
    }
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final weddingDay = DateTime(
      weddingDate!.year,
      weddingDate!.month,
      weddingDate!.day,
    );
    return weddingDay.difference(currentDate).inDays;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
