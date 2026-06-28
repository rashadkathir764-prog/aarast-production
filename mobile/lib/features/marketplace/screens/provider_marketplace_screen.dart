import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

class ProviderMarketplaceScreen extends StatefulWidget {
  const ProviderMarketplaceScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState extends State<ProviderMarketplaceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  WeddingLocationDraft? _weddingLocation;
  String? _weddingLocationPlanId;
  List<String> _neededServiceLabels = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ProviderMarketplaceProvider>();
      _searchController.text = provider.search;
      final includeAccountData = await AuthActionGuard.hasAccount(context);
      if (!mounted) return;
      await provider.loadMarketplace(includeAccountData: includeAccountData);
      if (!mounted) return;
      await _loadWeddingLocationContext(
        hasAccount: includeAccountData,
        marketplace: provider,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            color: AppTheme.dMaroon,
            onRefresh: provider.loadMarketplace,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.embedded ? 18 : 20,
                16,
                widget.embedded ? 124 : 28,
              ),
              children: [
                _ProvidersHeader(embedded: widget.embedded, provider: provider),
                const SizedBox(height: 14),
                _MarketplaceHero(
                  provider: provider,
                  neededServiceLabels: _neededServiceLabels,
                  onTap: () => _searchFocusNode.requestFocus(),
                ),
                const SizedBox(height: 12),
                _ServiceCategoriesSection(
                  categories: provider.categories,
                  selectedLabels: _neededServiceLabels,
                  selectedCategoryId: provider.categoryId,
                  onSelect: provider.setCategory,
                ),
                const SizedBox(height: 12),
                _ImportantNowCard(
                  quotes: provider.quoteRequests,
                  includesAccountData: provider.includesAccountData,
                  onOpenPlanCenter: _openPlanCenterForQuote,
                ),
                const SizedBox(height: 12),
                _LocationContextCard(
                  location: _weddingLocation,
                  onCompleteLocation: _openLocationCompletion,
                ),
                const SizedBox(height: 18),
                _MarketplaceSearch(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  provider: provider,
                ),
                const SizedBox(height: 12),
                _FilterChips(provider: provider),
                const SizedBox(height: 18),
                if (provider.errorMessage != null)
                  _ErrorCard(
                    message: provider.errorMessage!,
                    onRetry: provider.loadMarketplace,
                  )
                else if (provider.isLoading && provider.providers.isEmpty)
                  const _MarketplaceSkeleton()
                else if (provider.providers.isEmpty)
                  AarastEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'لا يوجد موردون متاحون حاليًا',
                    message: _weddingLocation?.hasRequiredLocation == true
                        ? 'غيّر المدينة أو الفئة، أو امسح الفلاتر لاستعراض الموردين المتاحين.'
                        : 'أضف موقع الزفاف لتحسين تصفية المدينة، أو امسح الفلاتر لاستعراض الموردين المتاحين.',
                    action: OutlinedButton.icon(
                      onPressed: provider.clearFilters,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('مسح الفلاتر'),
                    ),
                  )
                else ...[
                  _ResultsHeader(
                    count: provider.providers.length,
                    location: _weddingLocation,
                  ),
                  const SizedBox(height: 12),
                  for (final item in provider.providers) ...[
                    _ProviderCard(
                      provider: item,
                      isFavorite: provider.favoriteProviderIds.contains(
                        item.id,
                      ),
                      onFavorite: () async {
                        if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
                          context,
                        )) {
                          return;
                        }
                        await provider.toggleFavorite(item.id);
                      },
                      onTap: () =>
                          context.push(AppRouter.providerDetails(item.id)),
                      onRequestQuote: () =>
                          context.push(AppRouter.providerQuote(item.id)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 8),
                _QuoteRequestsOverview(
                  quotes: provider.quoteRequests,
                  includesAccountData: provider.includesAccountData,
                  onOpenPlanCenter: _openPlanCenterForQuote,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadWeddingLocationContext({
    required bool hasAccount,
    required ProviderMarketplaceProvider marketplace,
  }) async {
    WeddingLocationDraft? location;
    String? planId;
    GuestOnboardingStorage? guestStorage;
    WeddingPlansProvider? weddingPlans;

    try {
      guestStorage = context.read<GuestOnboardingStorage>();
    } on ProviderNotFoundException {
      // Some isolated widget tests mount the marketplace without app-level providers.
    }
    if (hasAccount) {
      try {
        weddingPlans = context.read<WeddingPlansProvider>();
      } on ProviderNotFoundException {
        // Marketplace browsing can still work without plan context.
      }
    }

    if (guestStorage != null) {
      final guestPlan = await guestStorage.loadGuestPlan();
      final guestLocation = guestPlan?.weddingLocation;
      if (guestLocation?.hasAnyLocation == true) {
        location = guestLocation;
        planId = guestPlan?.guestPlanId;
      }
      _neededServiceLabels = _cleanLabels(
        guestPlan?.selectedCategoryKeys ?? const [],
      );
    }

    if (location?.hasAnyLocation != true && hasAccount) {
      if (weddingPlans != null) {
        if (weddingPlans.activePlan == null) {
          await weddingPlans.loadActiveWeddingPlan();
        }
        final activePlan = weddingPlans.activePlan;
        final activeLocation = activePlan?.weddingLocation;
        if (activeLocation?.hasAnyLocation == true) {
          location = activeLocation;
          planId = activePlan?.id;
        }
      }
    }

    if (!mounted) return;
    final matchingCityId = location?.hasRequiredLocation == true
        ? _matchingCityId(marketplace, location!)
        : null;
    setState(() {
      _weddingLocation = location;
      _weddingLocationPlanId = planId;
    });
    if (matchingCityId != null && marketplace.cityId == null) {
      await marketplace.setCity(matchingCityId);
    }
  }

  String? _matchingCityId(
    ProviderMarketplaceProvider marketplace,
    WeddingLocationDraft location,
  ) {
    final candidates = <String>[
      if (location.cityOrDistrict?.trim().isNotEmpty == true)
        location.cityOrDistrict!.trim(),
      if (location.governorate?.trim().isNotEmpty == true)
        location.governorate!.trim(),
    ];
    if (candidates.isEmpty) return null;

    for (final city in marketplace.cities) {
      final cityName = city.nameAr.trim();
      if (candidates.any((candidate) => candidate == cityName)) {
        return city.id;
      }
    }
    return null;
  }

  void _openLocationCompletion() {
    final planId = _weddingLocationPlanId;
    if (planId != null && planId.trim().isNotEmpty) {
      context.push(AppRouter.planCenter(planId));
      return;
    }
    context.push(AppRouter.onboarding);
  }

  void _openPlanCenterForQuote(QuoteRequest quote) {
    final planId = quote.weddingPlanId;
    if (planId == null || planId.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('افتح مركز الخطة بعد ربط طلب العرض بخطة زفاف.'),
          ),
        );
      return;
    }
    context.push(AppRouter.planCenter(planId));
  }
}

