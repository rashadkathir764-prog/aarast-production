import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      final hasAccount =
          !AppFeatureFlags.devBypassLoginGatesForUxExploration ||
          await AuthActionGuard.hasAccount(context);
      if (!mounted || !hasAccount) return;
      context.read<ProviderDashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    final canManageListing = _canManageProviderListing(profile?.status);

    return AarastPageScaffold(
      title: 'لوحة المزود',
      subtitle: 'إدارة ملفك وخدماتك وطلبات العملاء المحتملين.',
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.home);
            }
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: dashboard.loadDashboard,
        child: ListView(
          children: [
            if (auth.status != AuthStatus.authenticated &&
                AppFeatureFlags.devBypassLoginGatesForUxExploration)
              _NoProviderProfileCard(
                onApply: () => context.go(AppRouter.providerApply),
              )
            else if (auth.status == AuthStatus.unauthenticated)
              _AuthRequiredCard(onLogin: () => context.go(AppRouter.login))
            else if (dashboard.isLoading && dashboard.profile == null)
              const _DashboardSkeleton()
            else if (!dashboard.hasProviderProfile)
              _NoProviderProfileCard(
                onApply: () => context.go(AppRouter.providerApply),
              )
            else ...[
              _ProviderProfileCard(profile: profile!),
              const SizedBox(height: 16),
              _ProviderStatusNotice(profile: profile),
              const SizedBox(height: 16),
              _ProviderStats(
                summary: dashboard.summary,
                packageCount: dashboard.packages.length,
              ),
              const SizedBox(height: 16),
              _ProviderGuideCard(profile: profile),
              const SizedBox(height: 16),
              _ProviderServices(
                services: dashboard.services,
                canManageListing: canManageListing,
              ),
              const SizedBox(height: 16),
              _ProviderPackages(
                packages: dashboard.packages,
                canManageListing: canManageListing,
              ),
              const SizedBox(height: 16),
              _ProviderQuotes(quotes: dashboard.quoteRequests),
            ],
            if (dashboard.errorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineError(message: dashboard.errorMessage!),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _AuthRequiredCard extends StatelessWidget {
  const _AuthRequiredCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'تسجيل الدخول مطلوب',
      message: 'سجلي الدخول لعرض لوحة المزود أو إرسال طلب الانضمام.',
      action: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login_rounded),
        label: const Text('تسجيل الدخول'),
      ),
    );
  }
}

class _NoProviderProfileCard extends StatelessWidget {
  const _NoProviderProfileCard({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: Icons.storefront_rounded,
      title: 'لا يوجد حساب مزود',
      message:
          'أرسل طلب الانضمام كمزود. بعد المراجعة ستظهر لوحة المزود وخدماتك هنا.',
      action: FilledButton.icon(
        onPressed: onApply,
        icon: const Icon(Icons.assignment_ind_outlined),
        label: const Text('طلب الانضمام كمزود'),
      ),
    );
  }
}

class _ProviderProfileCard extends StatelessWidget {
  const _ProviderProfileCard({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Logo(url: profile.logoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AarastStatusPill(
                      label: _providerStatusLabel(profile.status),
                      icon: Icons.verified_user_outlined,
                      color: _providerStatusColor(profile.status),
                      backgroundColor: _providerStatusColor(
                        profile.status,
                      ).withAlpha(24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.dMaroonDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.city?.nameAr ??
                          PhoneNumberUtils.display(profile.phone) ??
                          profile.phone ??
                          'حساب مزود اعّرست',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(
              profile.description!.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.phone?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label:
                      PhoneNumberUtils.display(profile.phone) ??
                      profile.phone!.trim(),
                  icon: Icons.phone_outlined,
                  color: AppTheme.dBlue,
                  backgroundColor: AppTheme.dBlueBg,
                ),
              if (profile.primaryCategory?.nameAr.trim().isNotEmpty == true)
                AarastStatusPill(
                  label: profile.primaryCategory!.nameAr.trim(),
                  icon: Icons.category_outlined,
                  color: AppTheme.dMaroon,
                  backgroundColor: AppTheme.dPinkBg,
                ),
              AarastStatusPill(
                label:
                    '${profile.ratingAverage.toStringAsFixed(1)} (${profile.ratingCount})',
                icon: Icons.star_rounded,
                color: AppTheme.dGoldDeep,
                backgroundColor: AppTheme.dCreamBg,
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تعديل ملف المزود سيظهر قريبًا بواجهة كاملة.',
                    ),
                  ),
                );
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل الملف'),
          ),
        ],
      ),
    );
  }
}

