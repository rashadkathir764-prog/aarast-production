import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class BudgetSetupScreen extends StatelessWidget {
  const BudgetSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'ميزانية تقريبية',
      description: 'أدخل مبلغًا تقديريًا أو تخط هذه الخطوة الآن.',
      continueLabel: 'حفظ الميزانية',
      child: Column(
        children: [
          TextField(
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'المبلغ التقديري'),
          ),
          SizedBox(height: 12),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: 'العملة', hintText: 'YER'),
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'تخطي الآن',
            subtitle: 'يمكن إضافة الميزانية من شاشة المال لاحقًا.',
            icon: Icons.skip_next_rounded,
          ),
        ],
      ),
    );
  }
}
