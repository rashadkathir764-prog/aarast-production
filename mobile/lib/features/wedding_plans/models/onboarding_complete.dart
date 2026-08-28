import '../../../core/session/safe_user.dart';
import '../../finance/models/budget_category.dart';
import 'active_wedding_plan.dart';

class OnboardingCompleteRequest {
  const OnboardingCompleteRequest({
    this.path,
    this.persona,
    this.title,
    this.city,
    this.location,
    this.weddingDate,
    this.priorities = const [],
    this.estimatedBudget,
    this.currency,
    this.selectedCategories = const [],
  });

  final String? path;
  final String? persona;
  final String? title;
  final String? city;
  final Map<String, dynamic>? location;
  final String? weddingDate;
  final List<String> priorities;
  final String? estimatedBudget;
  final String? currency;
  final List<String> selectedCategories;

  Map<String, dynamic> toJson() {
    return {
      if (_hasText(path)) 'path': path!.trim(),
      if (_hasText(persona)) 'persona': persona!.trim(),
      if (_hasText(title)) 'title': title!.trim(),
      if (_hasText(city)) 'city': city!.trim(),
      if (location != null && location!.isNotEmpty) 'location': location,
      if (_hasText(weddingDate)) 'weddingDate': weddingDate!.trim(),
      if (priorities.isNotEmpty) 'priorities': priorities,
      if (_hasText(estimatedBudget)) 'estimatedBudget': estimatedBudget!.trim(),
      if (_hasText(currency)) 'currency': currency!.trim(),
      if (selectedCategories.isNotEmpty)
        'selectedCategories': selectedCategories,
    };
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class OnboardingCompleteResponse {
  const OnboardingCompleteResponse({
    required this.user,
    required this.activeWeddingPlan,
    required this.budgetCategories,
  });

  factory OnboardingCompleteResponse.fromJson(Map<String, dynamic> json) {
    return OnboardingCompleteResponse(
      user: SafeUser.fromJson(_mapOrEmpty(json['user'])),
      activeWeddingPlan: ActiveWeddingPlan.fromJson(
        _mapOrEmpty(json['activeWeddingPlan']),
      ),
      budgetCategories: _listOfMaps(
        json['budgetCategories'],
      ).map(BudgetCategory.fromJson).toList(growable: false),
    );
  }

  final SafeUser user;
  final ActiveWeddingPlan activeWeddingPlan;
  final List<BudgetCategory> budgetCategories;

  String get activePlanId => activeWeddingPlan.id;

  static Map<String, dynamic> _mapOrEmpty(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
