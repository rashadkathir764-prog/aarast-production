import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class GeneratedDashboardPreviewScreen extends StatelessWidget {
  const GeneratedDashboardPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'ملخص محلي مؤقت',
      description:
          'هذه معاينة هيكلية وليست لوحة التحكم الحقيقية أو خطة محفوظة في الخادم.',
      continueLabel: 'إنهاء المعاينة',
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'الخطة المحلية',
            subtitle: 'ملخص أولي من الدور والموقع والتاريخ والتصنيفات.',
            icon: Icons.dashboard_customize_rounded,
            selected: true,
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'الخطوة التالية',
            subtitle:
                'سيتم تحديدها لاحقًا من بيانات المسار المحلي عند التفعيل.',
            icon: Icons.flag_rounded,
          ),
        ],
      ),
    );
  }
}
