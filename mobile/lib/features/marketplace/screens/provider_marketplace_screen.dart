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
import '../models/provider_budget_match_intent.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

class ProviderMarketplaceScreen extends StatefulWidget {
  const ProviderMarketplaceScreen({
    this.embedded = false,
    this.initialBudgetIntent,
    super.key,
  });

  final bool embedded;
  final ProviderBudgetMatchIntent? initialBudgetIntent;

  @override
  State<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState extends State<ProviderMarketplaceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  WeddingLocationDraft? _weddingLocation;
  String? _weddingLocationPlanId;

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
      final budgetIntent = widget.initialBudgetIntent;
      if (budgetIntent != null && mounted) {
        await provider.applyBudgetMatchIntent(budgetIntent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProviderMarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBudgetIntent != widget.initialBudgetIntent) {
      final budgetIntent = widget.initialBudgetIntent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || budgetIntent == null) return;
        context.read<ProviderMarketplaceProvider>().applyBudgetMatchIntent(
          budgetIntent,
        );
      });
    }
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
            color: AppTheme.burgundy,
            onRefresh: provider.loadMarketplace,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.embedded ? 18 : 20,
                16,
                widget.embedded ? 124 : 28,
              ),
              children: [
                _TopMarketplaceCommandCard(
                  embedded: widget.embedded,
                  provider: provider,
                ),
                if (!provider.includesAccountData) ...[
                  const SizedBox(height: 12),
                  const _LoginRequiredCard(),
                ],
                const SizedBox(height: 14),
                _MarketplaceSearch(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  provider: provider,
                ),

                if (_weddingLocation != null &&
                    !_weddingLocation!.hasRequiredLocation) ...[
                  const SizedBox(height: 12),
                  _LocationContextCard(
                    location: _weddingLocation,
                    onCompleteLocation: _openLocationCompletion,
                  ),
                ],
                if (provider.budgetMatchIntent != null) ...[
                  const SizedBox(height: 12),
                  _BudgetMatchContextCard(
                    intent: provider.budgetMatchIntent!,
                    categoryName: _activeCategoryName(provider),
                    onClear: provider.clearBudgetMatch,
                  ),
                ],
                if (provider.quoteRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ImportantNowCard(
                    quotes: provider.quoteRequests,
                    includesAccountData: provider.includesAccountData,
                    onOpenPlanCenter: _openPlanCenterForQuote,
                  ),
                ],
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
                  if (provider.budgetMatchIntent != null &&
                      provider.budgetMatchedServices.isNotEmpty) ...[
                    _BudgetMatchedServicesSection(
                      intent: provider.budgetMatchIntent!,
                      services: provider.budgetMatchedServices,
                      onOpenProvider: (providerId) =>
                          context.push(AppRouter.providerDetails(providerId)),
                      onRequestQuote: (service) => context.push(
                        AppRouter.providerQuote(service.providerId),
                        extra: ProviderQuoteInitialContext(
                          serviceId: service.id,
                          budgetIntent: provider.budgetMatchIntent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
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

class _TopMarketplaceCommandCard extends StatelessWidget {
  const _TopMarketplaceCommandCard({
    required this.embedded,
    required this.provider,
  });

  final bool embedded;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final quotes = provider.quoteRequests;
    final offersReceived = _offersReceivedCount(quotes);
    final acceptedProviders = _acceptedProviderCount(quotes);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الموردون والعروض',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AarastStatusPill(
                      label: provider.includesAccountData
                          ? 'حساب محفوظ'
                          : 'تصفح عام',
                      color: AppTheme.gold,
                      backgroundColor: AppTheme.goldSoft,
                      icon: provider.includesAccountData
                          ? Icons.verified_user_outlined
                          : Icons.visibility_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'تصفّح المزودين واطلب عرض سعر عند الحاجة. لا يوجد حجز أو دفع داخل هذه الشاشة.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (provider.includesAccountData)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MiniStat(
                    label: 'طلبات مرسلة',
                    value: quotes.length.toString(),
                    color: AppTheme.muted,
                  ),
                  _MiniStat(
                    label: 'عروض وصلت',
                    value: offersReceived.toString(),
                    color: AppTheme.gold,
                  ),
                  _MiniStat(
                    label: 'عروض مقبولة',
                    value: acceptedProviders.toString(),
                    color: AppTheme.success,
                  ),
                ],
              ),
            )
          else
            const _PublicBrowseNote(),
        ],
      ),
    );
  }
}

