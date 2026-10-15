import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show
        ProviderDashboardProfile,
        ProviderDashboardSummary,
        QuoteRequest,
        QuoteStatusChip;
import '../providers/provider_dashboard_provider.dart';
import 'provider_requests_tab.dart' show ProviderQuoteFacts;

class ProviderHomeTab extends StatelessWidget {
  const ProviderHomeTab({required this.onOpenTab, super.key});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    return RefreshIndicator(
      color: AppTheme.brand,
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
            if (!dashboard.canUseProviderOperations)
              _ProviderLifecycleNotice(profile: profile)
            else ...[
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
                actionLabel: dashboard.quoteRequests.isEmpty
                    ? null
                    : 'عرض الكل',
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
                  _QuoteSummaryTile(quote: quote, onOpen: () => onOpenTab(1)),
                  const SizedBox(height: 10),
                ],
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

class _ProviderLifecycleNotice extends StatelessWidget {
  const _ProviderLifecycleNotice({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    final status = profile.status.toUpperCase();
    final title = switch (status) {
      'NEEDS_CHANGES' => 'ملفك يحتاج تعديلات',
      'REJECTED' => 'لم يُعتمد طلب المزوّد',
      'SUSPENDED' => 'حساب المزوّد موقوف',
      _ => 'طلبك قيد المراجعة',
    };
    final defaultMessage = switch (status) {
      'NEEDS_CHANGES' => 'حدّث ملفك وفق ملاحظة الإدارة ليُراجع من جديد.',
      'REJECTED' => 'راجع سبب الرفض قبل تحديث الملف أو التواصل مع الدعم.',
      'SUSPENDED' => 'توقفت العمليات مؤقتًا حتى تعيد الإدارة تفعيل الحساب.',
      _ => 'يمكنك متابعة ملفك، وستتاح العمليات بعد الاعتماد.',
    };
    final note = profile.reviewNote?.trim();
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'NEEDS_CHANGES'
                    ? LucideIcons.fileEdit
                    : LucideIcons.shieldAlert,
                color: AppTheme.brand,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note == null || note.isEmpty ? defaultMessage : note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          if (status == 'NEEDS_CHANGES' || status == 'PENDING') ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.providerProfileEdit),
              icon: const Icon(LucideIcons.fileEdit),
              label: const Text('تحديث ملف المزوّد'),
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
      padding: const EdgeInsets.all(AarastV3Space.x4),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AarastV3Color.paper,
              borderRadius: BorderRadius.circular(AarastV3Radius.surface),
              border: Border.all(color: AarastV3Color.line),
              image: profile.logoUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(profile.logoUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: profile.logoUrl == null
                ? const Icon(
                    LucideIcons.store,
                    color: AarastV3Color.primary,
                    size: 26,
                  )
                : null,
          ),
          const SizedBox(width: AarastV3Space.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'استوديو العمل',
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: AarastV3Color.primary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AarastV3Space.x2,
                        vertical: AarastV3Space.x1,
                      ),
                      decoration: BoxDecoration(
                        color: AarastV3Color.mintSoft,
                        borderRadius: BorderRadius.circular(
                          AarastV3Radius.pill,
                        ),
                      ),
                      child: Text(
                        _providerStatus(profile.status),
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: AarastV3Color.mint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x2),
                Text(
                  profile.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AarastV3Type.title(
                    context,
                  ).copyWith(color: AarastV3Color.ink),
                ),
                const SizedBox(height: AarastV3Space.x2),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      color: AarastV3Color.textMuted,
                      size: 15,
                    ),
                    const SizedBox(width: AarastV3Space.x1),
                    Expanded(
                      child: Text(
                        profile.city?.nameAr ?? 'المدينة غير محددة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AarastV3Type.body(
                          context,
                        ).copyWith(color: AarastV3Color.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AarastV3Color.line)),
          ),
          child: Row(
            children: [
              Icon(
                item.$3,
                color: index.isEven ? AppTheme.brand : AppTheme.focus,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
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
            label: const Text('عرض الطلبات'),
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
  const _QuoteSummaryTile({required this.quote, required this.onOpen});

  final QuoteRequest quote;

  /// Opens the requests tab, where the provider replies (field test Q12: the
  /// tile looked tappable and did nothing).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(LucideIcons.mailQuestion, color: AppTheme.focus),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.service?.title ?? 'طلب عرض سعر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ProviderQuoteFacts(quote: quote),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuoteStatusChip(
            status: quote.lifecycleStatus,
            compact: true,
            forProvider: true,
          ),
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
