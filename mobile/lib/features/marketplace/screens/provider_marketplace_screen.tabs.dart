part of 'provider_marketplace_screen.dart';

/// The four tabs of «المزودين»: طلباتي (f01), استكشف (f02), المحادثات (f08)
/// and المفضلة (f09).
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
    if (_firstVisitLeft || planId == null || !marketplace.includesAccountData) {
      return false;
    }
    if (marketplace.quotesForPlan(planId).isNotEmpty ||
        marketplace.favoriteProviders.isNotEmpty ||
        board.any((row) => row.stage > 0) ||
        // D52: a participant's plan has started when anyone booked.
        _participantBookings(watch: true)?.isNotEmpty == true) {
      return false;
    }
    if (marketplace.isLoading || _participantPlanPending) return null;
    if (marketplace.quoteRequestsErrorMessage != null) return false;
    final finance = context.read<FinanceProvider?>();
    if (finance != null &&
        (finance.loadedPlanId != planId || finance.isLoading)) {
      return null;
    }
    return true;
  }

  Widget _firstVisitPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureMoneyLoaded();
    });
    return const Padding(
      padding: EdgeInsets.only(top: 14),
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
    List<String> tabs,
  ) {
    final planId = _weddingLocationPlanId!;
    final finance = context.read<FinanceProvider?>();
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
      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.embedded ? 124 : 28),
      children: [
        JourneyStartWays(
          key: const ValueKey('providers-first-visit'),
          icon: LucideIcons.store,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: context.planWord('نبدأ بالقاعة', 'نبدأ بالصالة'),
          message: context.say(
            'لأنها تحدد يومك وعدد ضيوفك،\nوالقاعات تنحجز قبل بشهرين.',
            'لأنها تحدد يومك وعدد ضيفاتك،\nوالصالات تنحجز قبل بشهرين.',
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
                _selectTab('استكشف', tabs);
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
              title: 'استكشف كل الخدمات',
              subtitle: context.say(
                'فرق، تصوير، زينة، ضيافة',
                'مزينات، مصورات، زينة، ضيافة',
              ),
              onTap: () {
                _leaveFirstVisit();
                _selectTab('استكشف', tabs);
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
    List<String> tabs,
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
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
        children: [
          if (marketplace.quoteRequestsErrorMessage != null) ...[
            JourneyListNotice(
              offline: false,
              onRetry: marketplace.loadScopedQuoteRequests,
            ),
            const SizedBox(height: 12),
          ],
          ..._participantBookingsSection(),
          for (final hardCase in providerHardCases(board, DateTime.now()))
            ProviderHardCaseCard(
              hardCase: hardCase,
              now: DateTime.now(),
              onFindOthers: () =>
                  _searchService(hardCase.row, marketplace, tabs),
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
                'اللي تطلب منهم عروض يطلعون هنا. دوّر عليهم في «استكشف».',
                'اللي تطلبين منهم عروض يطلعون هنا. دوّري عليهم في «استكشف».',
              ),
              icon: LucideIcons.search,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
            )
          else
            ProviderBoardView(
              rows: board,
              onOpen: _openBoardRow,
              onSearch: (row) => _searchService(row, marketplace, tabs),
            ),
        ],
      ),
    );
  }

  /// «ابحث» (and a hard case's «شوف غيرهم»): the directory, filtered to the
  /// categories the server lists for the row's item (G40), with the item's
  /// amount for «قريبين من بندك».
  Future<void> _searchService(
    ProviderBoardRow row,
    ProviderMarketplaceProvider marketplace,
    List<String> tabs,
  ) async {
    if (row.providerCategoryIds.isEmpty) {
      // A hard case of a kind no item holds: the whole directory.
      _selectTab('استكشف', tabs);
      return;
    }
    final itemId = row.budgetCategoryId;
    final item = itemId == null
        ? null
        : context.read<FinanceProvider?>()?.categoryById(itemId);
    _selectTab('استكشف', tabs);
    await marketplace.applyBudgetMatchIntent(
      ProviderBudgetMatchIntent(
        budgetCategoryName: row.title,
        allocatedAmount: item?.allocatedAmount,
        providerCategoryIds: row.providerCategoryIds,
      ),
    );
    // A new search starts at its top: the item's chip, its line and the
    // first results, not where an earlier browse left the list.
    if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// w34 «الحجوزات», which comes back with a declined service's category
  /// for «شوف غيرهم»: the item it lands in, else that category alone.
  Future<void> _openBookings(
    ProviderMarketplaceProvider marketplace,
    List<String> tabs,
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
      await _searchService(row, marketplace, tabs);
      return;
    }
    _selectTab('استكشف', tabs);
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

  /// f09 «المفضلة»: the saved providers two by two, each with a box to pick
  /// it for «قارن الملفين» (the first two are picked to start).
  Widget _favoritesTab(ProviderMarketplaceProvider marketplace) {
    final favorites = marketplace.favoriteProviders
        .map((favorite) => favorite.provider)
        .whereType<MarketplaceProvider>()
        .toList();
    final picked = _comparePicks(favorites);
    final bottomGap = widget.embedded ? 124.0 : 28.0;
    if (favorites.isEmpty) {
      return ListView(
        key: const PageStorageKey('providers-favorites'),
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomGap),
        children: [
          JourneyBox(
            key: const ValueKey('providers-favorites-empty'),
            child: Text(
              context.say(
                'احفظ المزود اللي يعجبك بالقلب، ويجيك هنا تقارن بينهم.',
                'احفظي المزود اللي يعجبك بالقلب، ويجيك هنا تقارنين بينهم.',
              ),
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          // Two by two; each row as tall as its taller card, so large text
          // grows the cards instead of cutting them.
          child: ListView(
            key: const PageStorageKey('providers-favorites'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            children: [
              for (var i = 0; i < favorites.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final provider in favorites.skip(i).take(2)) ...[
                        if (provider != favorites[i]) const SizedBox(width: 10),
                        Expanded(
                          child: _FavoriteCard(
                            key: ValueKey('providers-favorite-${provider.id}'),
                            provider: provider,
                            price: _favoritePrice(marketplace, provider),
                            picked: picked.contains(provider.id),
                            onPick: () => _togglePick(provider.id, picked),
                            onOpen: () => _openProviderDetails(provider.id),
                          ),
                        ),
                      ],
                      if (i + 1 >= favorites.length) ...[
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (favorites.length >= 2)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomGap - 16),
            child: JourneyButton(
              key: const ValueKey('providers-favorites-compare'),
              label: context.say('قارن الملفين', 'قارني الملفين'),
              icon: LucideIcons.columns,
              background: context.accent.primary,
              large: true,
              expand: true,
              onPressed: picked.length == 2
                  ? () => _pushOnce(
                      AppRouter.compareProviders(picked.first, picked.last),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// A saved provider's prices. The saved list carries none, so they come
  /// from the directory's summary or the provider's page, read once; null
  /// until known, and «حسب الطلب» only when nothing is priced.
  String? _favoritePrice(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) {
    final summary = _providerPriceRangeLabel(provider);
    if (summary != null) return summary;
    if (marketplace.providerDetails(provider.id) == null) {
      if (_favoritePricesAsked.add(provider.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            marketplace.loadProviderDetails(provider.id, weddingPlanId: null);
          }
        });
      }
      return null;
    }
    return providerPriceRange(marketplace.servicesFor(provider.id)) ??
        'حسب الطلب';
  }

  /// The picks still saved, or the first two saved providers.
  List<String> _comparePicks(List<MarketplaceProvider> favorites) {
    final saved = favorites.map((provider) => provider.id).toList();
    return _comparePicked?.where(saved.contains).toList() ??
        saved.take(2).toList();
  }

  Widget _exploreTab(ProviderMarketplaceProvider provider) {
    return RefreshIndicator(
      color: context.accent.primary,
      onRefresh: () => _refreshMarketplace(provider),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
        children: [
          if (!provider.includesAccountData) ...[
            JourneyNote(
              key: const Key('marketplace-login-note'),
              text: context.say(
                'تقدر تتصفح الآن. تطلب عروض وتتابعها بعد ما تحفظ خطتك برقم جوالك.',
                'تقدرين تتصفحين الآن. تطلبين عروض وتتابعينها بعد ما تحفظين خطتك برقم جوالك.',
              ),
              icon: LucideIcons.logIn,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
            ),
            const SizedBox(height: 12),
          ],
          if (provider.includesAccountData &&
              provider.favoriteProvidersErrorMessage != null) ...[
            const JourneyNote(
              key: Key('marketplace-favorites-stale-warning'),
              text: 'ما قدرنا نحدّث المحفوظين، فعلامات القلب ممكن تكون قديمة.',
              icon: LucideIcons.alertTriangle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                label: context.say('حاول مرة ثانية', 'حاولي مرة ثانية'),
                color: AarastV3Color.danger,
                onPressed: provider.loadMarketplace,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_searchShown) ...[
            _MarketplaceSearch(
              controller: _searchController,
              focusNode: _searchFocusNode,
              provider: provider,
            ),
            const SizedBox(height: 10),
          ],
          _FilterChips(provider: provider),
          if (_weddingLocation != null &&
              !_weddingLocation!.hasRequiredLocation) ...[
            const SizedBox(height: 10),
            _LocationContextCard(
              location: _weddingLocation,
              onCompleteLocation: _openLocationCompletion,
            ),
          ],
          if (provider.budgetMatchIntent != null) ...[
            const SizedBox(height: 10),
            _BudgetMatchContextCard(
              intent: provider.budgetMatchIntent!,
              categoryName: _activeCategoryName(provider),
              onClear: provider.clearBudgetMatch,
            ),
          ],
          if (provider.isLoading && provider.providers.isNotEmpty) ...[
            const SizedBox(height: 10),
            AarastV3ProgressLine(
              key: const Key('marketplace-results-refreshing'),
              height: 3,
              color: context.accent.primary,
              backgroundColor: context.accent.primarySoft,
              semanticsLabel: 'تحديث نتائج المزودين',
            ),
          ],
          const SizedBox(height: 16),
          ..._exploreResults(provider),
        ],
      ),
    );
  }
}

/// One saved provider in f09: its photo (or its kind's icon), the box that
/// picks it for comparing, its name, kind and prices.
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.provider,
    required this.price,
    required this.picked,
    required this.onPick,
    required this.onOpen,
    super.key,
  });

  final MarketplaceProvider provider;

  /// Null while the provider's prices are not known yet.
  final String? price;
  final bool picked;
  final VoidCallback onPick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final kind = provider.primaryCategory?.nameAr.trim();
    final cover = provider.coverUrl?.trim();
    // Soft, as on the f02 card, so the picking box shows on it.
    final placeholder = ColoredBox(
      color: context.accent.primarySoft,
      child: Center(
        child: Icon(
          providerServiceIcon(kind ?? ''),
          size: 32,
          color: context.accent.primary,
        ),
      ),
    );
    return AarastPressable(
      onTap: onOpen,
      semanticLabel: provider.businessName,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(20),
          border: picked
              ? Border.all(color: context.accent.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover == null ||
                      cover.isEmpty ||
                      (context.watch<DevicePreferences?>()?.dataSaver ?? false))
                    placeholder
                  else
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: Semantics(
                      checked: picked,
                      child: AarastPressable(
                        key: ValueKey('providers-favorite-pick-${provider.id}'),
                        onTap: onPick,
                        semanticLabel: context.say(
                          'اختره للمقارنة',
                          'اختاريه للمقارنة',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: picked
                                  ? context.accent.primary
                                  : AarastV3Color.paper,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: picked
                                ? const Icon(
                                    LucideIcons.check,
                                    size: 15,
                                    color: AarastV3Color.onPrimary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (kind != null && kind.isNotEmpty)
                    Text(
                      kind,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.caption,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  if (price != null)
                    Text(
                      price!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
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
