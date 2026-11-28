import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../widgets/plan_read_bookings.dart';
import '../widgets/provider_result_card.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, GuestPersona, WeddingLocationDraft;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        DashboardSummaryProvider,
        PlanReadBooking,
        PlanReadViewProvider,
        WeddingPlansProvider;
import '../../chat/chat_api.dart' show ChatProvider, ConversationListView;
import '../../finance/finance_api.dart' show CostDraftIntent, FinanceProvider;
import '../data/booking_moment_ledger.dart';
import '../models/marketplace_models.dart';
import '../models/provider_board.dart';
import '../models/provider_portfolio.dart' show PublicPortfolioPhoto;
import '../models/provider_shelves.dart' show ProviderShelf;
import '../widgets/provider_board_view.dart';
import '../widgets/provider_hard_case_card.dart';
import '../widgets/provider_prices.dart';
import '../models/provider_budget_match_intent.dart';
import '../providers/marketplace_provider.dart';

part 'provider_marketplace_screen.sections.dart';
part 'provider_marketplace_screen.results.dart';
part 'provider_marketplace_screen.labels.dart';
part 'provider_marketplace_screen.participant.dart';
part 'provider_marketplace_screen.tabs.dart';

/// f08: a conversation shows the icon of the service it is about.
IconData _conversationIcon(String? serviceTitle) =>
    providerServiceIcon(serviceTitle ?? '');

/// The four tabs of «المزوّدون», in the order they are drawn.
enum ProvidersTab { directory, requests, chats, favorites }

class ProviderMarketplaceScreen extends StatefulWidget {
  const ProviderMarketplaceScreen({
    this.embedded = false,
    this.weddingPlanId,
    this.initialBudgetIntent,
    this.initialQuoteId,
    this.preserveOwnerShellOnQuoteFocus = false,
    super.key,
  });

  final bool embedded;
  final String? weddingPlanId;
  final ProviderBudgetMatchIntent? initialBudgetIntent;
  final String? initialQuoteId;
  final bool preserveOwnerShellOnQuoteFocus;

  @override
  State<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState extends State<ProviderMarketplaceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Set<String> _routeLaunchesInFlight = <String>{};
  WeddingLocationDraft? _weddingLocation;
  String? _weddingLocationPlanId;
  String? _focusedQuoteId;

  /// The tab chosen by hand; null lets the plan's state choose (D72).
  ProvidersTab? _tab;

  /// The tab the screen opened on, settled once the plan's requests have
  /// been read, so it never moves on its own after the reader's eye settled.
  ProvidersTab? _settledOpening;
  bool _chatsLoaded = false;

  /// The conversations read once for «المحادثات 2» (no live connection).
  bool _chatCountRead = false;

  /// Whether this reader has an account, once asked; null until answered.
  bool? _hasAccount;

  /// x22 gives way to the tabs once a way to start was picked, kept on the
  /// phone per plan (the shell rebuilds this screen on every tab switch).
  bool _firstVisitLeft = false;

  static String _firstVisitKey(String planId) =>
      'aarast_providers_start_left:$planId';

  /// The confirmed bookings last checked for y09.
  String? _momentSignature;

  /// f09's picks for the comparison; null until the reader picks.
  List<String>? _comparePicked;

