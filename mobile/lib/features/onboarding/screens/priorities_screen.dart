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
    return GuestOnboardingStepScaffold(
      stepNumber: 5,
      title: 'ما أهم ما تريد ترتيبه؟',
      description: 'هذه الأولويات ستساعد لوحة البداية المحلية لاحقًا.',
      continueLabel: 'حفظ الأولويات',
      onContinue: selectedPriorities.isEmpty ? null : onContinue,
      onBack: onBack,
      child: Column(
        children: [
          for (var index = 0; index < defaultPriorities.length; index++) ...[
            GuestOnboardingOptionTile(
              key: Key('guest-priority-$index'),
              title: defaultPriorities[index],
              subtitle: 'اجعلها ضمن أولويات لوحة البداية',
              icon: _priorityIcon(index),
              selected: selectedPriorities.contains(defaultPriorities[index]),
              onTap: () {
                final next = [...selectedPriorities];
                final value = defaultPriorities[index];
                next.contains(value) ? next.remove(value) : next.add(value);
                onChanged?.call(List.unmodifiable(next));
              },
            ),
            if (index != defaultPriorities.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  static IconData _priorityIcon(int index) => switch (index) {
    0 => Icons.account_balance_wallet_outlined,
    1 => Icons.check_circle_outline_rounded,
    2 => Icons.groups_2_outlined,
    3 => Icons.storefront_outlined,
    _ => Icons.diversity_3_outlined,
  };
}
