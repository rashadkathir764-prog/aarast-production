import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
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
                    message: _emptyProvidersMessage(
                      budgetIntent: provider.budgetMatchIntent,
                      location: _weddingLocation,
                    ),
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
                  ] else if (provider.budgetMatchIntent != null) ...[
                    _NoBudgetMatchesCard(
                      intent: provider.budgetMatchIntent!,
                      onClear: provider.clearBudgetMatch,
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
                      onTap: () =>
                          context.push(AppRouter.providerDetails(item.id)),
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
