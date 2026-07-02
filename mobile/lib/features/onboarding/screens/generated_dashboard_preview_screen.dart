import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/generated_dashboard_seed.dart';
import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class GeneratedDashboardPreviewScreen extends StatelessWidget {
  const GeneratedDashboardPreviewScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onContinue,
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final seed = GeneratedDashboardSeed.fromDraft(draft);

    return GuestOnboardingStepScaffold(
      stepNumber: 8,
      title: 'مسودة خطة جاهزة للمراجعة',
      description:
          'هذه معاينة لمسودة محفوظة على هذا الجهاز. سجّل الدخول لحفظ الخطة ومزامنتها.',
      continueLabel: 'إنشاء خطتي',
      onContinue: onContinue,
      onBack: onBack,
      child: Column(
        children: [
          const _LocalDraftNotice(),
          const SizedBox(height: 12),
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
              color: AppTheme.burgundy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalDraftNotice extends StatelessWidget {
  const _LocalDraftNotice();

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingCard(
      color: AppTheme.goldSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              Icons.devices_rounded,
              color: AppTheme.burgundy,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مسودة محلية',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ستفتح الخطة على هذا الجهاز. المزامنة والمشاركة تحتاج تسجيل دخول لاحقًا.',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
