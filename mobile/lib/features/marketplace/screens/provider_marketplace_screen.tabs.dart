part of 'provider_marketplace_screen.dart';

/// «طلباتي» (f01) and «المفضلة» (f09). «الدليل» is in the results part, the
/// conversations are the chat feature's own list.
extension _ProviderTabs on _ProviderMarketplaceScreenState {
  List<ProviderBoardRow> _board(ProviderMarketplaceProvider marketplace) {
    final planId = _weddingLocationPlanId!;
    final finance = context.watch<FinanceProvider?>();
    final money = finance?.loadedPlanId == planId ? finance : null;
    final costs = money?.costs ?? const [];
    return buildProviderBoard(
      items: [
        // The mahr is no provider's service (C1, D55).
        for (final category in money?.categories ?? const [])
          if (!category.isMahr)
            (
              id: category.id,
              name: category.name,
              providerCategoryIds: money!.providerCategoryIdsFor(category.id),
            ),
      ],
      costs: [
        for (final cost in costs)
          (
            budgetCategoryId: cost.budgetCategoryId,
            providerId: cost.providerId,
            partyName: cost.partyName,
          ),
      ],
      costItemById: {for (final cost in costs) cost.id: cost.budgetCategoryId},
      reader: context.journeyProfile,
      booked: _serverBooked(planId),
      // Never another plan's request, even if one leaks into the provider.
      quotes: marketplace
          .quotesForPlan(planId)
          .where((quote) => quote.weddingPlanId == planId)
          .toList(),
    );
  }