class _ProviderStatusNotice extends StatelessWidget {
  const _ProviderStatusNotice({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    final status = profile.status;
    if (_canManageProviderListing(status)) {
      return const AarastCard(
        color: AppTheme.dGreenBg,
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: AppTheme.dGreen),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'حساب المزود نشط. خدماتك وباقاتك المؤهلة تظهر في سوق الموردين للعملاء.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final note = profile.reviewNote?.trim();
    return AarastCard(
      color: status == 'SUSPENDED' || status == 'REJECTED'
          ? AppTheme.dPinkBg
          : AppTheme.dCreamBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status == 'NEEDS_CHANGES'
                ? Icons.edit_note_outlined
                : Icons.pending_actions_outlined,
            color: _providerStatusColor(status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _providerStatusTitle(status),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _providerStatusMessage(status),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    note,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStats extends StatelessWidget {
  const _ProviderStats({required this.summary, required this.packageCount});

  final ProviderDashboardSummary summary;
  final int packageCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.18,
      children: [
        _StatBox(
          icon: Icons.design_services_outlined,
          label: 'الخدمات',
          value: '${summary.activeServicesCount}/${summary.servicesCount}',
          color: AppTheme.dMaroon,
          bg: AppTheme.dPinkBg,
        ),
        _StatBox(
          icon: Icons.inventory_2_outlined,
          label: 'الباقات',
          value: '$packageCount',
          color: AppTheme.dGoldDeep,
          bg: AppTheme.dCreamBg,
        ),
        _StatBox(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'طلبات العروض',
          value: '${summary.quoteRequestsCount}',
          color: AppTheme.dBlue,
          bg: AppTheme.dBlueBg,
        ),
        _StatBox(
          icon: Icons.person_search_outlined,
          label: 'العملاء المحتملين',
          value: '${summary.newQuoteRequestsCount}',
          color: AppTheme.dGreen,
          bg: AppTheme.dGreenBg,
        ),
      ],
    );
  }
}

class _ProviderGuideCard extends StatelessWidget {
  const _ProviderGuideCard({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCreamBg,
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppTheme.dGoldDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _canManageProviderListing(profile.status)
                  ? 'أكمل ملفك وخدماتك وباقاتك لتظهر أفضل في نتائج البحث وتستقبل طلبات أوضح من العملاء.'
                  : 'يمكنك متابعة حالة الطلب من هنا. لن يظهر ملفك في سوق الموردين حتى يتم اعتماده من الإدارة.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderServices extends StatelessWidget {
  const _ProviderServices({
    required this.services,
    required this.canManageListing,
  });

  final List<MarketplaceService> services;
  final bool canManageListing;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'الخدمات',
            icon: Icons.design_services_outlined,
            actionLabel: canManageListing ? 'إضافة' : null,
            onAction: canManageListing
                ? () => context.push(AppRouter.providerServiceNew)
                : null,
          ),
          const SizedBox(height: 12),
          if (!canManageListing) ...[
            const _LockedListingNotice(),
            const SizedBox(height: 12),
          ],
          if (services.isEmpty)
            AarastEmptyState(
              icon: Icons.design_services_outlined,
              title: 'لا توجد خدمات بعد',
              message: canManageListing
                  ? 'أضف خدمة ليبدأ كتالوج المزود بالظهور للعملاء.'
                  : 'ستتمكنين من إضافة الخدمات بعد اعتماد حساب المزود.',
              action: canManageListing
                  ? OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRouter.providerServiceNew),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة خدمة'),
                    )
                  : null,
            )
          else
            for (final service in services) ...[
              _ServiceCard(service: service),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ProviderPackages extends StatelessWidget {
  const _ProviderPackages({
    required this.packages,
    required this.canManageListing,
  });

  final List<ProviderPackage> packages;
  final bool canManageListing;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'الباقات',
            icon: Icons.inventory_2_outlined,
            actionLabel: canManageListing ? 'إضافة' : null,
            onAction: canManageListing
                ? () => context.push(AppRouter.providerPackageNew)
                : null,
          ),
          const SizedBox(height: 12),
          if (!canManageListing) ...[
            const _LockedListingNotice(),
            const SizedBox(height: 12),
          ],
          if (packages.isEmpty)
            AarastEmptyState(
              icon: Icons.card_giftcard_rounded,
              title: 'لا توجد باقات بعد',
              message: canManageListing
                  ? 'أنشئي باقة واضحة لتسهل على العملاء مقارنة عروضك.'
                  : 'ستتمكنين من إضافة الباقات بعد اعتماد حساب المزود.',
              action: canManageListing
                  ? OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRouter.providerPackageNew),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة باقة'),
                    )
                  : null,
            )
          else
            for (final item in packages) ...[
              _PackageCard(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ProviderQuotes extends StatelessWidget {
  const _ProviderQuotes({required this.quotes});

  final List<QuoteRequest> quotes;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'طلبات عروض الأسعار',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (quotes.isEmpty)
            const AarastEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'لا توجد طلبات حالية',
              message: 'ستظهر طلبات العملاء هنا عند إرسال عروض سعر لك.',
            )
          else
            for (final quote in quotes) ...[
              _QuoteTile(quote: quote),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LockedListingNotice extends StatelessWidget {
  const _LockedListingNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCreamBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dGold2.withAlpha(120)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: AppTheme.dGoldDeep, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'الإدارة تراجع الطلب أولاً. إدارة الخدمات والباقات ستفتح بعد الاعتماد.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dCard2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final MarketplaceService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _tileDecoration(),
      child: Row(
        children: [
          _TileIcon(
            icon: Icons.auto_awesome_rounded,
            color: AppTheme.dGoldDeep,
            background: AppTheme.dCreamBg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    AarastStatusPill(
                      label: service.isActive ? 'نشطة' : 'متوقفة',
                      color: service.isActive
                          ? AppTheme.dGreen
                          : AppTheme.dMuted,
                      backgroundColor: service.isActive
                          ? AppTheme.dGreenBg
                          : AppTheme.dCard2,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  service.category?.nameAr ?? 'فئة غير محددة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _priceText(service.basePrice, service.currency),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dMaroon,
                    fontWeight: FontWeight.w900,
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

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.item});

  final ProviderPackage item;

  @override
  Widget build(BuildContext context) {
    final items = item.items
        ?.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _tileDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TileIcon(
                icon: Icons.card_giftcard_rounded,
                color: AppTheme.dMaroon,
                background: AppTheme.dPinkBg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.serviceTitle?.trim().isNotEmpty == true)
                      Text(
                        item.serviceTitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _priceText(item.price, item.currency),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppTheme.dMaroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (item.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              item.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.dInkSoft, height: 1.45),
            ),
          ],
          if (items != null && items.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final feature in items)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppTheme.dGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feature,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showQuoteDetails(context, quote),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _tileDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _quoteStatusColor(quote.status).withAlpha(24),
              child: Text(
                _statusInitial(quote.status),
                style: TextStyle(
                  color: _quoteStatusColor(quote.status),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.service?.title ??
                        quote.weddingPlanTitle ??
                        'طلب عرض سعر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    quote.userName?.trim().isNotEmpty == true
                        ? quote.userName!.trim()
                        : quote.message?.trim() ?? 'عميل اعّرست',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            AarastStatusPill(
              label: _quoteStatusLabel(quote.status),
              color: _quoteStatusColor(quote.status),
              backgroundColor: _quoteStatusColor(quote.status).withAlpha(24),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuoteDetails(BuildContext context, QuoteRequest quote) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.dLine,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quote.service?.title ?? 'تفاصيل طلب عرض السعر',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _SheetLine('العميل', quote.userName ?? 'عميل اعّرست'),
                  if (quote.userPhone?.trim().isNotEmpty == true)
                    _SheetLine(
                      'التواصل',
                      PhoneNumberUtils.display(quote.userPhone) ??
                          quote.userPhone!.trim(),
                    ),
                  if (quote.weddingPlanTitle?.trim().isNotEmpty == true)
                    _SheetLine('الخطة', quote.weddingPlanTitle!.trim()),
                  if (quote.eventDate != null)
                    _SheetLine('التاريخ', _dateText(quote.eventDate!)),
                  if (quote.location?.hasAnyLocation == true)
                    _SheetLine('الموقع', quote.location!.displayLabel),
                  if (quote.guestCount != null)
                    _SheetLine('الضيوف', '${quote.guestCount}'),
                  if (quote.budgetMin?.trim().isNotEmpty == true ||
                      quote.budgetMax?.trim().isNotEmpty == true)
                    _SheetLine(
                      'الميزانية',
                      '${quote.budgetMin ?? '—'} - ${quote.budgetMax ?? '—'}',
                    ),
                  if (quote.message?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      quote.message!.trim(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: QuoteStatusChip(status: quote.lifecycleStatus),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (quote.status == 'SENT')
                        OutlinedButton.icon(
                          onPressed: () =>
                              _updateStatus(sheetContext, quote.id, 'VIEWED'),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('قيد الرد'),
                        ),
                      if (quote.status == 'SENT' || quote.status == 'VIEWED')
                        FilledButton.icon(
                          onPressed: () =>
                              _showOfferComposer(sheetContext, quote),
                          icon: const Icon(Icons.request_quote_outlined),
                          label: const Text('إرسال عرض سعر'),
                        ),
                      if (quote.status == 'SENT' || quote.status == 'VIEWED')
                        TextButton(
                          onPressed: () =>
                              _updateStatus(sheetContext, quote.id, 'REJECTED'),
                          child: const Text('رفض الطلب'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String quoteRequestId,
    String status,
  ) async {
    final ok = await context
        .read<ProviderDashboardProvider>()
        .updateQuoteStatus(quoteRequestId: quoteRequestId, status: status);
    if (context.mounted && ok) Navigator.of(context).pop();
  }

  Future<void> _showOfferComposer(
    BuildContext sheetContext,
    QuoteRequest quote,
  ) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final sent = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إرسال عرض سعر حقيقي'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان العرض (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ (اختياري)',
                      suffixText: 'YER',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return num.tryParse(text) == null
                          ? 'أدخل مبلغًا صحيحًا'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل العرض',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'تفاصيل العرض مطلوبة'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final ok = await dialogContext
                    .read<ProviderDashboardProvider>()
                    .createQuoteOffer(
                      quoteRequestId: quote.id,
                      title: titleController.text,
                      amount: amountController.text,
                      message: messageController.text,
                    );
                if (dialogContext.mounted && ok) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('إرسال العرض'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    amountController.dispose();
    messageController.dispose();
    if (sent == true && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.dMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return ClipOval(
      child: Container(
        width: 78,
        height: 78,
        color: AppTheme.dCreamBg,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: AppTheme.dGoldDeep,
                size: 36,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 36,
                ),
              ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          Container(
            height: i == 0 ? 130 : 94,
            decoration: BoxDecoration(
              color: AppTheme.dCard2.withAlpha(180),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.dLine),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg,
      border: Border.all(color: AppTheme.danger.withAlpha(55)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

BoxDecoration _tileDecoration() {
  return BoxDecoration(
    color: AppTheme.dCard,
    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    border: Border.all(color: AppTheme.dLine),
  );
}

String _providerStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => 'نشط',
    'APPROVED' => 'نشط',
    'NEEDS_CHANGES' => 'يحتاج تعديل',
    'REJECTED' => 'مرفوض / يحتاج تعديل',
    'SUSPENDED' => 'موقوف',
    _ => 'قيد المراجعة',
  };
}

Color _providerStatusColor(String status) {
  return switch (status) {
    'ACTIVE' || 'APPROVED' => AppTheme.dGreen,
    'NEEDS_CHANGES' => AppTheme.dOrange,
    'REJECTED' => AppTheme.danger,
    'SUSPENDED' => AppTheme.dOrange,
    _ => AppTheme.dGoldDeep,
  };
}

bool _canManageProviderListing(String? status) {
  return status == 'ACTIVE' || status == 'APPROVED';
}

String _providerStatusTitle(String status) {
  return switch (status) {
    'NEEDS_CHANGES' => 'يحتاج الطلب إلى تعديل',
    'REJECTED' => 'تم رفض الطلب',
    'SUSPENDED' => 'تم إيقاف حساب المزود',
    _ => 'طلبك قيد المراجعة',
  };
}

String _providerStatusMessage(String status) {
  return switch (status) {
    'NEEDS_CHANGES' =>
      'راجعي ملاحظة الإدارة ثم حدّثي بيانات الطلب عند توفر شاشة تعديل الملف.',
    'REJECTED' =>
      'لن يظهر ملف المزود في السوق. يمكنك متابعة الملاحظة أو إعادة التقديم لاحقاً عند دعم التعديل.',
    'SUSPENDED' =>
      'تم إيقاف الظهور العام مؤقتاً. تواصل مع الإدارة لمعرفة الخطوة التالية.',
    _ =>
      'سيتم مراجعة بياناتك من الإدارة. لن يظهر ملفك للعملاء حتى يتم الاعتماد.',
  };
}

String _quoteStatusLabel(String status) {
  return switch (status) {
    'VIEWED' => 'قيد الرد',
    'RESPONDED' => 'تم الرد',
    'ACCEPTED' => 'مغلق',
    'REJECTED' => 'مغلق',
    'CANCELLED' => 'ملغي',
    _ => 'جديد',
  };
}

Color _quoteStatusColor(String status) {
  return switch (status) {
    'VIEWED' => AppTheme.dBlue,
    'RESPONDED' => AppTheme.dGoldDeep,
    'ACCEPTED' => AppTheme.dGreen,
    'REJECTED' => AppTheme.danger,
    'CANCELLED' => AppTheme.dMuted,
    _ => AppTheme.dMaroon,
  };
}

String _statusInitial(String status) {
  return switch (status) {
    'VIEWED' => 'ق',
    'RESPONDED' => 'ت',
    'ACCEPTED' => 'غ',
    'REJECTED' => 'غ',
    'CANCELLED' => 'ل',
    _ => 'ج',
  };
}

String _priceText(String? value, String? currency) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return 'حسب الطلب';
  return '$clean ${currency ?? 'YER'}';
}

String _dateText(DateTime value) {
  return '${value.day}/${value.month}/${value.year}';
}
