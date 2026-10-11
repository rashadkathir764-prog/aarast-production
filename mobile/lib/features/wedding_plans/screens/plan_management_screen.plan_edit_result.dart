part of 'plan_management_screen.dart';

/// What the plan edit sheet returns. [currency] is only applied to a plan
/// kept on this device: a server plan's currency is fixed at creation, so the
/// server update payload never carries it.
class PlanEditResult {
  const PlanEditResult({
    required this.title,
    required this.weddingDate,
    required this.currency,
    required this.priorities,
    required this.location,
  });

  final String title;
  final DateTime? weddingDate;
  final String currency;
  final List<String> priorities;
  final WeddingLocationDraft? location;

  /// The body for `PATCH /api/v1/wedding-plans/:id` (UpdateWeddingPlanDto).
  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      if (weddingDate != null)
        'weddingDate': DateTime.utc(
          weddingDate!.year,
          weddingDate!.month,
          weddingDate!.day,
        ).toIso8601String(),
      'priorities': priorities,
      if (location != null) ...{
        'city': location!.cityOrDistrict,
        'location': location!.toJson(),
      },
    };
  }
}