  /// D60: what the server counts as booked in this plan, the home's count;
  /// null until the plan's summary is read.
  ({Set<String> items, Set<String> quotes})? _serverBooked(String planId) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    if (summary == null || summary.planId != planId) return null;
    return (
      items: summary.bookedServices.itemIds.toSet(),
      quotes: summary.bookedServices.quoteRequestIds.toSet(),
    );
  }

  /// The board reads the plan's money items; load them once if the money
  /// tab has not.
  void _ensureMoneyLoaded() {
    final planId = _weddingLocationPlanId;
    final finance = context.read<FinanceProvider?>();
    if (planId == null || finance == null) return;
    if (finance.loadedPlanId == planId || finance.isLoading) return;
    finance.loadMoney(planId);
  }

  /// Whether «طلباتي» is the plan's first visit (x22): nothing asked,
  /// booked (here or outside) or saved yet. Null while the requests or the
  /// money items are still loading, so neither view flashes before the other.
  bool? _firstVisitOf(
    ProviderMarketplaceProvider marketplace,
    List<ProviderBoardRow> board,
  ) {
    final planId = _weddingLocationPlanId;
    if (_firstVisitLeft || planId == null) return false;
    // Without an account there are no requests to read until the plan is
    // saved: a first visit, not a wait (RA-MO-19: it waits for the money,
    // which x22's ways depend on).
    if (_hasAccount == false) return _moneyReadFor(planId) ? true : null;
    if (!marketplace.includesAccountData) return null;
    if (marketplace.quotesForPlan(planId).isNotEmpty ||
        marketplace.favoriteProviders.isNotEmpty ||
        board.any((row) => row.stage > 0) ||
        // D52: a participant's plan has started when anyone booked.
        _participantBookings(watch: true)?.isNotEmpty == true) {
      return false;
    }
    // The phone's copy of the directory ends [isLoading] at once and holds
    // no requests and no saved providers: the plan's first visit is decided
    // by the server's answer, not by that copy.
    if (marketplace.isLoading ||
        marketplace.accountDataPending ||
        _participantPlanPending) {
      return null;
    }
    if (marketplace.quoteRequestsErrorMessage != null) return false;
    return _moneyReadFor(planId) ? true : null;
  }

  /// Whether this plan's money items are read (or there is no money here).
  bool _moneyReadFor(String planId) {
    final finance = context.read<FinanceProvider?>();
    return finance == null ||
        (finance.loadedPlanId == planId && !finance.isLoading);
  }

  Widget _firstVisitPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureMoneyLoaded();
    });
    return const Padding(
      padding: EdgeInsets.only(top: AarastV3Space.x3),
      child: JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.providers,
      ),
    );
  }

  /// x22 «نبدأ بالقاعة»: the hall first, a booking made outside, or the
  /// whole directory.
  Widget _firstVisitView(
    ProviderMarketplaceProvider marketplace,
    List<ProvidersTab> tabs,
  ) {
    final planId = _weddingLocationPlanId!;
    final read = context.read<FinanceProvider?>();
    final finance = read?.loadedPlanId == planId ? read : null;
    // The venue kind by the catalog's own slug, and the item it lands in by
    // the server's list (G40).
    final venue = marketplace.categories
        .where((category) => category.slug == venueCategorySlug)
        .firstOrNull;
    final hall = venue == null || finance == null
        ? null
        : budgetItemForCategories(
            finance.categories,
            (item) => finance.providerCategoryIdsFor(item.id),
            [venue.id],
          );
    final hallIntent = hall == null
        ? null
        : ProviderBudgetMatchIntent(
            budgetCategoryName: hall.name,
            allocatedAmount: hall.allocatedAmount,
            providerCategoryIds: finance!.providerCategoryIdsFor(hall.id),
          );
    final city =
        [_weddingLocation?.cityOrDistrict, _weddingLocation?.governorate]
            .map((name) => name?.trim() ?? '')
            .where((name) => name.isNotEmpty)
            .firstOrNull;
    final hallWhere = [
      if (hallIntent?.hasBudget == true) 'على قد بندك',
      if (city != null) 'في $city',
    ].join(' ');

    return ListView(
      key: const PageStorageKey('providers-first-visit'),
      padding: EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x1,
        AarastV3Space.x4,
        widget.embedded ? AarastV3Density.pageBottom : AarastV3Space.x6,
      ),
      children: [
        JourneyStartWays(
          key: const ValueKey('providers-first-visit'),
          icon: LucideIcons.store,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: context.planWord('نبدأ بالقاعة', 'نبدأ بالصالة'),
          // The plan's words, not the reader's: a helper reads this too.
          message: context.planWord(
            'لأنها تحدد يوم العرس وعدد الضيوف،\nوالقاعات تنحجز قبل بشهرين.',
            'لأنها تحدد يوم العرس وعدد الضيفات،\nوالصالات تنحجز قبل بشهرين.',
          ),
          ways: [
            JourneyStartWay(
              key: const ValueKey('providers-first-halls'),
              icon: LucideIcons.building2,
              title: context.say('قاعات لعرسك', 'صالات لعرسك'),
              subtitle: hallWhere.isEmpty
                  ? context.say('كل القاعات في الدليل', 'كل الصالات في الدليل')
                  : hallWhere,
              onTap: () async {
                _leaveFirstVisit();
                _selectTab(ProvidersTab.directory);
                if (hallIntent != null) {
                  await marketplace.applyBudgetMatchIntent(hallIntent);
                  return;
                }
                if (venue != null && marketplace.categoryId != venue.id) {
                  await marketplace.setCategory(venue.id);
                }
              },
            ),
            if (finance?.canManageMoney == true)
              JourneyStartWay(
                key: const ValueKey('providers-first-outside'),
                icon: LucideIcons.checkCircle2,
                title: context.say('حجزت برا اعّرست', 'حجزتِ برا اعّرست'),
                subtitle: context.say(
                  'سجّله هنا عشان يدخل خطتك',
                  'سجّليه هنا عشان يدخل خطتك',
                ),
                onTap: () => _pushOnce(
                  AppRouter.moneyCostCreate(planId),
                  extra: const CostDraftIntent(outsideParty: true),
                ),
              ),
            JourneyStartWay(
              key: const ValueKey('providers-first-explore'),
              icon: LucideIcons.search,
              title: aarastText.providersFavoritesBrowse,
              subtitle: context.say(
                'فرق، تصوير، زينة، ضيافة',
                'مزينات، مصورات، زينة، ضيافة',
              ),
              onTap: () {
                _leaveFirstVisit();
                _selectTab(ProvidersTab.directory);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _boardTab(
    ProviderMarketplaceProvider marketplace,
    List<ProviderBoardRow> board,
    List<ProvidersTab> tabs,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureMoneyLoaded();
    });
    return RefreshIndicator(
      color: context.accent.primary,
      onRefresh: () => _refreshMarketplace(marketplace),
      child: ListView(
        key: const PageStorageKey('providers-board'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x3,
          AarastV3Space.x4,
          widget.embedded ? AarastV3Density.pageBottom : AarastV3Space.x6,
        ),
        children: [
          if (marketplace.quoteRequestsErrorMessage != null ||
              marketplace.quoteRequestsStale) ...[
            // D87: an old copy of the requests; decisions need the server.
            JourneyListNotice(
              offline: marketplace.quoteRequestsErrorMessage == null,
              onRetry: marketplace.loadScopedQuoteRequests,
            ),
            const SizedBox(height: AarastV3Space.x3),
          ],
          ..._participantBookingsSection(),
          for (final hardCase in providerHardCases(board, appNow()))
            ProviderHardCaseCard(
              hardCase: hardCase,
              now: appNow(),
              onFindOthers: () => _searchService(hardCase.row, marketplace),
              onAnotherDay: () => _pushOnce<void>(
                AppRouter.providerQuote(hardCase.quote.providerId),
              ),
              // B-03: «افتح العرض الثاني» and «اسألهم ليش».
              onOpenOther: switch ((hardCase.other, _weddingLocationPlanId)) {
                (final other?, final planId?) => () => _pushOnce<void>(
                  AppRouter.providerRequests(
                    planId,
                    itemKey: hardCase.row.key,
                    quoteId: other.id,
                  ),
                ),
                _ => null,
              },
              onAsk: () => _pushOnce<void>(
                AppRouter.quoteConversation(hardCase.quote.id),
              ),
            ),
          if (board.isEmpty && _participantBookings()?.isNotEmpty == true)
            // The plan's bookings are above; the participant has asked
            // nobody themselves yet, and the money items are not theirs.
            JourneyNote(
              key: const ValueKey('participant-own-requests-empty'),
              text: context.say(
                'اللي تطلب منهم عروض يطلعون هنا. دوّر عليهم في «الدليل».',
                'اللي تطلبين منهم عروض يطلعون هنا. دوّري عليهم في «الدليل».',
              ),
              icon: LucideIcons.search,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
            )
          else
            ProviderBoardView(
              rows: board,
              onOpen: _openBoardRow,
              onSearch: (row) => _searchService(row, marketplace),
              onExplore: () => _selectTab(ProvidersTab.directory),
            ),
        ],
      ),
    );
  }

  /// «ابحث» (and a hard case's «شوف غيرهم»): the directory, filtered to the
  /// categories the server lists for the row's item (G40), with the item's
  /// amount for how a price stands against it.
  Future<void> _searchService(
    ProviderBoardRow row,
    ProviderMarketplaceProvider marketplace,
  ) async {
    _selectTab(ProvidersTab.directory);
    if (row.providerCategoryIds.isEmpty) return;
    final itemId = row.budgetCategoryId;
    final item = itemId == null
        ? null
        : context.read<FinanceProvider?>()?.categoryById(itemId);
    await marketplace.applyBudgetMatchIntent(
      ProviderBudgetMatchIntent(
        budgetCategoryName: row.title,
        allocatedAmount: item?.allocatedAmount,
        providerCategoryIds: row.providerCategoryIds,
      ),
    );
    // A new search starts at its top, not where an earlier browse left it.
    if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// w34 «الحجوزات», which comes back with a declined service's category
  /// for «شوف غيرهم»: the item it lands in, else that category alone.
  Future<void> _openBookings(
    ProviderMarketplaceProvider marketplace,
    List<ProviderBoardRow> board,
  ) async {
    final planId = _weddingLocationPlanId;
    if (planId == null) return;
    final categoryId = await _pushOnce<String>(AppRouter.planBookings(planId));
    if (!mounted || categoryId == null || categoryId.isEmpty) return;
    final row = board
        .where((row) => row.providerCategoryIds.contains(categoryId))
        .firstOrNull;
    if (row != null) {
      await _searchService(row, marketplace);
      return;
    }
    _selectTab(ProvidersTab.directory);
    if (marketplace.categoryId != categoryId) {
      await marketplace.setCategory(categoryId);
    }
  }

  /// A service with requests: f04, its offers and its booking.
  Future<void> _openBoardRow(ProviderBoardRow row) async {
    final planId = _weddingLocationPlanId;
    if (planId == null) return;
    await _pushOnce(
      AppRouter.providerRequests(
        planId,
        itemKey: row.key,
        quoteId: row.quotes.firstOrNull?.id,
      ),
    );
  }

  /// f09 «المفضلة»: two by two, the shelf's own card (the first proposal's
  /// grid, every card one height so the grid keeps its rows), each with the
  /// box on its picture that picks it for the comparison; the button under
  /// them compares the two picked (of one kind only).
  Widget _favoritesTab(ProviderMarketplaceProvider marketplace, Widget top) {
    final favorites = marketplace.favoriteProviders
        .map((favorite) => favorite.provider)
        .whereType<MarketplaceProvider>()
        .toList();
    final picked = _comparePicks(favorites);
    final rowHeight = providerRowHeight(context);
    final failed = marketplace.favoriteProvidersErrorMessage != null;
    Widget box(Widget child) => SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Density.pageHorizontal,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );
    final List<Widget> content;
    if (favorites.isEmpty && failed) {
      content = [
        box(
          _DirectoryState(
            key: const ValueKey('providers-favorites-error'),
            icon: LucideIcons.wifiOff,
            title: aarastText.providersFavoritesErrorTitle,
            body: aarastText.providersLoadErrorBody(context.gender),
            action: aarastText.providersRetry(context.gender),
            onAction: marketplace.loadFavoriteProviders,
          ),
        ),
      ];
    } else if (favorites.isEmpty &&
        (marketplace.isLoading || marketplace.accountDataPending)) {
      content = [
        _rowCard(
          key: const ValueKey('providers-favorites-loading'),
          count: 3,
          row: (_) => ProviderRowSkeleton(minHeight: rowHeight),
        ),
      ];
    } else if (favorites.isEmpty) {
      content = [
        box(
          _DirectoryState(
            key: const ValueKey('providers-favorites-empty'),
            icon: LucideIcons.heart,
            title: aarastText.providersFavoritesEmptyTitle,
            body: aarastText.providersFavoritesEmptyBody(context.gender),
            action: aarastText.providersFavoritesBrowse,
            onAction: () => _selectTab(ProvidersTab.directory),
          ),
        ),
      ];
    } else {
      final facts = [
        for (final provider in favorites) _favoriteFacts(marketplace, provider),
      ];
      content = [
        SliverPadding(
          key: const ValueKey('providers-favorites-grid'),
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Density.pageHorizontal,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.crossAxisExtent - AarastV3Space.x3) / 2;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AarastV3Space.x3,
                  crossAxisSpacing: AarastV3Space.x3,
                  mainAxisExtent: providerCardHeight(
                    context,
                    width: width,
                    boxed: true,
                    facts: facts,
                  ),
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final provider = favorites[index];
                  final isPicked = picked.contains(provider.id);
                  return ProviderShelfCard(
                    key: ValueKey('providers-favorite-${provider.id}'),
                    facts: facts[index],
                    boxed: true,
                    picked: isPicked,
                    isFavorite: true,
                    onFavorite: () => _toggleFavorite(marketplace, provider.id),
                    onOpen: () => _openProviderDetails(provider.id),
                    pick: favorites.length < 2
                        ? null
                        : ProviderComparePick(
                            key: ValueKey(
                              'providers-favorite-pick-${provider.id}',
                            ),
                            picked: isPicked,
                            onTap: () =>
                                _togglePick(provider, picked, favorites),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            key: const PageStorageKey('providers-favorites'),
            slivers: [
              SliverToBoxAdapter(child: top),
              const SliverToBoxAdapter(
                child: SizedBox(height: AarastV3Space.x3),
              ),
              ...content,
              const SliverToBoxAdapter(
                child: SizedBox(height: AarastV3Space.x4),
              ),
            ],
          ),
        ),
        if (favorites.length >= 2)
          ColoredBox(
            color: AarastV3Color.canvas,
            child: Padding(
              // The «+» floats at the bar's end (D33): nothing to press under
              // it, so the button stops before its column.
              padding: EdgeInsetsDirectional.fromSTEB(
                AarastV3Density.pageHorizontal,
                AarastV3Space.x2,
                widget.embedded
                    ? AarastV3Size.quickAction + AarastV3Space.x8
                    : AarastV3Density.pageHorizontal,
                AarastV3Space.x4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (picked.length < 2) ...[
                    Text(
                      aarastText.providersCompareSameKind,
                      key: const ValueKey('providers-favorites-same-kind'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                  ],
                  JourneyButton(
                    key: const ValueKey('providers-favorites-compare'),
                    label: aarastText.providersCompare(context.gender),
                    icon: LucideIcons.columns,
                    large: true,
                    expand: true,
                    onPressed: picked.length == 2
                        ? () => _pushOnce(
                            AppRouter.compareProviders(
                              picked.first,
                              picked.last,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// A saved provider's card facts, with the prices and the photo his page
  /// gives once read.
  ProviderCardFacts _favoriteFacts(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) {
    final price = _favoritePrice(marketplace, provider);
    return providerCardFacts(
      provider,
      bridePlan: context.journeyProfile.isBride,
      now: appNow(),
      askedDay: marketplace.eventDate,
      span: price.span,
      priceKnown: price.known,
      photoUrl: _favoritePhoto(marketplace, provider),
      bookedByReader: marketplace.providersBookedByReader.contains(provider.id),
    );
  }

  /// A saved provider's prices, as every card says them. The saved list
  /// carries none, so they come from his page (services and packages), read
  /// once; not known until then, and «السعر عند الطلب» only when nothing
  /// is priced.
  ({ProviderPriceSpan? span, bool known}) _favoritePrice(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) {
    final listed = providerPublishedSpan(provider);
    if (listed != null) return (span: listed, known: true);
    if (marketplace.providerDetails(provider.id) == null) {
      if (_favoritePricesAsked.add(provider.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            marketplace.loadProviderDetails(provider.id, weddingPlanId: null);
          }
        });
      }
      return (span: null, known: false);
    }
    return (
      span: providerOwnKindSpan(
        provider,
        marketplace.servicesFor(provider.id),
        marketplace.packagesFor(provider.id),
      ),
      known: true,
    );
  }

  /// A saved provider's picture: the saved list carries his cover and logo
  /// only, so his first work photo (outside the women's album) comes from
  /// his page once read, as the directory's card shows it.
  String? _favoritePhoto(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) {
    for (final photo
        in marketplace.portfolioFor(provider.id)?.items ??
            const <PublicPortfolioPhoto>[]) {
      if (!photo.forWomen && photo.imageUrl.trim().isNotEmpty) {
        return photo.imageUrl.trim();
      }
    }
    return null;
  }

  /// The picks still saved, or the first two saved providers of the same
  /// kind: a band is never set beside a photographer.
  List<String> _comparePicks(List<MarketplaceProvider> favorites) {
    final saved = favorites.map((provider) => provider.id).toList();
    return _comparePicked?.where(saved.contains).toList() ??
        firstSameKindPair(favorites);
  }
}
