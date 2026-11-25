import '../../../core/experience_v3/aarast_v3.dart' show ReaderVoice;
import '../../../core/utils/arabic_date_formatter.dart';
import 'guest_onboarding_draft.dart';
import 'persona_copy.dart';

/// The place of a plan whose place was not given (Q-35 (أ): Sana'ani).
const _noPlace = 'المكان ما تحدد';

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
    final shortLocationLabel = location.shortLabel ?? _noPlace;
    final mediumLocationLabel = location.mediumLabel ?? shortLocationLabel;
    final fullLocationLabel = location.fullLabel ?? mediumLocationLabel;
    final cityLabel = mediumLocationLabel;
    final hasBudget = _hasText(draft.estimatedBudget);
    final hasCategories = draft.selectedCategoryKeys.isNotEmpty;
    final copy = personaCopyForGuest(draft.persona);
    final planName = draft.planName?.trim();

    return GeneratedDashboardSeed(
      title: planName != null && planName.isNotEmpty
          ? planName
          : shortLocationLabel == _noPlace
          ? 'خطة عرس على الجوال'
          : 'خطة عرس $shortLocationLabel',
      cityLabel: cityLabel,
      shortLocationLabel: shortLocationLabel,
      mediumLocationLabel: mediumLocationLabel,
      fullLocationLabel: fullLocationLabel,
      weddingDateLabel: _weddingDateLabel(draft),
      estimatedBudgetLabel: hasBudget
          ? '${draft.estimatedBudget} ${draft.currency ?? 'YER'}'
          : 'الميزانية ما تحددت بعد',
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
    return ReaderVoice.say('اختر بنود البداية', 'اختاري بنود البداية');
  }

  static String _weddingDateLabel(GuestOnboardingDraft draft) {
    if (draft.weddingDateUnknown) return 'الموعد ما ندريه الحين';
    final weddingDate = draft.weddingDate;
    if (weddingDate == null) return 'الموعد ما تحدد بعد';
    return formatArabicCompactDate(weddingDate);
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