class _ProvidersHeader extends StatelessWidget {
  const _ProvidersHeader({required this.embedded, required this.provider});

  final bool embedded;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final offersReceived = _offersReceivedCount(provider.quoteRequests);
    final acceptedProviders = _acceptedProviderCount(provider.quoteRequests);
    return Row(
      children: [
        if (!embedded) ...[
          _CircleButton(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              if (context.canPop()) context.pop();
            },
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموردون والعروض',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.dMaroonDeep,
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر خدمات زفافك واطلب عروضًا مناسبة بدون حجز أو دفع داخل التطبيق',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MiniCount(label: 'فئات', value: provider.categories.length),
            const SizedBox(height: 6),
            _MiniCount(
              label: 'عروض',
              value: provider.includesAccountData ? offersReceived : null,
            ),
            const SizedBox(height: 6),
            _MiniCount(
              label: 'مقبول',
              value: provider.includesAccountData ? acceptedProviders : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value?.toString() ?? '—',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.dMaroon,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withAlpha(34)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.dGold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(210),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({
    required this.provider,
    required this.neededServiceLabels,
    required this.onTap,
  });

  final ProviderMarketplaceProvider provider;
  final List<String> neededServiceLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quotes = provider.quoteRequests;
    final offersReceived = _offersReceivedCount(quotes);
    final acceptedProviders = _acceptedProviderCount(quotes);
    final pendingDecisions = _pendingDecisionCount(quotes);

    return Container(
      decoration: AppTheme.heroDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Colors.white.withAlpha(36)),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.dGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مركز الموردين والعروض',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.includesAccountData
                          ? 'طلباتك وعروضك من بيانات الحساب'
                          : 'تصفح عام، وطلب العرض يحتاج تسجيل دخول',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(210),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              AarastStatusPill(
                label: provider.includesAccountData ? 'حساب محفوظ' : 'تصفح عام',
                color: AppTheme.dGold,
                backgroundColor: Colors.white.withAlpha(24),
                icon: provider.includesAccountData
                    ? Icons.verified_user_outlined
                    : Icons.visibility_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 330
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetric(
                    width: tileWidth,
                    label: 'خدمات تحتاج متابعة',
                    value: neededServiceLabels.length.toString(),
                    icon: Icons.category_outlined,
                  ),
                  _HeroMetric(
                    width: tileWidth,
                    label: 'طلبات مرسلة',
                    value: provider.includesAccountData
                        ? quotes.length.toString()
                        : '0',
                    icon: Icons.outbox_outlined,
                  ),
                  _HeroMetric(
                    width: tileWidth,
                    label: 'عروض وصلت',
                    value: provider.includesAccountData
                        ? offersReceived.toString()
                        : '0',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                  _HeroMetric(
                    width: tileWidth,
                    label: 'قرارات معلقة',
                    value: provider.includesAccountData
                        ? pendingDecisions.toString()
                        : '0',
                    icon: Icons.rule_rounded,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  acceptedProviders == 0 || !provider.includesAccountData
                      ? 'لم تعتمد أي مورد بعد'
                      : '$acceptedProviders مورد معتمد في الخطة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(225),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha(90)),
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('بحث'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCategoriesSection extends StatelessWidget {
  const _ServiceCategoriesSection({
    required this.categories,
    required this.selectedLabels,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<ProviderCategory> categories;
  final List<String> selectedLabels;
  final String? selectedCategoryId;
  final Future<void> Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الخدمات التي قد تحتاجها',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 10),
          if (selectedLabels.isEmpty)
            Text(
              'لم تحدد خدمات مطلوبة في الخطة بعد. استخدم الفئات كتصفح فقط، بدون أرقام أو ترشيحات غير مؤكدة.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in selectedLabels)
                  _NeededServiceChip(label: label),
              ],
            ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const AarastEmptyState(
              icon: Icons.category_outlined,
              title: 'لا توجد فئات خدمات متاحة حاليًا',
              message: 'عند توفر فئات الموردين ستظهر هنا للتصفح.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth < 330
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final category in categories)
                      _CategoryCard(
                        width: itemWidth,
                        category: category,
                        selected: category.id == selectedCategoryId,
                        needed: selectedLabels.any(
                          (label) =>
                              _looselySameArabicLabel(label, category.nameAr),
                        ),
                        onTap: () => onSelect(
                          category.id == selectedCategoryId
                              ? null
                              : category.id,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NeededServiceChip extends StatelessWidget {
  const _NeededServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_outline_rounded, size: 16),
      label: Text(label),
      backgroundColor: AppTheme.dPinkBg,
      side: BorderSide(color: AppTheme.dMaroon.withAlpha(28)),
      labelStyle: const TextStyle(
        color: AppTheme.dMaroon,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.width,
    required this.category,
    required this.selected,
    required this.needed,
    required this.onTap,
  });

  final double width;
  final ProviderCategory category;
  final bool selected;
  final bool needed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.dMaroon : AppTheme.dCard2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? AppTheme.dMaroon
                  : needed
                  ? AppTheme.dGoldDeep.withAlpha(70)
                  : AppTheme.dLine,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : needed
                    ? Icons.flag_outlined
                    : Icons.category_outlined,
                color: selected
                    ? Colors.white
                    : needed
                    ? AppTheme.dGoldDeep
                    : AppTheme.dMaroon,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.nameAr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? Colors.white : AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportantNowCard extends StatelessWidget {
  const _ImportantNowCard({
    required this.quotes,
    required this.includesAccountData,
    required this.onOpenPlanCenter,
  });

  final List<QuoteRequest> quotes;
  final bool includesAccountData;
  final void Function(QuoteRequest quote) onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final important = _importantQuotes(quotes);
    final title = important.isEmpty
        ? 'لا توجد متابعة عاجلة الآن'
        : 'أهم ما يحتاج قرار الآن';
    final message = !includesAccountData
        ? 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود.'
        : important.isEmpty
        ? 'لا توجد عروض حقيقية تحتاج قبولًا أو رفضًا في هذه اللحظة.'
        : 'راجع العروض الواصلة أو الطلبات المنتظرة بناءً على بيانات حسابك.';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: important.isEmpty ? AppTheme.dCard2 : AppTheme.dPinkBg,
      border: Border.all(
        color: important.isEmpty
            ? AppTheme.dLine
            : AppTheme.dMaroon.withAlpha(35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                important.isEmpty
                    ? Icons.check_circle_outline_rounded
                    : Icons.priority_high_rounded,
                color: important.isEmpty ? AppTheme.dGreen : AppTheme.dMaroon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (important.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final quote in important) ...[
              _ImportantQuoteRow(
                quote: quote,
                onOpenPlanCenter: () => onOpenPlanCenter(quote),
              ),
              if (quote != important.last)
                const Divider(height: 18, color: AppTheme.dLine),
            ],
          ],
        ],
      ),
    );
  }
}

class _ImportantQuoteRow extends StatelessWidget {
  const _ImportantQuoteRow({
    required this.quote,
    required this.onOpenPlanCenter,
  });

  final QuoteRequest quote;
  final VoidCallback onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final action = _quoteNextActionLabel(quote);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.dLine),
          ),
          child: const Icon(
            Icons.request_quote_outlined,
            color: AppTheme.dMaroon,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _quoteProviderLabel(quote),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                action,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (quote.weddingPlanId?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenPlanCenter,
                  icon: const Icon(Icons.event_note_outlined, size: 18),
                  label: const Text('فتح مركز الخطة'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketplaceSearch extends StatelessWidget {
  const _MarketplaceSearch({
    required this.controller,
    required this.focusNode,
    required this.provider,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          decoration: InputDecoration(
            hintText: 'ابحث عن مورد أو خدمة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      provider.setSearch('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectedCity = provider.cityId;
    final selectedCategory = provider.categoryId;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MenuFilterChip(
          label: _cityLabel(selectedCity),
          icon: Icons.place_outlined,
          items: provider.cities
              .map((city) => _FilterOption(city.id, city.nameAr))
              .toList(),
          onSelected: provider.setCity,
        ),
        _MenuFilterChip(
          label: _categoryLabel(selectedCategory),
          icon: Icons.category_outlined,
          items: provider.categories
              .map((category) => _FilterOption(category.id, category.nameAr))
              .toList(),
          onSelected: provider.setCategory,
        ),
        ActionChip(
          avatar: const Icon(Icons.close_rounded, size: 18),
          label: const Text('مسح'),
          onPressed: provider.clearFilters,
        ),
      ],
    );
  }

  String _cityLabel(String? id) {
    if (id == null) return 'المدينة';
    return provider.cities
        .firstWhere(
          (city) => city.id == id,
          orElse: () => const MarketplaceCity(id: '', nameAr: 'المدينة'),
        )
        .nameAr;
  }

  String _categoryLabel(String? id) {
    if (id == null) return 'الفئة';
    return provider.categories
        .firstWhere(
          (category) => category.id == id,
          orElse: () => const ProviderCategory(id: '', nameAr: 'الفئة'),
        )
        .nameAr;
  }
}

class _LocationContextCard extends StatelessWidget {
  const _LocationContextCard({
    required this.location,
    required this.onCompleteLocation,
  });

  final WeddingLocationDraft? location;
  final VoidCallback onCompleteLocation;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location?.hasRequiredLocation == true;
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: hasLocation ? AppTheme.dCreamBg : AppTheme.dCard2,
      border: Border.all(color: AppTheme.dLine),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: hasLocation ? AppTheme.dGoldDeep : AppTheme.dPinkBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              hasLocation ? Icons.near_me_outlined : Icons.add_location_alt,
              color: hasLocation ? Colors.white : AppTheme.dMaroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? 'تصفية حسب موقع الزفاف: ${location!.mediumLabel ?? location!.shortLabel}'
                      : 'أضف موقع الزفاف لتحسين تصفية المدينة.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLocation
                      ? 'نستخدم الموقع كفلتر مدينة عند وجود تطابق واضح. لا نعرض مسافات أو ترتيبًا حسب القرب بدون بيانات حقيقية.'
                      : 'يمكنك إكمال المحافظة والمدينة/المديرية من مسار الخطة بدون تسجيل دخول.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                if (!hasLocation) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: onCompleteLocation,
                      icon: const Icon(Icons.place_outlined, size: 18),
                      label: const Text('إكمال الموقع'),
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

class _QuoteRequestsOverview extends StatelessWidget {
  const _QuoteRequestsOverview({
    required this.quotes,
    required this.includesAccountData,
    required this.onOpenPlanCenter,
  });

  final List<QuoteRequest> quotes;
  final bool includesAccountData;
  final void Function(QuoteRequest quote) onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final pending = quotes
        .where((quote) => quote.lifecycleStatus == 'PENDING_PROVIDER')
        .length;
    final received = quotes
        .where((quote) => quote.lifecycleStatus == 'RECEIVED')
        .length;
    final accepted = quotes
        .where((quote) => quote.lifecycleStatus == 'ACCEPTED')
        .length;
    final visibleQuotes = quotes.take(3).toList();

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dCard2,
      border: Border.all(color: AppTheme.dLine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.request_quote_outlined, color: AppTheme.dMaroon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلبات العروض والردود',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!includesAccountData)
            const _QuoteOverviewMessage(
              text: 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود',
            )
          else if (quotes.isEmpty)
            const _QuoteOverviewMessage(text: 'لم ترسل أي طلب عرض بعد')
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuoteCount(label: 'بانتظار الرد', value: pending),
                _QuoteCount(label: 'عروض وصلت', value: received),
                _QuoteCount(label: 'مقبولة', value: accepted),
              ],
            ),
            const SizedBox(height: 10),
            for (final quote in visibleQuotes) ...[
              _QuoteRequestTile(
                quote: quote,
                onOpenPlanCenter: () => onOpenPlanCenter(quote),
              ),
              if (quote != visibleQuotes.last)
                const Divider(height: 18, color: AppTheme.dLine),
            ],
          ],
        ],
      ),
    );
  }
}

class _QuoteOverviewMessage extends StatelessWidget {
  const _QuoteOverviewMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.dInkSoft,
        fontWeight: FontWeight.w800,
        height: 1.45,
      ),
    );
  }
}

class _QuoteRequestTile extends StatelessWidget {
  const _QuoteRequestTile({
    required this.quote,
    required this.onOpenPlanCenter,
  });

  final QuoteRequest quote;
  final VoidCallback onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final providerName = _quoteProviderLabel(quote);
    final serviceName = _quoteServiceLabel(quote);
    final amount = _quoteAmountLabel(quote);
    final nextAction = _quoteNextActionLabel(quote);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount == null ? serviceName : '$serviceName · $amount',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextAction,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        if (quote.weddingPlanId?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onOpenPlanCenter,
              icon: const Icon(Icons.event_note_outlined, size: 18),
              label: const Text('فتح مركز الخطة'),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuoteCount extends StatelessWidget {
  const _QuoteCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: AppTheme.dInkSoft,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.id, this.label);

  final String id;
  final String label;
}

class _MenuFilterChip extends StatelessWidget {
  const _MenuFilterChip({
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final List<_FilterOption> items;
  final Future<void> Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('الكل')),
        for (final item in items)
          PopupMenuItem<String?>(value: item.id, child: Text(item.label)),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18, color: AppTheme.dMaroon),
        label: Text(label),
        backgroundColor: AppTheme.dCard2,
        side: const BorderSide(color: AppTheme.dLine),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.location});

  final int count;
  final WeddingLocationDraft? location;

  @override
  Widget build(BuildContext context) {
    final title = location?.hasRequiredLocation == true
        ? 'موردون ضمن مدينة ${location!.shortLabel}'
        : 'الموردون المتاحون';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AarastStatusPill(label: '$count مورد', color: AppTheme.dMaroon),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
    required this.onRequestQuote,
  });

  final MarketplaceProvider provider;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final category = service?.category?.nameAr.trim();
    final serviceTitle = service?.title.trim();
    final location = _providerLocationLabel(provider);
    final hasRating = provider.ratingCount > 0;

    return AarastCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProviderImage(url: provider.coverUrl ?? provider.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        provider.businessName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.dInk,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'حفظ المورد',
                      onPressed: onFavorite,
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? AppTheme.dMaroon
                            : AppTheme.dInkSoft,
                      ),
                    ),
                  ],
                ),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dMaroon,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (serviceTitle != null && serviceTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    serviceTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hasRating)
                      _ProviderFactPill(
                        icon: Icons.star_rounded,
                        text:
                            '${provider.ratingAverage.toStringAsFixed(1)} (${provider.ratingCount})',
                        color: AppTheme.dGoldDeep,
                      ),
                    if (location != null)
                      _ProviderFactPill(
                        icon: Icons.place_outlined,
                        text: location,
                        color: AppTheme.dInkSoft,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('التفاصيل'),
                    ),
                    FilledButton.icon(
                      key: Key('super5-provider-quote-${provider.id}'),
                      onPressed: onRequestQuote,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.request_quote_outlined, size: 18),
                      label: const Text('طلب عرض'),
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

