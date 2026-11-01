import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
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
import '../widgets/provider_board_view.dart';
import '../widgets/provider_details_view.dart' show providerPriceRange;
import '../widgets/provider_hard_case_card.dart';
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
  int _tab = 0;
  bool _chatsLoaded = false;

  /// x22 gives way to the tabs once a way to start was picked.
  bool _firstVisitLeft = false;

  /// The confirmed bookings last checked for y09, so each change is
  /// looked at once.
  String? _momentSignature;

  /// f09's picks for «قارن الملفين»; null until the person picks.
  List<String>? _comparePicked;

  /// Saved providers whose page was read for its prices (f09).
  final Set<String> _favoritePricesAsked = {};

  /// f02 has no search box of its own: the header's search opens one.
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    _weddingLocationPlanId = _normalizedPlanId(widget.weddingPlanId);
    _focusedQuoteId = _normalizedPlanId(widget.initialQuoteId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ProviderMarketplaceProvider>();
      // A search kept from before shows its box with it.
      setState(() => _searchController.text = provider.search);
      final includeAccountData = await AuthActionGuard.hasAccount(context);
      if (!mounted) return;
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      backgroundColor: AarastV3Color.canvas,
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, provider, _) {
          // f01: the plan's own requests come first; without a plan (or an
          // account) the tab is the directory alone.
          final planMode =
              _weddingLocationPlanId != null && provider.includesAccountData;
          final tabs = planMode
              ? const ['طلباتي', 'استكشف', 'المحادثات', 'المفضلة']
              : const ['استكشف'];
          final tab = _tab.clamp(0, tabs.length - 1);
          final board = planMode
              ? _board(provider)
              : const <ProviderBoardRow>[];
          if (planMode) _checkNewBookings(provider);
          // x22: nothing asked, booked or saved yet, so the tab is where to
          // start, not an empty board.
          // Null while that is not known yet.
          final bool? firstVisit = tabs[tab] == 'طلباتي'
              ? _firstVisitOf(provider, board)
              : false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.embedded ? 12 : 16,
                  16,
                  0,
                ),
                child: JourneyTabHeader(
                  title: 'المزودين',
                  status: firstVisit != false
                      ? context.say('ما طلبت من أحد بعد', 'ما طلبتِ من أحد بعد')
                      : planMode
                      ? _boardStatus(board)
                      : context.say(
                          'دوّر على مزودين عرسك',
                          'دوّري على مزودين عرسك',
                        ),
                  onStatusTap:
                      planMode &&
                          firstVisit == false &&
                          board.any(
                            (row) => row.quotes.any(
                              (quote) => quote.booking != null,
                            ),
                          )
                      ? () => _openBookings(provider, tabs, board)
                      : null,
                  statusTapLabel: 'الحجوزات',
                  actions: [
                    if (firstVisit == false)
                      JourneyRoundButton(
                        key: const ValueKey('providers-search'),
                        icon: _searchShown && tabs[tab] == 'استكشف'
                            ? LucideIcons.x
                            : LucideIcons.search,
                        tooltip: _searchShown && tabs[tab] == 'استكشف'
                            ? context.say('سكّر البحث', 'سكّري البحث')
                            : context.say('دوّر على مزود', 'دوّري على مزود'),
                        onPressed: () => _toggleSearch(provider, tabs, tab),
                      ),
                  ],
                ),
              ),
              if (tabs.length > 1 && firstVisit == false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: JourneyTabSwitch(
                    key: const ValueKey('providers-tabs'),
                    labels: tabs,
                    selected: tab,
                    color: context.accent.primary,
                    onSelected: (index) => _selectTab(tabs[index], tabs),
                  ),
                ),
              Expanded(
                child: switch (tabs[tab]) {
                  'طلباتي' when firstVisit == true => _firstVisitView(
                    provider,
                    tabs,
                  ),
                  'طلباتي' when firstVisit == null => _firstVisitPending(),
                  'طلباتي' => _boardTab(provider, board, tabs),
                  'المحادثات' => const ConversationListView(
                    embedded: true,
                    iconFor: _conversationIcon,
                  ),
                  'المفضلة' => _favoritesTab(provider),
                  _ => _exploreTab(provider),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _leaveFirstVisit() => setState(() => _firstVisitLeft = true);

  /// y09: once the plan's requests are loaded, a booking the provider
  /// confirmed since this phone last looked opens its moment. Several at
  /// once open the first and count as seen together.
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

  /// f09: a box picks a provider to compare; a third pick lets go of the
  /// one picked first.
  void _togglePick(String id, List<String> picked) {
    final next = [...picked];
    if (!next.remove(id)) {
      next.add(id);
      if (next.length > 2) next.removeAt(0);
    }
    setState(() => _comparePicked = next);
  }

  bool get _searchShown =>
      _searchOpen || _searchController.text.trim().isNotEmpty;

  /// The header's search: on «استكشف» it opens and closes the box; on the
  /// other tabs it moves to «استكشف» with the box open.
  void _toggleSearch(
    ProviderMarketplaceProvider provider,
    List<String> tabs,
    int tab,
  ) {
    if (tabs[tab] == 'استكشف' && _searchShown) {
      final hadText = _searchController.text.trim().isNotEmpty;
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() => _searchOpen = false);
      if (hadText) provider.setSearch('');
      return;
    }
    _selectTab('استكشف', tabs);
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  /// f02: the directory results, or why there are none.
  List<Widget> _exploreResults(ProviderMarketplaceProvider provider) {
    return [
      if (provider.errorMessage != null && provider.providers.isEmpty)
        JourneyListState(
          key: const ValueKey('marketplace-directory-error'),
          phase: JourneyListPhase.error,
          section: JourneySection.providers,
          onRetry: provider.loadMarketplace,
        )
      else if (provider.isLoading && provider.providers.isEmpty)
        const JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.providers,
        )
      else if (provider.providers.isEmpty && !_hasDirectoryFilters(provider))
        // Nothing is filtered, so "change the filters" would be
        // a false lead: the directory itself is empty.
        JourneyListState(
          key: const ValueKey('marketplace-directory-empty'),
          phase: JourneyListPhase.empty,
          section: JourneySection.providers,
          emptyTitle: 'ما في مزودين في الدليل بعد',
          emptyMessage:
              'أول ما يسجّل مزودين ويعتمدهم فريق اعّرست، بيظهرون هنا. '
              '${context.say('تعرف مزود؟ قل له', 'تعرفين مزود؟ قولي له')} يسجّل في اعّرست.',
        )
      else if (provider.providers.isEmpty)
        JourneyListState(
          key: const ValueKey('marketplace-filtered-empty'),
          phase: JourneyListPhase.empty,
          section: JourneySection.providers,
          emptyIcon: LucideIcons.searchX,
          emptyTitle: _searchController.text.trim().isNotEmpty
              ? 'ما لقينا مزود بهذا الاسم'
              : 'ما لقينا مزودين بهذا الفلتر',
          emptyMessage: _emptyProvidersMessage(
            budgetIntent: provider.budgetMatchIntent,
            location: _weddingLocation,
            profile: context.journeyProfile,
            shownAmount:
                context.watch<FinanceProvider?>()?.shownAmount ??
                (text) => text,
          ),
          emptyAction: context.say('امسح الفلتر', 'امسحي الفلتر'),
          onEmptyAction: () => _clearMarketplaceFilters(provider),
        )
      else ...[
        if (provider.errorMessage != null) ...[
          JourneyListNotice(offline: false, onRetry: provider.loadMarketplace),
          const SizedBox(height: 12),
        ],
        // f02: the cards alone; each says where it stands against the item.
        for (final item in provider.providers) ...[
          _ProviderCard(
            provider: item,
            budgetIntent: provider.budgetMatchIntent,
            isFavorite: provider.favoriteProviderIds.contains(item.id),
            onFavorite: () async {
              if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
                context,
              )) {
                return;
              }
              final failure = await provider.toggleFavorite(item.id);
              if (failure != null && mounted) {
                AarastToast.showError(context, failure);
              }
            },
            onTap: () => _openProviderDetails(item.id),
          ),
          const SizedBox(height: 12),
        ],
        if (provider.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: AarastInlineSpinner(dimension: 36)),
          )
        else if (provider.loadMoreErrorMessage != null)
          JourneyListNotice(
            key: const ValueKey('providers-load-more-error'),
            offline: false,
            onRetry: provider.loadMoreProviders,
          )
        else if (provider.hasMoreProviders)
          Center(
            child: JourneyTextAction(
              key: const Key('providers-load-more'),
              label: 'اعرض أكثر',
              icon: LucideIcons.chevronDown,
              color: context.accent.primary,
              onPressed: provider.loadMoreProviders,
            ),
          ),
      ],
    ];
  }

  void _selectTab(String label, List<String> tabs) {
    setState(() => _tab = tabs.indexOf(label));
    if (label == 'المحادثات' && !_chatsLoaded) {
      _chatsLoaded = true;
      context.read<ChatProvider>().initialize();
    }
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    context.read<ProviderMarketplaceProvider>().loadMoreProviders();
  }

  bool _hasDirectoryFilters(ProviderMarketplaceProvider marketplace) {
    return marketplace.cityId != null ||
        marketplace.categoryId != null ||
        marketplace.budgetMatchIntent != null ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _clearMarketplaceFilters(
    ProviderMarketplaceProvider marketplace,
  ) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchOpen = false);
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
        // Marketplace browsing can still work without plan context.
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
        if (scopedPlan != null &&
            scopedPlan.status.toUpperCase() != 'ARCHIVED') {
          location = scopedPlan.weddingLocation;
          planId = scopedPlan.id;
        }
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
    });
    if (matchingCityId != null && marketplace.cityId == null) {
      await marketplace.setCity(matchingCityId);
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

  String? _selectedPlanIdForAccount() {
    final selected = context.read<AccountContextController?>()?.selectedContext;
    if (selected?.isPlan != true) return null;
    final selectedPlanId = _normalizedPlanId(selected?.weddingPlanId);
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
