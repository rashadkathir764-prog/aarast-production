import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuestOnboardingStepScaffold(
      title: 'من يخطط للزفاف؟',
      description: 'اختيار الدور يساعدنا لاحقًا في ضبط نبرة النصائح والخطوات.',
      continueLabel: 'حفظ الدور',
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'عريس',
            subtitle: 'أريد متابعة الخطة والميزانية والالتزامات.',
            icon: Icons.person_rounded,
            selected: true,
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'عروس',
            subtitle: 'أريد تجربة تخطيط واضحة ومرتبة لكل التفاصيل.',
            icon: Icons.person_outline_rounded,
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'مساعد',
            subtitle: 'أساعد العائلة أو الزوجين في ترتيب المهام.',
            icon: Icons.group_rounded,
          ),
        ],
      ),
    );
  }
}