class _ProviderFactPill extends StatelessWidget {
  const _ProviderFactPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderImage extends StatelessWidget {
  const _ProviderImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: 84,
        height: 84,
        color: AppTheme.dCreamBg,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: AppTheme.dGoldDeep,
                size: 34,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 34,
                ),
              ),
      ),
    );
  }
}

List<String> _cleanLabels(List<String> labels) {
  final seen = <String>{};
  final cleaned = <String>[];
  for (final raw in labels) {
    final label = raw.trim();
    if (label.isEmpty) continue;
    final key = _normalizeArabicLabel(label);
    if (seen.add(key)) cleaned.add(label);
  }
  return cleaned;
}

bool _looselySameArabicLabel(String left, String right) {
  final a = _normalizeArabicLabel(left);
  final b = _normalizeArabicLabel(right);
  if (a.isEmpty || b.isEmpty) return false;
  return a == b || a.contains(b) || b.contains(a);
}

String _normalizeArabicLabel(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[إأآا]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

int _offersReceivedCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) {
    return quote.lifecycleStatus == 'RECEIVED' ||
        quote.lifecycleStatus == 'ACCEPTED' ||
        quote.lifecycleStatus == 'REJECTED' ||
        quote.offers.isNotEmpty;
  }).length;
}

int _acceptedProviderCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) => quote.lifecycleStatus == 'ACCEPTED').length;
}

