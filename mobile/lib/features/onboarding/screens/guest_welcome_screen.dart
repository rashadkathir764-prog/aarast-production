import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({this.onContinue, this.onBack, super.key});

  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      title: 'ألف مبروك',
      description: 'ابدأ ترتيب زفافك خطوة بخطوة بدون تسجيل دخول الآن.',
      continueLabel: 'ابدأ',
      onContinue: onContinue,
      onBack: onBack,
      child: const GuestOnboardingCard(
        child: Text(
          'سنجهز مسارًا محليًا مؤقتًا يساعدك على اختيار الدور والموقع والتاريخ والميزانية الأولية.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
