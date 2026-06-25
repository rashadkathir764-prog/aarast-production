import 'guest_onboarding_draft.dart';
import 'persona_copy.dart';

class GeneratedDashboardSeed {
  const GeneratedDashboardSeed({
    required this.title,
    required this.cityLabel,
    required this.shortLocationLabel,
    required this.mediumLocationLabel,
    required this.fullLocationLabel,
    required this.weddingDateLabel,
    required this.estimatedBudgetLabel,
    required this.selectedPriorities,
    required this.selectedCategories,
    required this.nextBestAction,
  });

  final String title;
  final String cityLabel;
  final String shortLocationLabel;
  final String mediumLocationLabel;
  final String fullLocationLabel;
  final String weddingDateLabel;
  final String estimatedBudgetLabel;
  final List<String> selectedPriorities;
  final List<String> selectedCategories;
  final String nextBestAction;

  factory GeneratedDashboardSeed.fromDraft(GuestOnboardingDraft draft) {
    final location = draft.weddingLocation;
    final shortLocationLabel = location.shortLabel ?? 'لم يحدد الموقع';
    final mediumLocationLabel = location.mediumLabel ?? shortLocationLabel;
    final fullLocationLabel = location.fullLabel ?? mediumLocationLabel;
    final cityLabel = mediumLocationLabel;
    final hasBudget = _hasText(draft.estimatedBudget);
    final hasCategories = draft.selectedCategoryKeys.isNotEmpty;
    final copy = personaCopyForGuest(draft.persona);

    return GeneratedDashboardSeed(
      title: shortLocationLabel == 'لم يحدد الموقع'
          ? 'خطة زفاف محلية'
          : 'خطة زفاف $shortLocationLabel',
      cityLabel: cityLabel,
      shortLocationLabel: shortLocationLabel,
      mediumLocationLabel: mediumLocationLabel,
      fullLocationLabel: fullLocationLabel,
      weddingDateLabel: _weddingDateLabel(draft),
      estimatedBudgetLabel: hasBudget
          ? '${draft.estimatedBudget} ${draft.currency ?? 'YER'}'
          : 'لم تحدد الميزانية بعد',
      selectedPriorities: List.unmodifiable(draft.priorities),
      selectedCategories: List.unmodifiable(draft.selectedCategoryKeys),
      nextBestAction: _nextBestAction(
        copy: copy,
        hasBudget: hasBudget,
        hasKnownWeddingDate: draft.weddingDate != null,
        hasCategories: hasCategories,
      ),
    );
  }

  static String _nextBestAction({
    required AarastPersonaCopy copy,
    required bool hasBudget,
    required bool hasKnownWeddingDate,
    required bool hasCategories,
  }) {
    if (!hasBudget) return copy.nextBudgetAction;
    if (!hasKnownWeddingDate) return copy.nextDateAction;
    if (hasCategories) return copy.nextCategoriesAction;
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

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
