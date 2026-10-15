import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/provider_dashboard_provider.dart';

/// The provider's reach over the last 30 days (V1 checklist 4.19): page
/// views, quote requests, how many decided offers customers accepted, and
/// upcoming bookings, with one hint on what to improve.
class ProviderStatsPanel extends StatelessWidget {
  const ProviderStatsPanel({required this.dashboard, super.key});

  final ProviderDashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final stats = dashboard.summary.stats;
    if (stats == null) return const SizedBox.shrink();
    final rate = stats.acceptanceRate;
    final items = [
      ('${stats.profileViews}', 'مشاهدة لملفك', LucideIcons.eye),
      ('${stats.quoteRequests}', 'طلب عرض سعر', LucideIcons.mailQuestion),
      (
        rate == null ? '—' : '$rate٪',
        rate == null
            ? 'نسبة قبول عروضك'
            : 'قبول (${stats.offersAccepted} من ${stats.offersDecided})',
        LucideIcons.badgeCheck,
      ),
      ('${stats.upcomingBookings}', 'حجز قادم', LucideIcons.calendarCheck),
    ];
    final hint = providerStatsHint(
      profileViews: stats.profileViews,
      quoteRequests: stats.quoteRequests,
      acceptanceRate: rate,
    );
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'أداؤك خلال ${stats.windowDays} يومًا',
          subtitle: 'كيف يتفاعل العملاء مع ملفك.',
          icon: LucideIcons.barChart3,
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < items.length; row += 2)
          Row(
            children: [
              for (final item in items.skip(row).take(2))
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AarastV3Color.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$3, size: 20, color: AppTheme.brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (hint != null) ...[
          const SizedBox(height: 10),
          Text(
            hint,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// One practical next step from the numbers, or null when nothing stands out.
String? providerStatsHint({
  required int profileViews,
  required int quoteRequests,
  required int? acceptanceRate,
}) {
  if (profileViews == 0) {
    return 'لم يفتح أحد ملفك بعد. ملف فيه صور وأسعار واضحة يظهر للعملاء بثقة أكبر.';
  }
  if (quoteRequests == 0) {
    return 'عملاء شاهدوا ملفك ولم يطلبوا عرضًا. أضف صورًا لأعمالك ونطاق سعر واضحًا.';
  }
  if (acceptanceRate != null && acceptanceRate < 30) {
    return 'أغلب عروضك لم تُقبل. راجع أسعارك وما تشمله الباقة، وردّ بسرعة.';
  }
  return null;
}
