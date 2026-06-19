import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class LocationSetupScreen extends StatelessWidget {
  const LocationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'أين سيكون الزفاف؟',
      description: 'أدخل الموقع يدويًا. لا يتم طلب إذن الموقع في هذه المرحلة.',
      continueLabel: 'حفظ الموقع',
      child: Column(
        children: [
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'المحافظة'),
          ),
          SizedBox(height: 12),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'المدينة أو المديرية'),
          ),
          SizedBox(height: 12),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'الحي'),
          ),
          SizedBox(height: 12),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'الشارع'),
          ),
          SizedBox(height: 12),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'ملاحظة على العنوان'),
          ),
        ],
      ),
    );
  }
}
