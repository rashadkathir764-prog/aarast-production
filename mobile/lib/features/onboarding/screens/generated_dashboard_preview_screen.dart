import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/generated_dashboard_seed.dart';
import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class GeneratedDashboardPreviewScreen extends StatelessWidget {
  const GeneratedDashboardPreviewScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final seed = GeneratedDashboardSeed.fromDraft(draft);

    return GuestOnboardingStepScaffold(
      title: 'ملخص محلي مؤقت',
      description:
          'هذه معاينة هيكلية وليست لوحة التحكم الحقيقية أو خطة محفوظة في الخادم.',
      continueLabel: 'إنهاء المعاينة',
      onBack: onBack,
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: seed.title,
            subtitle: seed.cityLabel,
            icon: Icons.dashboard_customize_rounded,
            selected: true,
          ),
          const SizedBox(height: 12),
          _PreviewRow(label: 'التاريخ', value: seed.weddingDateLabel),
          const SizedBox(height: 8),
          _PreviewRow(label: 'الميزانية', value: seed.estimatedBudgetLabel),
          const SizedBox(height: 8),
          _PreviewRow(
            label: 'الأولويات',
            value: _joinOrFallback(seed.selectedPriorities),
          ),
          const SizedBox(height: 8),
          _PreviewRow(
            label: 'التصنيفات',
            value: _joinOrFallback(seed.selectedCategories),
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

  static String _joinOrFallback(List<String> values) {
    return values.isEmpty ? 'لم تحدد بعد' : values.join('، ');
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingCard(
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