  /// Saved providers whose page was read for its prices (f09).
  final Set<String> _favoritePricesAsked = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    _searchController.addListener(_onSearchTyped);
    _weddingLocationPlanId = _normalizedPlanId(widget.weddingPlanId);
    _focusedQuoteId = _normalizedPlanId(widget.initialQuoteId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ProviderMarketplaceProvider>();
      // A search kept from before shows its box with it.
      setState(() => _searchController.text = provider.search);
      final includeAccountData = await AuthActionGuard.hasAccount(context);
      if (!mounted) return;
      setState(() => _hasAccount = includeAccountData);
      final startPlanId = _weddingLocationPlanId;
      if (startPlanId != null) {
        final preferences = await SharedPreferences.getInstance();
        if (!mounted) return;
        if (preferences.getBool(_firstVisitKey(startPlanId)) ?? false) {
          setState(() => _firstVisitLeft = true);
        }
      }
      provider.configureCatalogAudience(
        await _catalogAudienceForSession(hasAccount: includeAccountData),
      );
      if (!mounted) return;
      final selectedPlanId = includeAccountData
          ? _selectedPlanIdForAccount()
          : null;
      provider.configureAccountScope(
        includeAccountData: includeAccountData,
        weddingPlanId: selectedPlanId,
      );
      await provider.loadMarketplace(
        includeAccountData: includeAccountData,
        weddingPlanId: selectedPlanId,
        updateQuoteScope: true,
      );
      if (!mounted) return;
      await _loadRequestedQuote(provider, selectedPlanId: selectedPlanId);
      if (!mounted) return;
      setState(
        () => _settledOpening = _openingTab(
          provider,
          planMode: _weddingLocationPlanId != null,
        ),
      );
      await _loadWeddingLocationContext(
        hasAccount: includeAccountData,
        marketplace: provider,
      );
      if (mounted) _loadParticipantPlan();
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final hasAccount = await AuthActionGuard.hasAccount(context);
        if (!mounted) return;
        final selectedPlanId = hasAccount ? _selectedPlanIdForAccount() : null;
        final provider = context.read<ProviderMarketplaceProvider>();
        provider.configureAccountScope(
          includeAccountData: hasAccount,
          weddingPlanId: selectedPlanId,
        );
        await provider.loadMarketplace(
          includeAccountData: hasAccount,
          weddingPlanId: selectedPlanId,
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
      _focusedQuoteId = _normalizedPlanId(widget.initialQuoteId);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final hasAccount = await AuthActionGuard.hasAccount(context);
        if (!mounted) return;
        await _loadRequestedQuote(
          context.read<ProviderMarketplaceProvider>(),
          selectedPlanId: hasAccount ? _selectedPlanIdForAccount() : null,
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
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchTyped)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The tabs and the search are states inside one route: Android back
    // undoes them before it leaves the providers (RA-MO-05).
    final opening = _settledOpening ?? ProvidersTab.directory;
    final awayFromOpening = _tab != null && _tab != opening;
    final nested = _searchShown || awayFromOpening;
    return TabBackStep(
      nested: nested,
      onBack: () {
        if (_searchShown) {
          _clearSearch(context.read<ProviderMarketplaceProvider>());
          return;
        }
        setState(() => _tab = null);
      },
      child: AarastScreenFrame(
        safeAreaBottom: false,
        backgroundColor: AarastV3Color.canvas,
        child: Consumer<ProviderMarketplaceProvider>(
          builder: (context, provider, _) {
            // The tab row follows the plan, not the arrival of its data, so
            // it is drawn once and never goes from one tab to four under the
            // reader's finger (RA-MO-256: a guest's plan has no chats and no
            // favourites, both kept in an account).
            final planMode =
                _weddingLocationPlanId != null && _hasAccount != null;
            final tabs = !planMode
                ? const [ProvidersTab.directory]
                : _hasAccount == true
                ? ProvidersTab.values
                : const [ProvidersTab.directory, ProvidersTab.requests];
            final board = planMode
                ? _board(provider)
                : const <ProviderBoardRow>[];
            final selected =
                _tab ??
                _settledOpening ??
                _openingTab(provider, planMode: planMode);
            final tab = tabs.contains(selected) ? selected : tabs.first;
            if (planMode) _checkNewBookings(provider);
            // x22: nothing asked, booked or saved yet; null while not known.
            final bool? firstVisit = tab == ProvidersTab.requests
                ? _firstVisitOf(provider, board)
                : false;
            final top = _top(
              provider: provider,
              board: board,
              tabs: tabs,
              tab: tab,
              planMode: planMode,
              firstVisit: firstVisit,
            );
            return switch (tab) {
              ProvidersTab.directory => _directoryTab(provider, top),
              ProvidersTab.favorites => _favoritesTab(provider, top),
              _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  top,
                  Expanded(
                    child: switch (tab) {
                      ProvidersTab.requests when firstVisit == true =>
                        _firstVisitView(provider, tabs),
                      ProvidersTab.requests when firstVisit == null =>
                        _firstVisitPending(),
                      ProvidersTab.requests => _boardTab(provider, board, tabs),
                      _ => ConversationListView(
                        embedded: true,
                        onExplore: () => _selectTab(ProvidersTab.directory),
                        iconFor: _conversationIcon,
                        planId: _conversationsPlanId(context),
                      ),
                    },
                  ),
                ],
              ),
            };
          },
        ),
      ),
    );
  }

  /// The title with its status, then the tabs: they scroll away with the
  /// directory and the favourites (REFINEMENT_SPEC 2.7).
  Widget _top({
    required ProviderMarketplaceProvider provider,
    required List<ProviderBoardRow> board,
    required List<ProvidersTab> tabs,
    required ProvidersTab tab,
    required bool planMode,
    required bool? firstVisit,
  }) {
    final gender = context.gender;
    // Over the directory and the favourites the requests' line stays only
    // when it says something to act on («محجوز 2 من 5»، «عرض ينتظرك»); its
    // generic «اختر مزوّديك» said nothing their lists do not.
    final quiet =
        planMode &&
        (tab == ProvidersTab.directory || tab == ProvidersTab.favorites) &&
        !board.any((row) => row.booked || row.waitingOffers > 0) &&
        _participantBookings()?.isNotEmpty != true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Density.pageHorizontal,
        AarastV3Space.x1,
        AarastV3Density.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JourneyTabHeader(
            title: aarastText.providersTitle,
            status: quiet
                ? ''
                : firstVisit == null
                ? aarastText.providersHeaderLoading
                : firstVisit
                ? aarastText.providersHeaderNothingAsked(gender)
                : planMode
                ? _boardStatus(board)
                : aarastText.providersHeaderBrowse(gender),
            onStatusTap:
                !quiet &&
                    planMode &&
                    firstVisit == false &&
                    board.any(
                      (row) => row.quotes.any((quote) => quote.booking != null),
                    )
                ? () => _openBookings(provider, board)
                : null,
            statusTapLabel: aarastText.providersHeaderBookings,
          ),
          if (tabs.length > 1 && firstVisit == false)
            JourneyTabSwitch(
              key: const ValueKey('providers-tabs'),
              labels: [for (final item in tabs) _tabLabel(context, item)],
              selected: tabs.indexOf(tab),
              color: context.accent.primary,
              onSelected: (index) => _selectTab(tabs[index]),
            ),
        ],
      ),
    );
  }

  String _tabLabel(BuildContext context, ProvidersTab tab) => switch (tab) {
    ProvidersTab.directory => aarastText.providersTabDirectory,
    ProvidersTab.requests => aarastText.providersTabRequests,
    ProvidersTab.chats => _chatsLabel(context),
    ProvidersTab.favorites => aarastText.providersTabFavorites,
  };

  void _leaveFirstVisit() {
    setState(() => _firstVisitLeft = true);
    final planId = _weddingLocationPlanId;
    if (planId == null) return;
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setBool(_firstVisitKey(planId), true),
      ),
    );
  }

  /// y09: a booking the provider confirmed since this phone last looked
  /// opens its moment, once.
  void _checkNewBookings(ProviderMarketplaceProvider marketplace) {
    final planId = _weddingLocationPlanId;
    if (planId == null ||
        marketplace.isLoading ||
        marketplace.quoteRequestsErrorMessage != null) {
      return;
    }
    final quotes = marketplace.quotesForPlan(planId);
    if (quotes.isEmpty) return;
    final confirmed = [
      for (final quote in quotes)
        if (quote.booking?.lifecycleStatus == 'CONFIRMED') quote,
    ];
    final signature = [
      planId,
      for (final quote in confirmed) quote.booking!.id,
    ].join(',');
    if (signature == _momentSignature) return;
    _momentSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ledger = BookingMomentLedger(await SharedPreferences.getInstance());
      final unseen = await ledger.unseen(
        planId,
        confirmed.map((quote) => quote.booking!.id),
      );
      if (unseen.isEmpty) return;
      for (final bookingId in unseen) {
        await ledger.markSeen(planId, bookingId);
      }
      if (!mounted) return;
      final quote = confirmed.firstWhere(
        (quote) => quote.booking!.id == unseen.first,
      );
      await _pushOnce<void>(AppRouter.bookingMoment(planId, quote.id));
    });
  }

  /// f09: a box picks a saved provider to compare; a third pick lets go of
  /// the first, and one of another kind starts a new pair with it.
  void _togglePick(
    MarketplaceProvider provider,
    List<String> picked,
    List<MarketplaceProvider> favorites,
  ) {
    final id = provider.id;
    final next = [...picked];
    if (!next.remove(id)) {
      next.removeWhere(
        (other) => favorites.any(
          (saved) => saved.id == other && saved.differsInKindFrom(provider),
        ),
      );
      next.add(id);
      if (next.length > 2) next.removeAt(0);
    }
    setState(() => _comparePicked = next);
  }

  /// A search typed in the box: Android back clears it first.
  bool get _searchShown => _searchController.text.trim().isNotEmpty;

  bool _searchWasShown = false;

  /// The search runs a moment after the typing stops (Rashad's phone
  /// 2026-11-18: waiting for the keyboard's key read as broken).
  Timer? _searchDebounce;
  static const _searchPause = Duration(milliseconds: 450);

  void _onSearchTyped() {
    if (!mounted) return;
    final text = _searchController.text.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchPause, () {
      if (!mounted) return;
      final marketplace = context.read<ProviderMarketplaceProvider>();
      if (marketplace.search.trim() != text) marketplace.setSearch(text);
    });
    final shown = _searchShown;
    if (shown == _searchWasShown) return;
    setState(() => _searchWasShown = shown);
  }

  void _clearSearch(ProviderMarketplaceProvider provider) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {});
    provider.setSearch('');
  }

  Future<void> _toggleFavorite(
    ProviderMarketplaceProvider provider,
    String id,
  ) async {
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
      context,
      message: aarastText.providersFavoriteNeedsAccount(context.gender),
    )) {
      return;
    }
    final failure = await provider.toggleFavorite(id);
    if (failure != null && mounted) {
      AarastToast.showError(context, aarastText.providersFavoriteFailed);
    }
  }

  /// Where the tab opens: «طلباتي» while a request is under way, or one was
  /// opened from outside; else the directory.
  ProvidersTab _openingTab(
    ProviderMarketplaceProvider provider, {
    required bool planMode,
  }) {
    final planId = _weddingLocationPlanId;
    if (!planMode || planId == null) return ProvidersTab.directory;
    if (_focusedQuoteId != null) return ProvidersTab.requests;
    return hasRequestUnderWay(provider.quotesForPlan(planId))
        ? ProvidersTab.requests
        : ProvidersTab.directory;
  }

  void _selectTab(ProvidersTab tab) {
    setState(() => _tab = tab);
    if (tab == ProvidersTab.chats && !_chatsLoaded) {
      _chatsLoaded = true;
      context.read<ChatProvider>().initialize();
    }
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    final provider = context.read<ProviderMarketplaceProvider>();
    // The shelves are whole on their own; only the rows read on.
    if (provider.showsWholeDirectory) return;
    provider.loadMoreProviders();
  }

  bool _hasDirectoryFilters(ProviderMarketplaceProvider marketplace) {
    return marketplace.cityId != null ||
        marketplace.categoryId != null ||
        marketplace.budgetMatchIntent != null ||
        marketplace.hideBusy ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _clearMarketplaceFilters(
    ProviderMarketplaceProvider marketplace,
  ) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {});
    await marketplace.clearFilters();
  }

  Future<void> _loadWeddingLocationContext({
    required bool hasAccount,
    required ProviderMarketplaceProvider marketplace,
  }) async {
    WeddingLocationDraft? location;
    String? planId;
    DateTime? weddingDate;
    final requestedPlanId = _normalizedPlanId(widget.weddingPlanId);
    GuestOnboardingStorage? guestStorage;
    WeddingPlansProvider? weddingPlans;

    if (hasAccount) {
      final selected = context
          .read<AccountContextController?>()
          ?.selectedContext;
      final selectedPlanId = selected?.isPlan == true
          ? selected?.weddingPlanId
          : null;
      final scopedPlanId =
          requestedPlanId == null || requestedPlanId == selectedPlanId
          ? selectedPlanId
          : null;
      try {
        weddingPlans = context.read<WeddingPlansProvider>();
      } on ProviderNotFoundException {
        // Browsing works without a plan.
      }
      if (weddingPlans != null && scopedPlanId != null) {
        var scopedPlan = weddingPlans.selectedPlan?.id == scopedPlanId
            ? weddingPlans.selectedPlan
            : null;
        if (scopedPlan == null) {
          await weddingPlans.loadWeddingPlan(scopedPlanId);
          if (weddingPlans.selectedPlan?.id == scopedPlanId) {
            scopedPlan = weddingPlans.selectedPlan;
          }
        }
        if (scopedPlan == null) {
          // The plan could not be read: the tab is still that plan's, only
          // its place is unknown, so the directory starts without a city.
          planId = scopedPlanId;
        } else if (scopedPlan.status.toUpperCase() != 'ARCHIVED') {
          location = scopedPlan.weddingLocation;
          planId = scopedPlan.id;
          weddingDate = scopedPlan.weddingDate;
        }
      }
    } else {
      try {
        guestStorage = context.read<GuestOnboardingStorage>();
      } on ProviderNotFoundException {
        // Public browsing works without a plan on the phone.
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
    });
    // RA-BE-150: the wedding day goes with the list; one reload covers it
    // and the city.
    final dayChanged = marketplace.setEventDate(weddingDate);
    if (matchingCityId != null && marketplace.cityId == null) {
      await marketplace.setCity(matchingCityId);
    } else if (dayChanged) {
      await marketplace.loadMarketplace();
    }
  }

  Future<String?> _catalogAudienceForSession({required bool hasAccount}) async {
    if (hasAccount) {
      final selected = context
          .read<AccountContextController?>()
          ?.selectedContext;
      if (selected?.isPlan != true) return null;
      return selected?.persona?.name;
    }
    try {
      final guestPlan = await context
          .read<GuestOnboardingStorage>()
          .loadGuestPlan();
      return switch (guestPlan?.persona) {
        GuestPersona.groom => 'GROOM',
        GuestPersona.bride => 'BRIDE',
        GuestPersona.helper => null,
        null => null,
      };
    } on ProviderNotFoundException {
      return null;
    }
  }

  String? _normalizedPlanId(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<T?> _pushOnce<T>(String location, {Object? extra}) async {
    if (!mounted || !_routeLaunchesInFlight.add(location)) return null;
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      _routeLaunchesInFlight.remove(location);
    }
  }

  Future<void> _openProviderDetails(String providerId) async {
    final result = await _pushOnce<ProviderMarketplaceRouteResult>(
      AppRouter.providerDetails(
        providerId,
        weddingPlanId: _weddingLocationPlanId,
      ),
      extra: widget.preserveOwnerShellOnQuoteFocus
          ? ProviderMarketplaceLaunchOrigin.ownerMainShellProviders
          : null,
    );
    await _applyRouteResult(result);
  }

  Future<void> _applyRouteResult(ProviderMarketplaceRouteResult? result) async {
    final quoteId = _normalizedPlanId(result?.quoteId);
    if (!mounted || quoteId == null) return;
    setState(() => _focusedQuoteId = quoteId);
    await _loadRequestedQuote(
      context.read<ProviderMarketplaceProvider>(),
      selectedPlanId: _selectedPlanIdForAccount(),
    );
  }

  Future<void> _loadRequestedQuote(
    ProviderMarketplaceProvider marketplace, {
    required String? selectedPlanId,
  }) async {
    final quoteId = _focusedQuoteId?.trim();
    if (selectedPlanId == null || quoteId == null || quoteId.isEmpty) return;
    final loaded = await marketplace.loadQuoteRequest(
      quoteId,
      expectedWeddingPlanId: selectedPlanId,
    );
    if (!loaded || !mounted) return;
    // A notification about this request opens its service page.
    _focusedQuoteId = null;
    await _pushOnce(
      AppRouter.providerRequests(selectedPlanId, quoteId: quoteId),
    );
  }

  Future<void> _refreshMarketplace(
    ProviderMarketplaceProvider marketplace,
  ) async {
    final hasAccount = await AuthActionGuard.hasAccount(context);
    if (!mounted) return;
    final selectedPlanId = hasAccount ? _selectedPlanIdForAccount() : null;
    marketplace.configureAccountScope(
      includeAccountData: hasAccount,
      weddingPlanId: selectedPlanId,
    );
    await marketplace.loadMarketplace(
      includeAccountData: hasAccount,
      weddingPlanId: selectedPlanId,
      updateQuoteScope: true,
    );
  }

  /// «المحادثات 2»: this plan's unread messages on the tab (Rashad
  /// 2026-11-18), read once when the providers open.
  String _chatsLabel(BuildContext context) {
    if (!_chatCountRead) {
      _chatCountRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ChatProvider?>()?.loadConversations();
      });
    }
    final planId = _conversationsPlanId(context);
    final conversations =
        context.watch<ChatProvider?>()?.conversations ?? const [];
    final unread = conversations
        .where(
          (conversation) =>
              planId == null || conversation.weddingPlan?.id == planId,
        )
        .fold<int>(0, (sum, item) => sum + item.unreadMessageCount);
    return unread > 0
        ? aarastText.providersTabChatsUnread(unread)
        : aarastText.providersTabChats;
  }

  String? _conversationsPlanId(BuildContext context) {
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    return _planIdOf(selected?.isPlan == true ? selected?.weddingPlanId : null);
  }

  String? _selectedPlanIdForAccount() {
    final selected = context.read<AccountContextController?>()?.selectedContext;
    return _planIdOf(selected?.isPlan == true ? selected?.weddingPlanId : null);
  }

  String? _planIdOf(String? openPlanId) {
    final selectedPlanId = _normalizedPlanId(openPlanId);
    if (selectedPlanId == null) return null;
    final requestedPlanId = _normalizedPlanId(widget.weddingPlanId);
    if (requestedPlanId != null && requestedPlanId != selectedPlanId) {
      return null;
    }
    return selectedPlanId;
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
      _pushOnce(AppRouter.planCenter(planId));
      return;
    }
    _pushOnce(AppRouter.onboarding);
  }
}
