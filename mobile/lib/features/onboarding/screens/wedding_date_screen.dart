import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class WeddingDateScreen extends StatelessWidget {
  const WeddingDateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'متى موعد الزفاف؟',
      description: 'يمكنك اختيار تاريخ تقريبي أو المتابعة بدون تاريخ الآن.',
      continueLabel: 'متابعة',
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'اختيار تاريخ لاحقًا',
            subtitle: 'لا أعرف التاريخ الآن، استخدموا خطة مرنة.',
            icon: Icons.event_busy_rounded,
            selected: true,
          ),
          SizedBox(height: 12),
          GuestOnboardingCard(
            child: Text(
              'اختيار التاريخ الحقيقي سيتم ربطه لاحقًا بمكوّن آمن داخل المسار المفعّل.',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
