import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class PrioritiesScreen extends StatelessWidget {
  const PrioritiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'ما أهم ما تريد ترتيبه؟',
      description: 'هذه الأولويات ستساعد لوحة البداية المحلية لاحقًا.',
      continueLabel: 'حفظ الأولويات',
      child: GuestOnboardingCard(
        child: GuestOnboardingChipList(
          labels: [
            'الميزانية',
            'المهام',
            'الضيوف',
            'الموردون',
            'المشاركة العائلية',
          ],
        ),
      ),
    );
  }
}
