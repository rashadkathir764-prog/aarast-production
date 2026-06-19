import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class SuggestedCategoriesScreen extends StatelessWidget {
  const SuggestedCategoriesScreen({
    this.selectedCategoryKeys = const [],
    this.onChanged,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final List<String> selectedCategoryKeys;
  final ValueChanged<List<String>>? onChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  static const defaultCategories = [
    'القاعة',
    'العشاء',
    'التصوير',
    'الكوشة',
    'الفستان',
    'الذهب',
    'الضيافة',
    'الطوارئ',
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = selectedCategoryKeys.isEmpty
        ? defaultCategories.take(4).toList(growable: false)
        : selectedCategoryKeys;

    return GuestOnboardingStepScaffold(
      title: 'تصنيفات بداية الخطة',
      description: 'اختر تصنيفات أولية حتى لا تبدأ صفحة المال فارغة لاحقًا.',
      continueLabel: 'إنشاء ملخص محلي',
      onContinue: onContinue,
      onBack: onBack,
      child: GuestOnboardingCard(
        child: GuestOnboardingChipList(
          labels: defaultCategories,
          selectedLabels: effectiveSelected,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
