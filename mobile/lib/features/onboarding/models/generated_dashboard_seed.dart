import 'guest_onboarding_draft.dart';

class GeneratedDashboardSeed {
  const GeneratedDashboardSeed({
    required this.title,
    required this.cityLabel,
    required this.weddingDateLabel,
    required this.estimatedBudgetLabel,
    required this.selectedPriorities,
    required this.selectedCategories,
    required this.nextBestAction,
  });

  final String title;
  final String cityLabel;
  final String weddingDateLabel;
  final String estimatedBudgetLabel;
  final List<String> selectedPriorities;
  final List<String> selectedCategories;
  final String nextBestAction;

  factory GeneratedDashboardSeed.fromDraft(GuestOnboardingDraft draft) {
    final cityLabel = _firstText([
      draft.city,
      draft.district,
      draft.governorate,
    ], fallback: 'لم يحدد الموقع');
    final hasBudget = _hasText(draft.estimatedBudget);
    final hasCategories = draft.selectedCategoryKeys.isNotEmpty;

    return GeneratedDashboardSeed(
      title: cityLabel == 'لم يحدد الموقع'
          ? 'خطة زفاف محلية'
          : 'خطة زفاف $cityLabel',
      cityLabel: cityLabel,
      weddingDateLabel: _weddingDateLabel(draft),
      estimatedBudgetLabel: hasBudget
          ? '${draft.estimatedBudget} ${draft.currency ?? 'YER'}'
          : 'لم تحدد الميزانية بعد',
      selectedPriorities: List.unmodifiable(draft.priorities),
      selectedCategories: List.unmodifiable(draft.selectedCategoryKeys),
      nextBestAction: _nextBestAction(
        hasBudget: hasBudget,
        hasKnownWeddingDate: draft.weddingDate != null,
        hasCategories: hasCategories,
      ),
    );
  }

  static String _nextBestAction({
    required bool hasBudget,
    required bool hasKnownWeddingDate,
    required bool hasCategories,
  }) {
    if (!hasBudget) return 'أضف ميزانية تقريبية';
    if (!hasKnownWeddingDate) return 'حدد تاريخ الزفاف';
    if (hasCategories) return 'راجع التصنيفات المقترحة';
    return 'اختر تصنيفات البداية';
  }

  static String _weddingDateLabel(GuestOnboardingDraft draft) {
    if (draft.weddingDateUnknown) return 'التاريخ غير معروف الآن';
    final weddingDate = draft.weddingDate;
    if (weddingDate == null) return 'لم يحدد التاريخ بعد';
    return '${weddingDate.year}/${_twoDigits(weddingDate.month)}/${_twoDigits(weddingDate.day)}';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String _firstText(List<String?> values, {required String fallback}) {
    for (final value in values) {
      if (_hasText(value)) return value!.trim();
    }
    return fallback;
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
