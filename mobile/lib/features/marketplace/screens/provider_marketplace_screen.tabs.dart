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

  void _openSearch(List<String> tabs) {
    _selectTab('استكشف', tabs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Widget _boardTab(
    ProviderMarketplaceProvider marketplace,
    List<ProviderBoardRow> board,
    WeddingPlanStageState? stage,
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
          if (stage != null) ...[
            WeddingStageContextLine(
              stage: stage,
              domain: WeddingStageDomain.providers,
            ),
            const SizedBox(height: 12),
          ],
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
              .where((category) => providerServiceGroupOf(category.nameAr) == group)
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

  Widget _exploreTab(
    ProviderMarketplaceProvider provider,
    WeddingPlanStageState? stage, {
    required bool showStage,
  }) {
    return RefreshIndicator(
      color: AarastV3Color.cobalt,
      onRefresh: () => _refreshMarketplace(provider),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
        children: [
          if (showStage && stage != null) ...[
            WeddingStageContextLine(
              stage: stage,
              domain: WeddingStageDomain.providers,
            ),
            const SizedBox(height: 12),
          ],
          if (!provider.includesAccountData) ...[
            const _LoginRequiredCard(),
            const SizedBox(height: 12),
          ],
          if (provider.includesAccountData &&
              provider.favoriteProvidersErrorMessage != null) ...[
            KeyedSubtree(
              key: const Key('marketplace-favorites-stale-warning'),
              child: _ErrorCard(
                title: 'تعذر تحديث المحفوظات',
                message:
                    'نعرض آخر حالة محفوظة مؤقتًا؛ قد تكون أرقام الحفظ '
                    'وعلامات القلب أدناه قديمة حتى تنجح إعادة المحاولة.',
                onRetry: provider.loadMarketplace,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _MarketplaceSearch(
            controller: _searchController,
            focusNode: _searchFocusNode,
            provider: provider,
          ),
          const SizedBox(height: 10),
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
