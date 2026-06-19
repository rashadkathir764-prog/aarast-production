import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class SuggestedCategoriesScreen extends StatelessWidget {
  const SuggestedCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'تصنيفات بداية الخطة',
      description: 'اختر تصنيفات أولية حتى لا تبدأ صفحة المال فارغة لاحقًا.',
      continueLabel: 'إنشاء ملخص محلي',
      child: GuestOnboardingCard(
        child: GuestOnboardingChipList(
          labels: [
            'القاعة',
            'العشاء',
            'التصوير',
            'الكوشة',
            'الفستان',
            'الذهب',
            'الضيافة',
            'الطوارئ',
          ],
        ),
      ),
    );
  }
}
