import 'package:flutter/material.dart';

import '../models/generated_dashboard_seed.dart';
import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class GeneratedDashboardPreviewScreen extends StatelessWidget {
  const GeneratedDashboardPreviewScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    super.key,
  });

  final GuestOnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final seed = GeneratedDashboardSeed.fromDraft(draft);

    return GuestOnboardingStepScaffold(
      title: 'ملخص محلي مؤقت',
      description:
          'هذه معاينة هيكلية وليست لوحة التحكم الحقيقية أو خطة محفوظة في الخادم.',
      continueLabel: 'إنهاء المعاينة',
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: seed.title,
            subtitle:
                '${seed.cityLabel} • ${seed.weddingDateLabel} • ${seed.estimatedBudgetLabel}',
            icon: Icons.dashboard_customize_rounded,
            selected: true,
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'الخطوة التالية',
            subtitle: seed.nextBestAction,
            icon: Icons.flag_rounded,
          ),
        ],
      ),
    );
  }
}
