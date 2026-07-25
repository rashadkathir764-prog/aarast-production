import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../finance/providers/finance_provider.dart';
import '../widgets/premium/premium_vendor_card.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

part 'provider_marketplace_screen.sections.dart';
part 'provider_marketplace_screen.results.dart';
part 'provider_marketplace_screen.labels.dart';

class ProviderMarketplaceScreen extends StatefulWidget {
  const ProviderMarketplaceScreen({
    this.embedded = false,
    this.weddingPlanId,
    this.initialBudgetIntent,
    this.initialQuoteId,
    super.key,
  });

  final bool embedded;
  final String? weddingPlanId;
  final ProviderBudgetMatchIntent? initialBudgetIntent;
  final String? initialQuoteId;

  @override
  State<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState extends State<ProviderMarketplaceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  WeddingLocationDraft? _weddingLocation;
  String? _weddingLocationPlanId;
  bool _planContextResolved = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    _weddingLocationPlanId = _normalizedPlanId(widget.weddingPlanId);
    _planContextResolved = _weddingLocationPlanId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ProviderMarketplaceProvider>();
      _searchController.text = provider.search;
      final includeAccountData = await AuthActionGuard.hasAccount(context);
      if (!mounted) return;
      await provider.loadMarketplace(
        includeAccountData: includeAccountData,
        weddingPlanId: widget.weddingPlanId,
        updateQuoteScope: true,
      );
      if (!mounted) return;
      await _loadRequestedQuote(provider, hasAccount: includeAccountData);
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
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      _weddingLocationPlanId = _normalizedPlanId(widget.weddingPlanId);
      _planContextResolved = _weddingLocationPlanId != null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final hasAccount = await AuthActionGuard.hasAccount(context);
        if (!mounted) return;
        await context.read<ProviderMarketplaceProvider>().loadMarketplace(
          includeAccountData: hasAccount,
          weddingPlanId: widget.weddingPlanId,
          updateQuoteScope: true,
        );
        if (!mounted) return;
        await _loadWeddingLocationContext(
          hasAccount: hasAccount,
          marketplace: context.read<ProviderMarketplaceProvider>(),
        );
      });
    }
    if (oldWidget.initialQuoteId != widget.initialQuoteId) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final hasAccount = await AuthActionGuard.hasAccount(context);
        if (!mounted) return;
        await _loadRequestedQuote(
          context.read<ProviderMarketplaceProvider>(),
          hasAccount: hasAccount,
        );
      });
    }
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
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
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
          final quoteRequests = _visibleQuoteRequests(provider);
          return RefreshIndicator(
            color: AppTheme.burgundy,
            onRefresh: () => provider.loadMarketplace(
              weddingPlanId: widget.weddingPlanId,
              updateQuoteScope: true,
            ),
            child: ListView(
              controller: _scrollController,
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
                  quotes: quoteRequests,
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
                if (quoteRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OffersInboxCard(
                    quotes: quoteRequests,
                    initialQuoteId: widget.initialQuoteId,
                    isSubmitting: provider.isSubmitting,
                    onAccept: _acceptQuote,
                    onReject: _rejectQuote,
                    onViewCost: _viewAcceptedQuoteCost,
                    onCreateNew: (quote) =>
                        context.push(AppRouter.providerQuote(quote.providerId)),
                  ),
                ],
                if (provider.includesAccountData &&
                    provider.quoteRequestsErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(
                    title: 'تعذر تحميل عروض الأسعار',
                    message: provider.quoteRequestsErrorMessage!,
                    onRetry: provider.loadScopedQuoteRequests,
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
                    icon: LucideIcons.store,
                    title: 'لا يوجد موردون متاحون حاليًا',
                    message: _emptyProvidersMessage(
                      budgetIntent: provider.budgetMatchIntent,
                      location: _weddingLocation,
                    ),
                    action: OutlinedButton.icon(
                      onPressed: () => _clearMarketplaceFilters(provider),
                      icon: const Icon(LucideIcons.slidersHorizontal),
                      label: const Text('مسح الفلاتر'),
                    ),
                  )
                else ...[
                  if (provider.budgetMatchIntent != null &&
                      provider.budgetMatchedServices.isNotEmpty) ...[
                    _BudgetMatchedServicesSection(
                      intent: provider.budgetMatchIntent!,
                      services: provider.budgetMatchedServices,
                      onOpenProvider: (providerId) => context.push(
                        AppRouter.providerDetails(
                          providerId,
                          weddingPlanId: _weddingLocationPlanId,
                        ),
                      ),
                      onRequestQuote: (service) => context.push(
                        AppRouter.providerQuote(service.providerId),
                        extra: ProviderQuoteInitialContext(
                          serviceId: service.id,
                          budgetIntent: provider.budgetMatchIntent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else if (provider.budgetMatchIntent != null) ...[
                    _NoBudgetMatchesCard(
                      intent: provider.budgetMatchIntent!,
                      onClear: provider.clearBudgetMatch,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _ResultsHeader(
                    count: provider.totalProviders,
                    cityLabel: _selectedCityName(provider),
                  ),
                  const SizedBox(height: 12),
                  for (final item in provider.providers) ...[
                    _ProviderCard(
                      provider: item,
                      budgetIntent: provider.budgetMatchIntent,
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
                      onTap: () => context.push(
                        AppRouter.providerDetails(
                          item.id,
                          weddingPlanId: _weddingLocationPlanId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (provider.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: AarastInlineSpinner(dimension: 36)),
                    )
                  else if (provider.loadMoreErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ErrorCard(
                        title: 'تعذر تحميل المزيد',
                        message: provider.loadMoreErrorMessage!,
                        onRetry: provider.loadMoreProviders,
                      ),
                    )
                  else if (provider.hasMoreProviders)
                    Center(
                      child: TextButton(
                        key: const Key('providers-load-more'),
                        onPressed: provider.loadMoreProviders,
                        child: const Text('تحميل المزيد'),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    context.read<ProviderMarketplaceProvider>().loadMoreProviders();
  }

  Future<void> _clearMarketplaceFilters(
    ProviderMarketplaceProvider marketplace,
  ) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    await marketplace.clearFilters();
  }

  Future<void> _loadWeddingLocationContext({
    required bool hasAccount,
    required ProviderMarketplaceProvider marketplace,
  }) async {
    WeddingLocationDraft? location;
    String? planId;
    final requestedPlanId = _normalizedPlanId(widget.weddingPlanId);
    GuestOnboardingStorage? guestStorage;
    WeddingPlansProvider? weddingPlans;

    if (hasAccount) {
      try {
        weddingPlans = context.read<WeddingPlansProvider>();
      } on ProviderNotFoundException {
        // Marketplace browsing can still work without plan context.
      }
      if (weddingPlans != null) {
        if (weddingPlans.activePlan == null) {
          await weddingPlans.loadActiveWeddingPlan();
        }
        final activePlan = weddingPlans.activePlan;
        if (activePlan != null &&
            activePlan.status.toUpperCase() != 'ARCHIVED' &&
            (requestedPlanId == null || requestedPlanId == activePlan.id)) {
          location = activePlan.weddingLocation;
          planId = activePlan.id;
        } else if (requestedPlanId != null) {
          var requestedPlan = weddingPlans.selectedPlan?.id == requestedPlanId
              ? weddingPlans.selectedPlan
              : null;
          if (requestedPlan == null) {
            for (final candidate in weddingPlans.plans) {
              if (candidate.id == requestedPlanId) {
                requestedPlan = candidate;
                break;
              }
            }
          }
          if (requestedPlan == null) {
            await weddingPlans.loadWeddingPlan(requestedPlanId);
            if (weddingPlans.selectedPlan?.id == requestedPlanId) {
              requestedPlan = weddingPlans.selectedPlan;
            }
          }
          if (requestedPlan != null &&
              requestedPlan.status.toUpperCase() != 'ARCHIVED') {
            location = requestedPlan.weddingLocation;
            planId = requestedPlan.id;
          }
        }
      } else {
        // Isolated widgets may provide an explicit already-scoped plan id.
        planId = requestedPlanId;
      }
    } else {
      try {
        guestStorage = context.read<GuestOnboardingStorage>();
      } on ProviderNotFoundException {
        // Public browsing can work without a local guest-plan context.
      }
      if (guestStorage != null) {
        final guestPlan = await guestStorage.loadGuestPlan();
        final guestLocation = guestPlan?.weddingLocation;
        if (guestLocation?.hasAnyLocation == true) {
          location = guestLocation;
          planId = guestPlan?.guestPlanId;
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
      _planContextResolved = true;
    });
    if (matchingCityId != null && marketplace.cityId == null) {
      await marketplace.setCity(matchingCityId);
    }
  }

  List<QuoteRequest> _visibleQuoteRequests(
    ProviderMarketplaceProvider marketplace,
  ) {
    final planId = _weddingLocationPlanId;
    if (planId != null) return marketplace.quotesForPlan(planId);
    if (!_planContextResolved) return const [];

    final prioritizedId = widget.initialQuoteId?.trim();
    if (prioritizedId == null || prioritizedId.isEmpty) return const [];
    return marketplace.quoteRequests
        .where((quote) => quote.id == prioritizedId)
        .toList(growable: false);
  }

  String? _normalizedPlanId(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _loadRequestedQuote(
    ProviderMarketplaceProvider marketplace, {
    required bool hasAccount,
  }) async {
    final quoteId = widget.initialQuoteId?.trim();
    if (!hasAccount || quoteId == null || quoteId.isEmpty) return;
    await marketplace.loadQuoteRequest(quoteId);
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

  // القبول من مكانه — الخادم يفحص الصلاحيات، ونحن نعرض النتيجة بصدق.
  Future<void> _acceptQuote(QuoteRequest quote) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final accepted = await marketplace.acceptQuote(quote);
    if (!mounted) return;
    if (!accepted) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر قبول عرض السعر.',
      );
      return;
    }
    final planId = quote.weddingPlanId?.trim();
    if (planId != null && planId.isNotEmpty) {
      await context.read<FinanceProvider?>()?.loadMoney(planId);
      if (!mounted) return;
    }
    AarastToast.showSuccess(
      context,
      'تم قبول العرض وإضافة التكلفة إلى تبويب المال.',
    );
  }

  Future<void> _rejectQuote(QuoteRequest quote) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final rejected = await marketplace.rejectQuote(quote);
    if (!mounted) return;
    if (!rejected) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر رفض عرض السعر.',
      );
      return;
    }
    AarastToast.showSuccess(context, 'تم رفض العرض.');
  }

  void _viewAcceptedQuoteCost(QuoteRequest quote) {
    final planId = quote.weddingPlanId?.trim();
    final costId = quote.costSuggestion?.costId?.trim();
    if (planId == null || planId.isEmpty || costId == null || costId.isEmpty) {
      AarastToast.showError(context, 'تعذر فتح التكلفة المرتبطة بهذا العرض.');
      return;
    }
    context.push(AppRouter.moneyCostDetails(planId, costId));
  }
}
