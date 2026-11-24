import '../../../core/utils/plan_day.dart';
import '../../onboarding/onboarding_api.dart' show WeddingLocationDraft;

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
    this.location,
    this.weddingDate,
    this.estimatedBudget,
    this.priorities = const [],
    this.onboardingPath,
    this.persona,
    this.budgetIncludesMahr = false,
    this.deletionScheduledFor,
  });

  factory WeddingPlan.fromJson(Map<String, dynamic> json) {
    return WeddingPlan(
      // D114: missing (an older server) or null (no money rights) is false.
      budgetIncludesMahr: json['budgetIncludesMahr'] == true,
      id: json['id'].toString(),
      ownerUserId: json['ownerUserId'].toString(),
      title: json['title'].toString(),
      city: json['city']?.toString(),
      location: _mapOrNull(json['location']),
      weddingDate: planDayFromJson(json['weddingDate']),
      estimatedBudget: json['estimatedBudget']?.toString(),
      priorities: _stringList(json['priorities']),
      onboardingPath: json['onboardingPath']?.toString(),
      persona: json['persona']?.toString(),
      currency: json['currency']?.toString() ?? 'YER',
      status: json['status']?.toString() ?? 'PLANNING',
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
      deletionScheduledFor: _dateTimeOrNull(json['deletionScheduledFor']),
    );
  }

  final String id;
  final String ownerUserId;
  final String title;
  final String? city;
  final Map<String, dynamic>? location;
  final DateTime? weddingDate;
  final String? estimatedBudget;

  /// D114: the groom counts the mahr inside [estimatedBudget]. False on a
  /// plan that receives the mahr, for a reader without money rights, and
  /// from a server before D114.
  final bool budgetIncludesMahr;
  final List<String> priorities;
  final String? onboardingPath;
  final String? persona;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Q-45 (D124): the owner asked to delete the plan; it is erased on this
  /// day unless he takes it back. Null for a plan that stays.
  final DateTime? deletionScheduledFor;

  bool get hasBudget =>
      estimatedBudget != null && estimatedBudget!.trim().isNotEmpty;

  int? get daysRemaining {
    if (weddingDate == null) {
      return null;
    }
    // D11: from today in Sana'a, as the server counts (RA-MO-20).
    return daysUntilPlanDay(weddingDate!);
  }

  WeddingLocationDraft get weddingLocation {
    return WeddingLocationDraft.fromJson(location, cityFallback: city);
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}

/// Whole days the wedding moved between two dates, or null when either is
/// missing or the day did not change (V1 checklist 4.13).
int? weddingDateShiftDays(DateTime? before, DateTime? after) {
  if (before == null || after == null) return null;
  final from = DateTime.utc(before.year, before.month, before.day);
  final to = DateTime.utc(after.year, after.month, after.day);
  final days = to.difference(from).inDays;
  return days == 0 ? null : days;
}
