import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class ProviderPathPendingScreen extends StatelessWidget {
  const ProviderPathPendingScreen({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      title: 'مسار المزود لاحقًا',
      description:
          'مسار مزود الخدمة محفوظ كاختيار داخلي فقط. لن نفتح لوحة المزود أو تسجيل مزود حقيقي في هذه المرحلة.',
      continueLabel: 'العودة لاختيار المسار',
      onContinue: onBack,
      onBack: onBack,
      child: const GuestOnboardingCard(
        child: Text(
          'سيتم فتح مسار المزود بعد اعتماد شاشة التسجيل والمراجعة ولوحة المزود. هذا الفرع آمن ومخفي خلف العلم الداخلي.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
