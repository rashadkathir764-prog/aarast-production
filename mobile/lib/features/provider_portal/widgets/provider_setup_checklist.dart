import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/provider_dashboard_provider.dart';

/// A newly approved provider lands on a dashboard of zeros. This names what
/// customers still cannot see and leads to it; customers find the provider
/// only once one service is published (field test Q14).
class ProviderSetupChecklist extends StatelessWidget {
  const ProviderSetupChecklist({required this.dashboard, super.key});

  final ProviderDashboardProvider dashboard;

  static bool _hasService(ProviderDashboardProvider dashboard) =>
      dashboard.services.any((service) => service.isActive);

  static bool _hasLogo(ProviderDashboardProvider dashboard) =>
      dashboard.profile?.logoUrl?.trim().isNotEmpty == true;

  static bool _hasDescription(ProviderDashboardProvider dashboard) =>
      dashboard.profile?.description?.trim().isNotEmpty == true;

  static bool isIncomplete(ProviderDashboardProvider dashboard) =>
      !_hasService(dashboard) ||
      !_hasLogo(dashboard) ||
      !_hasDescription(dashboard);

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        done: _hasService(dashboard),
        title: 'أضف خدمة واحدة على الأقل بسعرها',
        hint: 'لن يظهر ملفك للعملاء قبلها.',
        route: AppRouter.providerServiceNew,
      ),
      (
        done: _hasLogo(dashboard),
        title: 'أضف شعارك أو صورة نشاطك',
        hint: 'الملف بصورة يجذب طلبات أكثر.',
        route: AppRouter.providerProfileEdit,
      ),
      (
        done: _hasDescription(dashboard),
        title: 'اكتب نبذة عن نشاطك',
        hint: 'ما تقدّمه وما يميزك.',
        route: AppRouter.providerProfileEdit,
      ),
    ];
    final remaining = steps.where((step) => !step.done).length;
    final textTheme = Theme.of(context).textTheme;
    return AarastCard(
      key: const Key('provider-setup-checklist'),
      color: AppTheme.brandMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أكمل ملفك ليراك العملاء',
            style: textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            remaining == 1 ? 'بقيت خطوة واحدة.' : 'بقيت $remaining خطوات.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final step in steps)
            InkWell(
              onTap: step.done ? null : () => context.push(step.route),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      step.done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 20,
                      color: step.done ? AppTheme.success : AppTheme.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: textTheme.bodyMedium?.copyWith(
                              color: step.done
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              decoration: step.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (!step.done)
                            Text(
                              step.hint,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!step.done)
                      const Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: AppTheme.brand,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
