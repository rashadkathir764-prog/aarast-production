import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class ChoosePathScreen extends StatelessWidget {
  const ChoosePathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'كيف تريد استخدام أعرست؟',
      description:
          'اختر المسار المناسب حتى تبقى تجربة التخطيط منفصلة عن مسار المزودين.',
      continueLabel: 'متابعة',
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'أريد تنظيم زفافي',
            subtitle: 'مسار تخطيط الزفاف والميزانية والمهام والضيوف.',
            icon: Icons.favorite_rounded,
            selected: true,
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'أنا مزود خدمة',
            subtitle: 'مسار منفصل لاحقًا لملف المزود وطلبات العروض.',
            icon: Icons.storefront_rounded,
          ),
        ],
      ),
    );
  }
}
