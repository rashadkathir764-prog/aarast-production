import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/provider_dashboard_provider.dart';

/// The admin already listed this business under the account's phone (V1
/// checklist 4.18): the owner claims it instead of applying again. The phone
/// was verified at sign-in, so claiming needs no other proof.
class ProviderClaimCard extends StatelessWidget {
  const ProviderClaimCard({required this.dashboard, super.key});

  final ProviderDashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final listing = dashboard.claimableListing;
    if (listing == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(LucideIcons.badgeCheck, color: AppTheme.brand, size: 32),
          const SizedBox(height: 10),
          Text(
            'ملفك موجود في اعّرست',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'أضاف فريق اعّرست «${listing.businessName}» برقم جوالك. استلمه '
            'لتدير خدماتك وأسعارك وتستقبل طلبات العملاء، بلا طلب انضمام جديد.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (dashboard.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              dashboard.errorMessage!,
              style: textTheme.bodySmall?.copyWith(color: AppTheme.danger),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: dashboard.isSubmitting
                ? null
                : () async {
                    final claimed = await dashboard.claimListing();
                    if (!context.mounted || !claimed) return;
                    AarastToast.showSuccess(context, 'استلمت ملفك. أهلًا بك.');
                    await dashboard.loadDashboard();
                    if (context.mounted) context.go(AppRouter.providerDashboard);
                  },
            icon: dashboard.isSubmitting
                ? const AarastInlineSpinner(color: Colors.white)
                : const Icon(LucideIcons.checkCircle2),
            label: const Text('استلم ملفي'),
          ),
          const SizedBox(height: 8),
          Text(
            'إن لم يكن هذا نشاطك، تواصل مع الدعم من صفحة المساعدة.',
            style: textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
