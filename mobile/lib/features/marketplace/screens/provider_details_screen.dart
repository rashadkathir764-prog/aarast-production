import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContext, AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../data/provider_contact_links.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart'
    show budgetItemForCategories;
import '../providers/marketplace_provider.dart';
import '../widgets/provider_details_view.dart';

part 'provider_details_screen.widgets.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({
    required this.providerId,
    this.weddingPlanId,
    this.returnQuoteToMarketplace = false,
    super.key,
  });

  final String providerId;
  final String? weddingPlanId;
  final bool returnQuoteToMarketplace;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  bool _quoteContextReady = false;
  bool _isReturningQuoteToMarketplace = false;
  final Set<String> _routeLaunchesInFlight = <String>{};
  String? _countedViewProviderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadDetails();
      if (mounted) setState(() => _quoteContextReady = true);
    });
  }

  @override
  void didUpdateWidget(covariant ProviderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.weddingPlanId != widget.weddingPlanId) {
      _quoteContextReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadDetails();
        if (mounted) setState(() => _quoteContextReady = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = _matchingSelectedPlanId(selected);
    // «ضمن بندك» follows the plan's money items, read once if Money has not.
    final finance = context.watch<FinanceProvider?>();
    if (selectedPlanId != null &&
        finance != null &&
        finance.loadedPlanId != selectedPlanId &&
        !finance.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && finance.loadedPlanId != selectedPlanId) {
          unawaited(finance.loadMoney(selectedPlanId));
        }
      });
    }
    final providerFailedToLoad = context
        .select<ProviderMarketplaceProvider, bool>(
          (marketplace) =>
              marketplace.providerDetails(widget.providerId) == null &&
              marketplace.detailsErrorFor(widget.providerId) != null,
        );
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      backgroundColor: AarastV3Color.canvas,
      // A provider that failed to load has nothing to ask a quote from.
      bottomNavigationBar: providerFailedToLoad
          ? null
          : _quoteFooter(selectedPlanId),
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, state, _) {
          final provider = state.providerDetails(widget.providerId);
          final services = state.servicesFor(widget.providerId);
          final detailsError = state.detailsErrorFor(widget.providerId);
          final detailsLoading = state.isProviderQuoteContextLoading(
            widget.providerId,
          );
          void retry() => state.loadProviderDetails(
            widget.providerId,
            weddingPlanId: selectedPlanId,
          );

          if (detailsLoading && provider == null) {
            return const _DetailsFrame(
              child: JourneyListState(
                phase: JourneyListPhase.loading,
                section: JourneySection.providers,
              ),
            );
          }
          if (detailsError != null && provider == null) {
            return _DetailsFrame(
              child: JourneyListState(
                phase: JourneyListPhase.error,
                section: JourneySection.providers,
                onRetry: retry,
              ),
            );
          }
          if (provider == null) {
            return const _DetailsFrame(
              child: JourneyListState(
                phase: JourneyListPhase.empty,
                section: JourneySection.providers,
                emptyTitle: 'المزود هذا مو موجود',
                emptyMessage: 'ما لقينا صفحته، يمكن انشالت من الدليل.',
              ),
            );
          }

          return ProviderDetailsView(
            provider: provider,
            services: services,
            packages: state.packagesFor(widget.providerId),
            reviews: state.reviewsFor(widget.providerId),
            portfolio: state.portfolioFor(widget.providerId),
            onBack: () {
              if (context.canPop()) context.pop();
            },
            onOpenOffer: provider.isClaimed
                ? (serviceId) => _pushOnce(
                    AppRouter.providerQuote(provider.id),
                    extra: serviceId,
                  )
                : null,
            withinBudget: _withinBudget(provider, services, selectedPlanId),
            dataSaver: context.watch<DevicePreferences?>()?.dataSaver ?? false,
            // The page, its services or its packages failed to refresh.
            detailsErrorMessage:
                detailsError ??
                state.servicesErrorFor(widget.providerId) ??
                state.packagesErrorFor(widget.providerId),
            onRetryDetails: detailsLoading ? null : retry,
          );
        },
      ),
    );
  }

  /// «ضمن بندك» on f03: the plan's item for this kind of service has an
  /// amount, and the provider's lowest price in riyals fits it.
  bool _withinBudget(
    MarketplaceProvider provider,
    List<MarketplaceService> services,
    String? planId,
  ) {
    final finance = context.read<FinanceProvider?>();
    if (planId == null || finance?.loadedPlanId != planId) return false;
    // G40: the item this provider's offers land in, as the server lists it.
    final item = budgetItemForCategories(
      finance!.categories,
      (item) => finance.providerCategoryIdsFor(item.id),
      [
        provider.primaryCategory?.id ?? provider.primaryCategoryId,
        for (final service in services) service.category?.id,
      ],
    );
    final allocated = num.tryParse(item?.allocatedAmount ?? '') ?? 0;
    if (allocated <= 0) return false;
    final prices = [
      for (final service in services)
        if (currencyCodeFromDisplayInput(service.currency) ==
            defaultCurrencyCode)
          ?num.tryParse(service.basePrice?.replaceAll(',', '') ?? ''),
    ];
    if (prices.isEmpty) return false;
    final lowest = prices.reduce((a, b) => a < b ? a : b);
    return lowest <= allocated;
  }

  Future<void> _loadDetails() async {
    final hasAccount = await _hasAccount();
    if (!mounted) return;
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final selectedPlanId = hasAccount
        ? _matchingSelectedPlanId(selected)
        : null;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    marketplace.configureAccountScope(
      includeAccountData: hasAccount,
      weddingPlanId: selectedPlanId,
    );
    await marketplace.loadProviderDetails(
      widget.providerId,
      weddingPlanId: selectedPlanId,
    );
    _countView(marketplace);
  }

  /// Once per opened provider, and never the provider's own preview of
  /// their listing (V1 checklist 4.19).
  void _countView(ProviderMarketplaceProvider marketplace) {
    if (!mounted || _countedViewProviderId == widget.providerId) return;
    if (marketplace.providerDetails(widget.providerId) == null) return;
    final contexts =
        context.read<AccountContextController?>()?.contexts ?? const [];
    if (contexts.any((item) => item.providerId == widget.providerId)) return;
    _countedViewProviderId = widget.providerId;
    marketplace.recordProviderView(widget.providerId);
  }

  Future<bool> _hasAccount() async {
    try {
      return await AuthActionGuard.hasAccount(context);
    } on ProviderNotFoundException {
      // Public provider previews and isolated route tests do not mount the
      // account storage. They may browse public details, but never receive
      // account-scoped quotes.
      return false;
    }
  }

  String? _matchingSelectedPlanId(AccountContext? selected) {
    if (selected?.isPlan != true) return null;
    final selectedPlanId = selected?.weddingPlanId?.toString().trim();
    if (selectedPlanId == null || selectedPlanId.isEmpty) return null;
    final requestedPlanId = widget.weddingPlanId?.trim();
    if (requestedPlanId != null &&
        requestedPlanId.isNotEmpty &&
        requestedPlanId != selectedPlanId) {
      return null;
    }
    return selectedPlanId;
  }

  Future<T?> _pushOnce<T>(String location, {Object? extra}) async {
    if (!mounted || !_routeLaunchesInFlight.add(location)) return null;
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      _routeLaunchesInFlight.remove(location);
    }
  }

  void _openPrimaryQuoteAction(BuildContext context, QuoteRequest? quote) {
    if (quote == null ||
        quote.status == 'CANCELLED' ||
        quote.status == 'REJECTED' ||
        quote.hasExpiredOffer) {
      _pushOnce(AppRouter.providerQuote(widget.providerId));
      return;
    }
    if (quote.status == 'SENT' || quote.status == 'VIEWED') {
      _openQuoteConversation(quote.id);
      return;
    }
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final selectedPlanId = selected?.isPlan == true
        ? selected?.weddingPlanId
        : null;
    final quotePlanId = quote.weddingPlanId?.trim();
    if (selectedPlanId == null ||
        (quotePlanId != null &&
            quotePlanId.isNotEmpty &&
            quotePlanId != selectedPlanId)) {
      AarastToast.showError(
        context,
        'هذا العرض لا يطابق مسار الخطة المحدد حاليًا.',
      );
      return;
    }
    if (_returnQuoteToMarketplace(
      ProviderMarketplaceRouteResult.focusQuote(quote.id),
    )) {
      return;
    }
    _pushOnce(AppRouter.planProviders(selectedPlanId, quoteId: quote.id));
  }

  Future<void> _openQuoteConversation(String quoteId) async {
    final result = await _pushOnce<ProviderMarketplaceRouteResult>(
      AppRouter.quoteConversation(quoteId),
      extra: widget.returnQuoteToMarketplace
          ? ProviderMarketplaceLaunchOrigin.ownerMainShellProviders
          : null,
    );
    if (!mounted || result == null) return;
    _returnQuoteToMarketplace(result);
  }

  bool _returnQuoteToMarketplace(ProviderMarketplaceRouteResult result) {
    if (!widget.returnQuoteToMarketplace) return false;
    if (_isReturningQuoteToMarketplace) return true;
    if (!context.canPop()) return false;
    _isReturningQuoteToMarketplace = true;
    context.pop(result);
    return true;
  }
}
