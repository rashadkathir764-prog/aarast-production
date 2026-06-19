import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class PrioritiesScreen extends StatelessWidget {
  const PrioritiesScreen({
    this.selectedPriorities = const [],
    this.onChanged,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final List<String> selectedPriorities;
  final ValueChanged<List<String>>? onChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  static const defaultPriorities = [
    'الميزانية',
    'المهام',
    'الضيوف',
    'الموردون',
    'المشاركة العائلية',
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = selectedPriorities.isEmpty
        ? defaultPriorities.take(3).toList(growable: false)
        : selectedPriorities;

    return GuestOnboardingStepScaffold(
      title: 'ما أهم ما تريد ترتيبه؟',
      description: 'هذه الأولويات ستساعد لوحة البداية المحلية لاحقًا.',
      continueLabel: 'حفظ الأولويات',
      onContinue: onContinue,
      onBack: onBack,
      child: GuestOnboardingCard(
        child: GuestOnboardingChipList(
          labels: defaultPriorities,
          selectedLabels: effectiveSelected,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