int _pendingDecisionCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) => quote.canAcceptOrReject).length;
}

List<QuoteRequest> _importantQuotes(List<QuoteRequest> quotes) {
  return quotes
      .where(
        (quote) =>
            quote.canAcceptOrReject ||
            quote.lifecycleStatus == 'RECEIVED' ||
            quote.lifecycleStatus == 'PENDING_PROVIDER',
      )
      .take(2)
      .toList();
}

String _quoteProviderLabel(QuoteRequest quote) {
  final providerName = quote.provider?.businessName.trim();
  if (providerName != null && providerName.isNotEmpty) return providerName;
  return 'طلب عرض';
}

String _quoteServiceLabel(QuoteRequest quote) {
  final serviceTitle = quote.service?.title.trim();
  if (serviceTitle != null && serviceTitle.isNotEmpty) return serviceTitle;
  final category = quote.service?.category?.nameAr.trim();
  if (category != null && category.isNotEmpty) return category;
  return 'خدمة غير محددة';
}

String? _quoteAmountLabel(QuoteRequest quote) {
  final offer = quote.acceptedOffer ?? quote.pendingOffer;
  final amount = offer?.amount?.trim();
  if (amount == null || amount.isEmpty) return null;
  final currency = offer?.currency?.trim();
  if (currency == null || currency.isEmpty) return amount;
  return '$amount $currency';
}

String _quoteNextActionLabel(QuoteRequest quote) {
  if (quote.canAcceptOrReject) {
    return 'افتح مركز الخطة لقبول أو رفض العرض. لا يوجد حجز أو دفع داخل التطبيق.';
  }
  if (quote.lifecycleStatus == 'ACCEPTED') {
    return 'العرض مقبول. افتح مركز الخطة لإضافة مصروف أو دين عند الحاجة. لن يُنشأ أي سجل تلقائيًا.';
  }
  if (quote.lifecycleStatus == 'PENDING_PROVIDER') {
    return 'بانتظار رد المورد. لا توجد إجراءات مالية حتى يصل عرض حقيقي.';
  }
  if (quote.lifecycleStatus == 'READY_TO_SEND') {
    return 'هذا طلب قديم غير مرسل. أعد الإرسال عند توفر الاتصال والخادم.';
  }
  return 'تابع حالة الطلب من مركز الخطة عند الحاجة.';
}

String? _providerLocationLabel(MarketplaceProvider provider) {
  final city = provider.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) return city;
  final address = provider.address?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dLine),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Icon(icon, color: AppTheme.dMaroon),
      ),
    );
  }
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 134,
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg,
      border: Border.all(color: AppTheme.danger.withAlpha(60)),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
