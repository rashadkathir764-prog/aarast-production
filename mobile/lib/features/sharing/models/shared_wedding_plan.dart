import 'shared_member.dart';

class SharedWeddingPlan {
  const SharedWeddingPlan({
    required this.id,
    required this.title,
    required this.currency,
    required this.status,
    required this.sharedMember,
    this.city,
    this.weddingDate,
  });

  factory SharedWeddingPlan.fromJson(Map<String, dynamic> json) {
    return SharedWeddingPlan(
      id: json['id'].toString(),
      title: json['title'].toString(),
      city: json['city']?.toString(),
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      currency: json['currency']?.toString() ?? 'YER',
      status: json['status']?.toString() ?? 'PLANNING',
      sharedMember: SharedMember.fromJson(
        Map<String, dynamic>.from(json['sharedMember'] as Map),
      ),
    );
  }

  final String id;
  final String title;
  final String? city;
  final DateTime? weddingDate;
  final String currency;
  final String status;
  final SharedMember sharedMember;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