class _PublicBrowseNote extends StatelessWidget {
  const _PublicBrowseNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ivory.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: AppTheme.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'التصفح مفتوح للجميع. إرسال طلب عرض ومتابعة الردود يحتاج حسابًا محفوظًا.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
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
    if (important.isEmpty) return const SizedBox.shrink();

    final title = 'أهم ما يحتاج قرار الآن';
    final message = !includesAccountData
        ? 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود.'
        : 'راجع العروض الواصلة أو الطلبات المنتظرة بناءً على بيانات حسابك.';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high_rounded, color: AppTheme.burgundy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
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
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          for (final quote in important) ...[
            _ImportantQuoteRow(
              quote: quote,
              onOpenPlanCenter: () => onOpenPlanCenter(quote),
            ),
            if (quote != important.last)
              const Divider(height: 18, color: AppTheme.border),
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
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(
            Icons.request_quote_outlined,
            color: AppTheme.burgundy,
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
                        color: AppTheme.ink,
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
                  color: AppTheme.muted,
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

class _BudgetMatchContextCard extends StatelessWidget {
  const _BudgetMatchContextCard({
    required this.intent,
    required this.categoryName,
    required this.onClear,
  });

  final ProviderBudgetMatchIntent intent;
  final String? categoryName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final budgetLabel = intent.hasBudget
        ? '${_formatMoney(intent.allocatedValue)} ر.ي'
        : 'بدون مبلغ محدد';
    final rangeLabel = intent.hasBudget
        ? '${_formatMoney(intent.minPrice!)} - ${_formatMoney(intent.maxPrice!)} ر.ي'
        : 'حسب فئة البند فقط';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حسب ميزانية بند ${intent.budgetCategoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName == null
                      ? '$budgetLabel · $rangeLabel'
                      : '$categoryName · $budgetLabel · $rangeLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إزالة فلتر الميزانية',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _BudgetMatchedServicesSection extends StatelessWidget {
  const _BudgetMatchedServicesSection({
    required this.intent,
    required this.services,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final List<MarketplaceService> services;
  final ValueChanged<String> onOpenProvider;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'خدمات مناسبة لهذا البند',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 10),
        for (final service in services.take(5)) ...[
          _BudgetMatchedServiceCard(
            intent: intent,
            service: service,
            onOpenProvider: () => onOpenProvider(service.providerId),
            onRequestQuote: () => onRequestQuote(service),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BudgetMatchedServiceCard extends StatelessWidget {
  const _BudgetMatchedServiceCard({
    required this.intent,
    required this.service,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final MarketplaceService service;
  final VoidCallback onOpenProvider;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final price = _moneyValueOrNull(service.basePrice);
    final status = _serviceBudgetStatus(intent, price);
    final color = _serviceBudgetStatusColor(status);
    final providerName = service.provider?.businessName ?? 'مورد';
    final categoryName = service.category?.nameAr;
    final matchReason = _serviceBudgetReason(intent, service, price, status);

    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withValues(alpha: 0.20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(Icons.design_services_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AarastStatusPill(
                label: _serviceBudgetStatusLabel(status),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ProviderFactPill(
                icon: Icons.payments_outlined,
                text: price == null
                    ? 'السعر غير محدد'
                    : '${_formatMoney(price)} ${service.currency ?? 'ر.ي'}',
                color: color,
              ),
              if (categoryName != null && categoryName.trim().isNotEmpty)
                _ProviderFactPill(
                  icon: Icons.category_outlined,
                  text: categoryName,
                  color: AppTheme.burgundy,
                ),
              if (service.city != null)
                _ProviderFactPill(
                  icon: Icons.place_outlined,
                  text: service.city!.nameAr,
                  color: AppTheme.muted,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: color,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    matchReason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenProvider,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('التفاصيل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRequestQuote,
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('طلب عرض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            color: AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أضف موقع الزفاف لتحسين تصفية المدينة',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onCompleteLocation,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('إكمال الموقع'),
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
    if (quotes.isEmpty) return const SizedBox.shrink();

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
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.request_quote_outlined,
                color: AppTheme.burgundy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلبات العروض والردود',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              const Divider(height: 18, color: AppTheme.border),
          ],
        ],
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
                  color: AppTheme.ink,
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
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextAction,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.muted,
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
        color: AppTheme.muted,
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
        avatar: Icon(icon, size: 18, color: AppTheme.burgundy),
        label: Text(label),
        backgroundColor: AppTheme.surface,
        side: const BorderSide(color: AppTheme.border),
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
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AarastStatusPill(label: '$count مورد', color: AppTheme.burgundy),
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
                              color: AppTheme.ink,
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
                        color: isFavorite ? AppTheme.burgundy : AppTheme.muted,
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
                      color: AppTheme.burgundy,
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
                      color: AppTheme.muted,
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
                        color: AppTheme.gold,
                      ),
                    if (location != null)
                      _ProviderFactPill(
                        icon: Icons.place_outlined,
                        text: location,
                        color: AppTheme.muted,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
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
                color: AppTheme.muted,
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
        color: AppTheme.ivory,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: AppTheme.gold,
                size: 34,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.gold,
                  size: 34,
                ),
              ),
      ),
    );
  }
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

String? _activeCategoryName(ProviderMarketplaceProvider provider) {
  final id = provider.categoryId;
  if (id == null) return null;
  for (final category in provider.categories) {
    if (category.id == id) return category.nameAr;
  }
  return null;
}

_ServiceBudgetStatus _serviceBudgetStatus(
  ProviderBudgetMatchIntent intent,
  double? price,
) {
  if (price == null) return _ServiceBudgetStatus.unknown;
  if (!intent.hasBudget) return _ServiceBudgetStatus.categoryOnly;
  if (price >= intent.minPrice! && price <= intent.maxPrice!) {
    return _ServiceBudgetStatus.inRange;
  }
  if (price <= intent.allocatedValue) return _ServiceBudgetStatus.underBudget;
  return _ServiceBudgetStatus.nearby;
}

String _serviceBudgetStatusLabel(_ServiceBudgetStatus status) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => 'ضمن النطاق',
    _ServiceBudgetStatus.underBudget => 'أقل من ميزانيتك',
    _ServiceBudgetStatus.nearby => 'أقرب المتاح',
    _ServiceBudgetStatus.categoryOnly => 'نفس الفئة',
    _ServiceBudgetStatus.unknown => 'السعر غير محدد',
  };
}

Color _serviceBudgetStatusColor(_ServiceBudgetStatus status) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => AppTheme.success,
    _ServiceBudgetStatus.underBudget => AppTheme.burgundy,
    _ServiceBudgetStatus.nearby => AppTheme.gold,
    _ServiceBudgetStatus.categoryOnly => AppTheme.burgundy,
    _ServiceBudgetStatus.unknown => AppTheme.muted,
  };
}

String _serviceBudgetReason(
  ProviderBudgetMatchIntent intent,
  MarketplaceService service,
  double? price,
  _ServiceBudgetStatus status,
) {
  final pieces = <String>[];
  if (intent.hasBudget && price != null) {
    final difference = price - intent.allocatedValue;
    final absDifference = difference.abs();
    final amount = _formatMoney(absDifference);
    switch (status) {
      case _ServiceBudgetStatus.inRange:
        pieces.add('السعر قريب من المبلغ الذي خصصته لهذا البند.');
      case _ServiceBudgetStatus.underBudget:
        pieces.add('أقل من ميزانيتك بحوالي $amount ر.ي.');
      case _ServiceBudgetStatus.nearby:
        pieces.add('أعلى من ميزانيتك بحوالي $amount ر.ي، لكنه من أقرب المتاح.');
      case _ServiceBudgetStatus.categoryOnly:
      case _ServiceBudgetStatus.unknown:
        pieces.add('نفس نوع البند، لكن السعر يحتاج تأكيد من المورد.');
    }
  } else if (intent.hasBudget) {
    pieces.add('نفس نوع البند، لكن السعر غير منشور ويحتاج طلب عرض.');
  } else {
    pieces.add('مطابق لفئة البند، وأضف مبلغاً لتحسين الترتيب.');
  }

  final city = service.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) {
    pieces.add('متاح في $city.');
  }

  return pieces.join(' ');
}

double? _moneyValueOrNull(String? value) {
  final raw = value?.replaceAll(',', '').trim();
  if (raw == null || raw.isEmpty) return null;
  return double.tryParse(raw);
}

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

enum _ServiceBudgetStatus {
  inRange,
  underBudget,
  nearby,
  categoryOnly,
  unknown,
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
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Icon(icon, color: AppTheme.burgundy),
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
              color: AppTheme.surface.withAlpha(180),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
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
      color: AppTheme.burgundySoft,
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

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(Icons.login_rounded, color: AppTheme.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'طلبات العروض ومتابعتها تحتاج تسجيل دخول',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
