import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/media/aarast_network_image.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/utils/app_clock.dart';
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
import '../models/provider_shelves.dart';
import '../widgets/provider_board_view.dart';
import '../widgets/provider_details_view.dart'
    show providerPriceRange, providerPriceSpan, providerPriceText;
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

  /// The tab chosen by hand; null lets the plan's state choose (D72).
  String? _tabLabel;

  /// The tab the screen opened on, settled once the plan's requests have
  /// been read. It used to be worked out on every build, and the requests
  /// arrive after the first frame, so the tab moved from «استكشف» to
  /// «طلباتي» on its own after the reader's eye had settled.
  String? _settledOpening;
  bool _chatsLoaded = false;

  /// The conversations read once for «المحادثات 2» (no live connection).
  bool _chatCountRead = false;

  /// Whether this reader has an account, once asked. Null until the answer
  /// is back. «no account» is an answer, not a wait: without it the tabs
  /// that need one sat on a loading skeleton that could never end.
  bool? _hasAccount;

  /// x22 gives way to the tabs once a way to start was picked. Kept on the
  /// phone, not in this State: the owner's shell rebuilds this screen on
  /// every tab switch, so a State-only latch brought «نبدأ بالقاعة» back
  /// each time the reader returned to the tab, until they actually booked.
  bool _firstVisitLeft = false;

  /// The key under which [_firstVisitLeft] is remembered for this plan.
  static String _firstVisitKey(String planId) =>
      'aarast_providers_start_left:$planId';

  /// The confirmed bookings last checked for y09, so each change is
  /// looked at once.
  String? _momentSignature;

  /// f09's picks for «قارن الملفين»; null until the person picks.
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
    // The four tabs and the search box are states inside one route, the
    // same as c01's tabs and e01's groups. Android back has to undo them
    // before it leaves the providers, or picking «المحادثات» and pressing
    // back throws the reader out of the tab altogether. A tab picked by hand
    // that is the opening tab is not a step to undo (RA-MO-05).
    final opening = _settledOpening ?? 'استكشف';
    final awayFromOpening = _tabLabel != null && _tabLabel != opening;
    final nested = _searchShown || awayFromOpening;
    return TabBackStep(
      nested: nested,
      onBack: () {
        if (_searchShown) {
          // The same as the box's X: a search the reader can no longer see
          // must not keep filtering the list (RA-MO-05).
          _searchController.clear();
          _searchFocusNode.unfocus();
          setState(() {});
          context.read<ProviderMarketplaceProvider>().setSearch('');
          return;
        }
        // Back to the tab the screen opened on.
        setState(() => _tabLabel = null);
      },
      child: AarastScreenFrame(
        safeAreaBottom: false,
        backgroundColor: AarastV3Color.canvas,
        child: Consumer<ProviderMarketplaceProvider>(
          builder: (context, provider, _) {
            // «استكشف» comes first; it opens on «طلباتي» only when something
            // there waits on the owner. Without a plan (or an account) the tab
            // is the directory alone.
            //
            // The tab row follows the plan, not the arrival of its data:
            // includesAccountData is set after the first frame, so the screen
            // used to draw one tab and then four, rearranging itself under the
            // reader's finger on the first visit of a session. A plan in hand
            // is enough to know the four tabs belong here; each one shows its
            // own loading state until its data lands.
            // Once the account answer is in: a plan gets the four tabs. Before
            // it, the directory alone, so the row is drawn once and does not
            // go from one tab to four under the reader's finger.
            final planMode =
                _weddingLocationPlanId != null && _hasAccount != null;
            // RA-MO-256: a guest's plan on the phone has no conversations
            // and no favourites (both are kept in an account), so those two
            // tabs were dead ends for him.
            final tabs = !planMode
                ? const ['استكشف']
                : _hasAccount == true
                ? const ['استكشف', 'طلباتي', 'المحادثات', 'المفضلة']
                : const ['استكشف', 'طلباتي'];
            final board = planMode
                ? _board(provider)
                : const <ProviderBoardRow>[];
            final selectedLabel =
                _tabLabel ??
                _settledOpening ??
                _openingTab(provider, planMode: planMode);
            final tab = tabs.contains(selectedLabel)
                ? tabs.indexOf(selectedLabel)
                : 0;
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
                    AarastV3Space.x4,
                    widget.embedded ? AarastV3Space.x2 : AarastV3Space.x3,
                    AarastV3Space.x4,
                    0,
                  ),
                  child: JourneyTabHeader(
                    title: 'المزودين',
                    // Still reading (null) is not «nothing asked yet».
                    status: firstVisit == null
                        ? 'لحظة…'
                        : firstVisit
                        ? context.say(
                            'ما طلبت من أحد بعد',
                            'ما طلبتِ من أحد بعد',
                          )
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
                    // Rashad 2026-11-18: the search is a box at the top of
                    // «استكشف», always there; the magnifier that opened it
                    // here is gone.
                  ),
                ),
                if (tabs.length > 1 && firstVisit == false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AarastV3Space.x4,
                      AarastV3Space.x3,
                      AarastV3Space.x4,
                      0,
                    ),
                    child: JourneyTabSwitch(
                      key: const ValueKey('providers-tabs'),
                      labels: [
                        for (final label in tabs)
                          label == 'المحادثات'
                              ? _chatsLabel(context, label)
                              : label,
                      ],
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
                    'المحادثات' => ConversationListView(
                      embedded: true,
                      iconFor: _conversationIcon,
                      planId: _conversationsPlanId(context),
                    ),
                    'المفضلة' => _favoritesTab(provider),
                    _ => _exploreTab(provider),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

  /// A search typed in «استكشف»'s box: Android back clears it first.
  bool get _searchShown => _searchController.text.trim().isNotEmpty;

  /// Redraws the screen when the box goes from empty to typed or back, so
  /// back knows there is a search to clear; not on every letter.
  bool _searchWasShown = false;

  /// Rashad's phone 2026-11-18: the list waited for the keyboard's search
  /// key, so typing a name changed nothing and read as broken. The search
  /// runs a moment after the typing stops.
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

  /// f02: the directory results, or why there are none.
  List<Widget> _exploreResults(ProviderMarketplaceProvider provider) {
    // A search that could not load, with no copy of it on the phone, left an
    // earlier search's page in place: it is not this search's answer, so it
    // is not shown as one. While the answer loads the page stays, as before.
    final shown = provider.providersAnswerFilters || provider.isLoading
        ? provider.providers
        : const <MarketplaceProvider>[];
    return [
      if (provider.errorMessage != null && shown.isEmpty)
        JourneyListState(
          key: const ValueKey('marketplace-directory-error'),
          phase: JourneyListPhase.error,
          section: JourneySection.providers,
          onRetry: provider.loadMarketplace,
        )
      else if (provider.isLoading && shown.isEmpty)
        const JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.providers,
        )
      else if (shown.isEmpty && !_hasDirectoryFilters(provider))
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
      else if (shown.isEmpty)
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
        if (provider.errorMessage != null || provider.isStale) ...[
          // D87: an old copy of the directory is said, view only.
          JourneyListNotice(
            offline: provider.errorMessage == null,
            onRetry: provider.loadMarketplace,
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        ..._directory(provider, shown),
        if (provider.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AarastV3Space.x3),
            child: Center(
              child: AarastInlineSpinner(dimension: AarastV3Icon.feature),
            ),
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

  /// Rashad 2026-11-19, the staged layout. Browsing the whole directory
  /// (no kind, no item, no search), each kind is a section in the catalog's
  /// order: more than five providers make a sideways row, fewer a short list
  /// of rows (three at most, «الكل» for the rest). The providers no section
  /// holds follow. A kind picked, an item's search or a typed name shows rows
  /// only, in one list. No provider is shown twice.
  List<Widget> _directory(
    ProviderMarketplaceProvider provider,
    List<MarketplaceProvider> shown,
  ) {
    // The search that ran, not the letters still being typed: the sections
    // stay until the results change, not a beat before. The kinds and which
    // of them are rows are fixed by the provider on the first page.
    final browsing = provider.showsWholeDirectory;
    final order = [for (final category in provider.categories) category.id];
    final sections = browsing
        ? providerSections(
            shown,
            order,
            allowedKinds: provider.browseSectionKinds,
          )
        : const <ProviderShelf>[];
    final inSection = {
      for (final section in sections)
        for (final item in section.providers) item.id,
    };
    final rest = [
      for (final item in shown)
        if (!inSection.contains(item.id)) item,
    ];
    final names = {
      for (final category in provider.categories)
        category.id: providerKindName(context, category),
    };
    Widget row(
      MarketplaceProvider item,
      ProviderRowPlace place, {
      bool showKind = true,
    }) => _ProviderCard(
      provider: item,
      budgetIntent: provider.budgetMatchIntent,
      isFavorite: provider.favoriteProviderIds.contains(item.id),
      onFavorite: () => _toggleFavorite(provider, item.id),
      onTap: () => _openProviderDetails(item.id),
      place: place,
      showKind: showKind,
    );
    return [
      for (final section in sections) ...[
        if (provider.browseShelfKinds.contains(section.categoryId))
          _ProviderShelfRow(
            key: ValueKey('providers-shelf-${section.categoryId}'),
            title: names[section.categoryId] ?? '',
            providers: section.providers,
            favorites: provider.favoriteProviderIds,
            onAll: () => provider.setCategory(section.categoryId),
            onFavorite: (id) => _toggleFavorite(provider, id),
            onOpen: _openProviderDetails,
          )
        else ...[
          _SectionTitle(
            key: ValueKey('providers-section-${section.categoryId}'),
            title: names[section.categoryId] ?? '',
            onAll: section.providers.length > providerSectionPreview
                ? () => provider.setCategory(section.categoryId)
                : null,
            allKey: ValueKey('providers-section-all-${section.categoryId}'),
          ),
          const SizedBox(height: AarastV3Space.x2),
          for (final (index, item)
              in section.providers.take(providerSectionPreview).indexed)
            row(
              item,
              providerRowPlace(
                index,
                section.providers.length.clamp(0, providerSectionPreview),
              ),
              showKind: false,
            ),
        ],
        const SizedBox(height: AarastV3Space.x6),
      ],
      if (sections.isNotEmpty && rest.isNotEmpty) ...[
        Text(
          'مزودين ثانيين',
          key: const ValueKey('providers-rest-title'),
          style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
        ),
        const SizedBox(height: AarastV3Space.x2),
      ],
      // f02: the rows in one group; each says where it stands against the
      // item.
      for (final (index, item) in rest.indexed)
        row(item, providerRowPlace(index, rest.length)),
    ];
  }

  Future<void> _toggleFavorite(
    ProviderMarketplaceProvider provider,
    String id,
  ) async {
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
      context,
      message: context.say(
        'المفضلة تنحفظ في حسابك. سجّل دخول عشان تحفظ المزود.',
        'المفضلة تنحفظ في حسابك. سجّلي دخول عشان تحفظ المزود.',
      ),
    )) {
      return;
    }
    final failure = await provider.toggleFavorite(id);
    if (failure != null && mounted) {
      AarastToast.showError(context, failure);
    }
  }

  /// Where the tab opens: «طلباتي» while a request is under way, or one was
  /// opened from outside (a notice); else «استكشف»: nothing started yet, or
  /// all of it booked. Read from the requests, which come with the screen,
  /// so the tab never jumps when the money items arrive later.
  String _openingTab(
    ProviderMarketplaceProvider provider, {
    required bool planMode,
  }) {
    final planId = _weddingLocationPlanId;
    if (!planMode || planId == null) return 'استكشف';
    if (_focusedQuoteId != null) return 'طلباتي';
    return hasRequestUnderWay(provider.quotesForPlan(planId))
        ? 'طلباتي'
        : 'استكشف';
  }

  void _selectTab(String label, List<String> tabs) {
    setState(() => _tabLabel = label);
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
        if (scopedPlan == null) {
          // The plan could not be read (a weak network): the tab is still
          // that plan's, with its requests, chats and hearts. Only its
          // place is unknown, so the directory starts without a city.
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
    // RA-BE-150: the wedding day goes with the list, so each row says
    // whether the provider takes it; one reload covers it and the city.
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

  /// The plan whose conversations the tab lists (RA-MO-255), watched in
  /// the build as [_selectedPlanIdForAccount] reads it.
  /// «المحادثات 2»: this plan's unread messages on the tab (Rashad
  /// 2026-11-18). The tab is the one inbox of a provider's new message;
  /// «طلباتي» and the bottom bar count none, so without the number a reply
  /// went unseen until a notice. The conversations are read once when the
  /// providers open, not only when the tab is picked.
  String _chatsLabel(BuildContext context, String label) {
    // The list once, for the count; the live connection waits for the tab
    // itself (initialize, in _selectTab), as before.
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
    return unread > 0 ? '$label $unread' : label;
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

  /// [openPlanId]: the plan the account has open, if it is a plan.
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
