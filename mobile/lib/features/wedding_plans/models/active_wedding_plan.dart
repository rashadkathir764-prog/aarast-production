import 'wedding_plan.dart';
import '../../onboarding/models/wedding_location_draft.dart';

class ActiveWeddingPlan {
  const ActiveWeddingPlan({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.city,
    this.location,
    this.weddingDate,
    this.priorities = const [],
    this.estimatedBudget,
    this.onboardingPath,
    this.persona,
    this.onboardingCompletedAt,
  });

  factory ActiveWeddingPlan.fromJson(Map<String, dynamic> json) {
    return ActiveWeddingPlan(
      id: json['id'].toString(),
      ownerUserId: json['ownerUserId'].toString(),
      title: json['title'].toString(),
      city: json['city']?.toString(),
      location: _mapOrNull(json['location']),
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      priorities: _stringList(json['priorities']),
      estimatedBudget: json['estimatedBudget']?.toString(),
      currency: json['currency']?.toString() ?? 'YER',
      onboardingPath: json['onboardingPath']?.toString(),
      persona: json['persona']?.toString(),
      onboardingCompletedAt: _dateTimeOrNull(json['onboardingCompletedAt']),
      status: json['status']?.toString() ?? 'PLANNING',
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String ownerUserId;
  final String title;
  final String? city;
  final Map<String, dynamic>? location;
  final DateTime? weddingDate;
  final List<String> priorities;
  final String? estimatedBudget;
  final String currency;
  final String? onboardingPath;
  final String? persona;
  final DateTime? onboardingCompletedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get cityLabel {
    return weddingLocation.shortLabel ?? 'غير محدد';
  }

  WeddingLocationDraft get weddingLocation {
    return WeddingLocationDraft.fromJson(location, cityFallback: city);
  }

  WeddingPlan toWeddingPlan() {
    return WeddingPlan(
      id: id,
      ownerUserId: ownerUserId,
      title: title,
      city: city,
      location: location,
      weddingDate: weddingDate,
      estimatedBudget: estimatedBudget,
      currency: currency,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
