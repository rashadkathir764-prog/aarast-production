import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/phone/phone_links.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContext, AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../../wedding_plans/wedding_plans_api.dart' show WeddingPlansProvider;
import '../data/provider_contact_links.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart'
    show budgetItemForCategories, priceFitsItem;
import '../providers/marketplace_provider.dart';
import '../widgets/provider_details_view.dart';
import '../widgets/provider_result_card.dart' show planDayIsPast;
import '../widgets/review_report_sheet.dart' show reportProviderReview;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(covariant ProviderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.weddingPlanId != widget.weddingPlanId) {
      _quoteContextReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  Future<void> _open() async {
    if (!mounted) return;
    await _loadDetails();
    if (mounted) setState(() => _quoteContextReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = _matchingSelectedPlanId(selected);
    // Opened by a link or after signing in there is no page behind it.
    void back() => context.popOrGo(
      selectedPlanId == null
          ? AppRouter.providerMarketplace
          : AppRouter.planProviders(selectedPlanId),
    );
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
    // No provider on the page (still read, not reached, or not there): no
    // footer asks him for a quote.
    final providerFailedToLoad = context
        .select<ProviderMarketplaceProvider, bool>(
          (marketplace) =>
              marketplace.providerDetails(widget.providerId) == null,
        );
    return AarastScreenFrame(
      safeAreaBottom: false,
      backgroundColor: AarastV3Color.canvas,
      bottomNavigationBar: providerFailedToLoad
          ? null
          : _quoteFooter(selectedPlanId),
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, state, _) {
          final id = widget.providerId;
          final provider = state.providerDetails(id);
          final services = state.servicesFor(id);
          final detailsError = state.detailsErrorFor(id);
          final detailsLoading = state.isProviderQuoteContextLoading(id);
          void retry() =>
              state.loadProviderDetails(id, weddingPlanId: selectedPlanId);

          if (provider == null) {
            return _DetailsFrame(
              onBack: back,
              // The read starts after the first frame: until it has run,
              // nothing is known, and «لم نجد هذا المزوّد» is not said (it
              // flashed on every open of a provider the list had not read).
              phase: detailsLoading || !_quoteContextReady
                  ? JourneyListPhase.loading
                  : detailsError != null
                  ? JourneyListPhase.error
                  : JourneyListPhase.empty,
              onRetry: retry,
            );
          }
          return ProviderDetailsView(
            eventDate: state.eventDate,
            bookedByReader: state.providersBookedByReader.contains(provider.id),
            provider: provider,
            services: services,
            packages: state.packagesFor(id),
            reviews: state.reviewsFor(id),
            reviewSummary: state.reviewSummaryFor(id),
            hasMoreReviews: state.hasMoreReviews(id),
            loadingMoreReviews: state.isLoadingMoreReviews(id),
            onLoadMoreReviews: () => _loadMoreReviews(state, id),
            portfolio: state.portfolioFor(id),
            onBack: back,
            onOpenOffer:
                provider.isClaimed && _dayBlock(state, provider) == null
                ? (serviceId) => _pushOnce(
                    AppRouter.providerQuote(provider.id),
                    extra: serviceId,
                  )
                : null,
            withinBudget: _withinBudget(provider, services, selectedPlanId),
            dataSaver: context.watch<DevicePreferences?>()?.dataSaver ?? false,
            // The page or one of its sections did not refresh (RA-MO-254).
            detailsErrorMessage:
                detailsError ??
                state.detailSectionsErrorFor(id) ??
                state.servicesErrorFor(id) ??
                state.packagesErrorFor(id),
            onRetryDetails: detailsLoading ? null : retry,
            onReportReview: _reportReview,
            readerUserId: context.watch<AuthController?>()?.user?.id,
            isFavorite: state.favoriteProviderIds.contains(provider.id),
            onFavorite: () => _toggleFavorite(state, provider.id),
          );
        },
      ),
    );
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
    // The page opened first (from an agreement in the money tab, a link):
    // the directory has not told the list the plan's wedding day nor read
    // the saved providers. The heart then drew empty on a saved provider,
    // and the day line stayed out with «اطلب عرض سعر» open on a closed day.
    if (selectedPlanId != null && marketplace.eventDate == null) {
      final plans = context.read<WeddingPlansProvider?>();
      if (plans != null && plans.selectedPlan?.id != selectedPlanId) {
        await plans.loadWeddingPlan(selectedPlanId);
        if (!mounted) return;
      }
      final plan = plans?.selectedPlan;
      if (plan != null &&
          plan.id == selectedPlanId &&
          plan.status.toUpperCase() != 'ARCHIVED') {
        marketplace.setEventDate(plan.weddingDate);
      }
    }
    if (hasAccount && !marketplace.accountDataRead) {
      unawaited(marketplace.loadFavoriteProviders());
    }
    await marketplace.loadProviderDetails(
      widget.providerId,
      weddingPlanId: selectedPlanId,
    );
    _countView(marketplace);
  }

  /// Once per opened provider, never the provider's own preview (4.19).
  void _countView(ProviderMarketplaceProvider marketplace) {
    if (!mounted || _countedViewProviderId == widget.providerId) return;
    if (marketplace.providerDetails(widget.providerId) == null) return;
    final contexts =
        context.read<AccountContextController?>()?.contexts ?? const [];
    if (contexts.any((item) => item.providerId == widget.providerId)) return;
    _countedViewProviderId = widget.providerId;
    marketplace.recordProviderView(widget.providerId);
  }

  /// The heart: the favourites are kept in an account, as on the cards.
  Future<void> _toggleFavorite(
    ProviderMarketplaceProvider marketplace,
    String providerId,
  ) async {
    final blocked = await AuthActionGuard.blockProtectedSubmitWithoutAccount(
      context,
      message: aarastText.providersFavoriteNeedsAccount(context.gender),
    );
    if (blocked || !mounted) return;
    final failure = await marketplace.toggleFavorite(providerId);
    if (failure != null && mounted) {
      AarastToast.showError(context, aarastText.providersFavoriteFailed);
    }
  }

  /// RA-ST-05 (D94): a report is from an account, and reaches the team.
  Future<void> _reportReview(ProviderReview review) async {
    final allowed = await AuthActionGuard.requireAccount(
      context,
      reason: aarastText.providersReviewNeedsAccount(context.gender),
    );
    if (allowed && mounted) await reportProviderReview(context, review.id);
  }

  Future<bool> _hasAccount() async {
    try {
      return await AuthActionGuard.hasAccount(context);
    } on ProviderNotFoundException {
      // Public previews and isolated tests mount no account storage: they
      // browse public details and never receive account-scoped quotes.
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
    if (quote == null || providerFooterAsksForNewQuote(quote)) {
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
      AarastToast.showError(context, aarastText.providersOtherPlanOffer);
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
