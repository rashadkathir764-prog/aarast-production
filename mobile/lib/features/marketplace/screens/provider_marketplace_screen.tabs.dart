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
        for (final category in money?.categories ?? const [])
          (id: category.id, name: category.name),
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
      // Never another plan's request, even if one leaks into the provider.
      quotes: marketplace
          .quotesForPlan(planId)
          .where((quote) => quote.weddingPlanId == planId)
          .toList(),
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
        board.any((row) => row.stage > 0)) {
      return false;
    }
    if (marketplace.isLoading) return null;
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
    final hall = finance?.categories
        .where((item) => providerServiceGroupOf(item.name) == 0)
        .firstOrNull;
    final hallIntent = hall == null
        ? null
        : ProviderBudgetMatchIntent(
            budgetCategoryName: hall.name,
            allocatedAmount: hall.allocatedAmount,
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
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
          title: 'نبدأ بالقاعة',
          message: 'لأنها تحدد يومك وعدد ضيوفك،\nوالقاعات تنحجز قبل بشهرين.',
          ways: [
            JourneyStartWay(
              key: const ValueKey('providers-first-halls'),
              icon: LucideIcons.building2,
              title: 'قاعات لعرسك',
              subtitle: hallWhere.isEmpty ? 'كل القاعات في الدليل' : hallWhere,
              onTap: () async {
                _leaveFirstVisit();
                _selectTab('استكشف', tabs);
                if (hallIntent?.hasBudget == true) {
                  await marketplace.applyBudgetMatchIntent(hallIntent!);
                  return;
                }
                final category = marketplace.categories
                    .where(
                      (category) =>
                          providerServiceGroupOf(category.nameAr) == 0,
                    )
                    .firstOrNull;
                if (category != null && marketplace.categoryId != category.id) {
                  await marketplace.setCategory(category.id);
                }
              },
            ),
            if (finance?.canManageMoney == true)
              JourneyStartWay(
                key: const ValueKey('providers-first-outside'),
                icon: LucideIcons.checkCircle2,
                title: 'حجزت برا اعّرست',
                subtitle: 'سجّله هنا عشان يدخل خطتك',
                onTap: () => _pushOnce(
                  AppRouter.moneyCostCreate(planId),
                  extra: const CostDraftIntent(outsideParty: true),
                ),
              ),
            JourneyStartWay(
              key: const ValueKey('providers-first-explore'),
              icon: LucideIcons.search,
              title: 'استكشف كل الخدمات',
              subtitle: 'فرق، تصوير، زينة، ضيافة',
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
      color: AarastV3Color.cobalt,
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
          ProviderBoardView(
            rows: board,
            onOpen: _openBoardRow,
            onSearch: (row) => _searchService(row, marketplace, tabs),
          ),
        ],
      ),
    );
  }

  /// «ابحث» on a service that has not started: the directory, filtered to
  /// that kind of provider when the directory has one.
  Future<void> _searchService(
    ProviderBoardRow row,
    ProviderMarketplaceProvider marketplace,
    List<String> tabs,
  ) async {
    _selectTab('استكشف', tabs);
    final group = providerServiceGroupOf(row.providerCategoryName ?? row.title);
    final category = group < 0
        ? null
        : marketplace.categories
              .where(
                (category) => providerServiceGroupOf(category.nameAr) == group,
              )
              .firstOrNull;
    if (category != null && marketplace.categoryId != category.id) {
      await marketplace.setCategory(category.id);
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

  Widget _favoritesTab(ProviderMarketplaceProvider marketplace) {
    final favorites = marketplace.favoriteProviders
        .where((favorite) => favorite.provider != null)
        .toList();
    return ListView(
      key: const PageStorageKey('providers-favorites'),
      padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
      children: [
        if (favorites.isEmpty)
          JourneyBox(
            key: const ValueKey('providers-favorites-empty'),
            child: Text(
              'احفظ المزود اللي يعجبك بالقلب، ويجيك هنا تقارن بينهم.',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          )
        else ...[
          if (favorites.length >= 2)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('providers-favorites-compare'),
                label: 'قارن الملفين',
                icon: LucideIcons.columns,
                color: AarastV3Color.cobalt,
                onPressed: () => _pushOnce(AppRouter.favoriteProviders),
              ),
            ),
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final favorite in favorites)
                  JourneyListRow(
                    key: ValueKey('providers-favorite-${favorite.providerId}'),
                    icon: LucideIcons.heart,
                    color: AarastV3Color.rose,
                    soft: AarastV3Color.roseSoft,
                    title: favorite.provider!.businessName,
                    subtitle: [
                      ?favorite.provider!.city?.nameAr,
                      if (favorite.provider!.ratingCount > 0)
                        '★ ${favorite.provider!.ratingAverage.toStringAsFixed(1)}',
                    ].join(' · '),
                    onTap: () => _openProviderDetails(favorite.providerId),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _exploreTab(ProviderMarketplaceProvider provider) {
    return RefreshIndicator(
      color: AarastV3Color.cobalt,
      onRefresh: () => _refreshMarketplace(provider),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
        children: [
          if (!provider.includesAccountData) ...[
            const JourneyNote(
              key: Key('marketplace-login-note'),
              text:
                  'تقدر تتصفح الآن. تطلب عروض وتتابعها بعد ما تحفظ خطتك برقم جوالك.',
              icon: LucideIcons.logIn,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
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
                label: 'حاول مرة ثانية',
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
            const AarastV3ProgressLine(
              key: Key('marketplace-results-refreshing'),
              height: 3,
              color: AarastV3Color.cobalt,
              backgroundColor: AarastV3Color.cobaltSoft,
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
