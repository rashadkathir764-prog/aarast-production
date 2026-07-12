import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

class ProviderHomeTab extends StatelessWidget {
  const ProviderHomeTab({required this.onOpenTab, super.key});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    return RefreshIndicator(
      color: AppTheme.burgundy,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          if (dashboard.isLoading && profile == null)
            const AarastScreenLoading(label: 'جارٍ تجهيز لوحة المزوّد...')
          else if (profile == null)
            AarastEmptyState(
              icon: LucideIcons.store,
              title: 'أكمل طلب الانضمام كمزوّد',
              message: 'بعد الاعتماد ستدير ملفك وخدماتك وطلبات العملاء من هنا.',
              action: FilledButton.icon(
                onPressed: () => context.push(AppRouter.providerApply),
                icon: const Icon(LucideIcons.badgeCheck),
                label: const Text('طلب الانضمام'),
              ),
            )
          else ...[
            _ProviderIdentityHero(profile: profile),
            const SizedBox(height: 16),
            _ProviderMetrics(
              summary: dashboard.summary,
              packageCount: dashboard.packages.length,
            ),
            const SizedBox(height: 18),
            _QuickActions(onOpenTab: onOpenTab),
            const SizedBox(height: 18),
            AarastSectionHeader(
              title: 'أحدث الطلبات',
              subtitle: 'طلبات عرض السعر الأحدث لنشاطك.',
              icon: LucideIcons.mailQuestion,
              actionLabel: dashboard.quoteRequests.isEmpty ? null : 'عرض الكل',
              onAction: dashboard.quoteRequests.isEmpty
                  ? null
                  : () => onOpenTab(1),
            ),
            const SizedBox(height: 12),
            if (dashboard.quoteRequests.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.inbox,
                title: 'لا توجد طلبات جديدة',
                message: 'حسّن ملفك وأضف صور خدماتك لزيادة فرص الظهور.',
              )
            else
              for (final quote in dashboard.quoteRequests.take(3)) ...[
                _QuoteSummaryTile(quote: quote),
                const SizedBox(height: 10),
              ],
          ],
          if (dashboard.errorMessage != null) ...[
            const SizedBox(height: 12),
            AarastErrorState(
              title: 'تعذر تحديث لوحة المزوّد',
              message: dashboard.errorMessage!,
              onRetry: dashboard.loadDashboard,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderIdentityHero extends StatelessWidget {
  const _ProviderIdentityHero({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppTheme.burgundy,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        image: profile.coverUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(profile.coverUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  AppTheme.burgundy.withValues(alpha: 0.58),
                  BlendMode.srcOver,
                ),
              ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.surface,
                backgroundImage: profile.logoUrl == null
                    ? null
                    : NetworkImage(profile.logoUrl!),
                child: profile.logoUrl == null
                    ? const Icon(
                        LucideIcons.store,
                        color: AppTheme.gold,
                        size: 30,
                      )
                    : null,
              ),
              const Spacer(),
              AarastStatusPill(
                label: _providerStatus(profile.status),
                icon: LucideIcons.shieldCheck,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
            ],
          ),
          const Spacer(),
          Text(
            profile.businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            profile.city?.nameAr ?? 'ملف مزوّد أعرست',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderMetrics extends StatelessWidget {
  const _ProviderMetrics({required this.summary, required this.packageCount});

  final ProviderDashboardSummary summary;
  final int packageCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('${summary.activeServicesCount}', 'خدمة نشطة', LucideIcons.sparkles),
      ('$packageCount', 'باقة', LucideIcons.gem),
      (
        '${summary.newQuoteRequestsCount}',
        'طلب جديد',
        LucideIcons.mailQuestion,
      ),
      (summary.averageRating.toStringAsFixed(1), 'التقييم', LucideIcons.star),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AarastCard(
          child: Row(
            children: [
              Icon(
                item.$3,
                color: index.isEven ? AppTheme.burgundy : AppTheme.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onOpenTab(1),
            icon: const Icon(LucideIcons.inbox),
            label: const Text('الطلبات'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(AppRouter.providerServiceNew),
            icon: const Icon(LucideIcons.plus),
            label: const Text('خدمة جديدة'),
          ),
        ),
      ],
    );
  }
}

class _QuoteSummaryTile extends StatelessWidget {
  const _QuoteSummaryTile({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Row(
        children: [
          const Icon(LucideIcons.mailQuestion, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote.service?.title ?? 'طلب عرض سعر',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
        ],
      ),
    );
  }
}

String _providerStatus(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return 'معتمد';
    case 'NEEDS_CHANGES':
      return 'يحتاج تعديل';
    case 'SUSPENDED':
      return 'موقوف';
    case 'REJECTED':
      return 'غير معتمد';
    default:
      return 'قيد المراجعة';
  }
}
