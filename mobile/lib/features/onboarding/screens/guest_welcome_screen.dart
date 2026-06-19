import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'ألف مبروك',
      description: 'ابدأ ترتيب زفافك خطوة بخطوة بدون تسجيل دخول الآن.',
      continueLabel: 'ابدأ',
      child: GuestOnboardingCard(
        child: Text(
          'سنجهز مسارًا محليًا مؤقتًا يساعدك على اختيار الدور والموقع والتاريخ والميزانية الأولية.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
