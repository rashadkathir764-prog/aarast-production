import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class PersonaScreen extends StatelessWidget {
  const PersonaScreen({
    this.selectedPersona,
    this.onSelectPersona,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final GuestPersona? selectedPersona;
  final ValueChanged<GuestPersona>? onSelectPersona;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      stepNumber: 2,
      title: 'من يخطط للزفاف؟',
      description: 'اختيار الدور يساعدنا لاحقًا في ضبط نبرة النصائح والخطوات.',
      continueLabel: 'حفظ الدور',
      onContinue: selectedPersona == null ? null : onContinue,
      onBack: onBack,
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            key: const Key('guest-persona-groom'),
            title: 'عريس',
            subtitle: 'أريد متابعة الخطة والميزانية والالتزامات.',
            icon: Icons.person_rounded,
            selected: selectedPersona == GuestPersona.groom,
            onTap: () => onSelectPersona?.call(GuestPersona.groom),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            key: const Key('guest-persona-bride'),
            title: 'عروسة',
            subtitle: 'أريد تجربة تخطيط واضحة ومرتبة لكل التفاصيل.',
            icon: Icons.person_outline_rounded,
            selected: selectedPersona == GuestPersona.bride,
            onTap: () => onSelectPersona?.call(GuestPersona.bride),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            key: const Key('guest-persona-helper'),
            title: 'مساعد',
            subtitle: 'أساعد العائلة أو الزوجين في ترتيب المهام.',
            icon: Icons.group_rounded,
            selected: selectedPersona == GuestPersona.helper,
            onTap: () => onSelectPersona?.call(GuestPersona.helper),
          ),
        ],
      ),
    );
  }
}
