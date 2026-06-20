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
      stepNumber: 7,
      title: 'تصنيفات بداية الخطة',
      description: 'اختر تصنيفات أولية حتى لا تبدأ صفحة المال فارغة لاحقًا.',
      continueLabel: 'إنشاء ملخص محلي',
      onContinue: onContinue,
      onBack: onBack,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: defaultCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final value = defaultCategories[index];
          final selected = effectiveSelected.contains(value);
          return GuestOnboardingOptionTile(
            title: value,
            subtitle: selected ? 'مضافة للخطة' : 'اضغط للإضافة',
            icon: _categoryIcon(index),
            selected: selected,
            compact: true,
            onTap: () {
              final next = [...effectiveSelected];
              next.contains(value) ? next.remove(value) : next.add(value);
              onChanged?.call(List.unmodifiable(next));
            },
          );
        },
      ),
    );
  }

  static IconData _categoryIcon(int index) => switch (index) {
    0 => Icons.account_balance_outlined,
    1 => Icons.restaurant_outlined,
    2 => Icons.photo_camera_outlined,
    3 => Icons.chair_alt_outlined,
    4 => Icons.checkroom_outlined,
    5 => Icons.diamond_outlined,
    6 => Icons.room_service_outlined,
    _ => Icons.health_and_safety_outlined,
  };
}
