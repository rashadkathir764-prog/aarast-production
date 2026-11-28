part of 'provider_marketplace_screen.dart';

/// «الدليل» (REFINEMENT_SPEC 2.7): the title and the tabs scroll away, the
/// search and the categories stay, then the count line and either one shelf
/// per category (browsing everything) or the rows (a category, a search, a
/// money item, an order picked by hand).
extension _DirectoryView on _ProviderMarketplaceScreenState {
  Widget _directoryTab(ProviderMarketplaceProvider provider, Widget top) {
    return RefreshIndicator(
      color: context.accent.primary,
      onRefresh: () => _refreshMarketplace(provider),
      child: CustomScrollView(
        key: const PageStorageKey('providers-directory'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: top),
          PinnedHeaderSliver(
            child: _DirectoryControls(
              controller: _searchController,
              focusNode: _searchFocusNode,
              provider: provider,
              onPickCategory: (id) => _showCategory(provider, id),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AarastV3Density.pageHorizontal,
            ),
            sliver: SliverList.list(children: _listTop(provider)),
          ),
          ..._results(provider),
          SliverToBoxAdapter(
            child: SizedBox(
              height: widget.embedded
                  ? AarastV3Density.pageBottomWithQuickAction
                  : AarastV3Space.x8,
            ),
          ),
        ],
      ),
    );
  }

  /// What sits over the results: the count line, and at most one note.
  List<Widget> _listTop(ProviderMarketplaceProvider provider) {
    final intent = provider.budgetMatchIntent;
    final location = _weddingLocation;
    final Widget? note = !provider.includesAccountData
        ? _QuietNote(
            key: const Key('marketplace-login-note'),
            icon: LucideIcons.logIn,
            text: aarastText.providersGuestNote(context.gender),
          )
        : provider.favoriteProvidersErrorMessage != null
        ? _QuietNote(
            key: const Key('marketplace-favorites-stale-warning'),
            icon: LucideIcons.heartOff,
            text: aarastText.providersFavoritesStale,
          )
        : location != null && !location.hasRequiredLocation
        ? _LocationRow(onTap: _openLocationCompletion)
        : null;
    return [
      _CountLine(provider: provider),
      if (provider.saysSavedCopy && provider.providers.isNotEmpty)
        _QuietNote(
          key: const ValueKey('providers-saved-copy-note'),
          icon: LucideIcons.wifiOff,
          text: aarastText.providersSavedCopyNote,
        )
      else
        ?note,
      if (intent != null) _BudgetLine(intent: intent, provider: provider),
      if (provider.isLoading && provider.providers.isNotEmpty)
        AarastV3ProgressLine(
          key: const Key('marketplace-results-refreshing'),
          height: AarastV3Size.bar,
          color: context.accent.primary,
          backgroundColor: context.accent.primarySoft,
          semanticsLabel: aarastText.providersFilterCounting,
        ),
    ];
  }

  /// The results, or why there are none.
  List<Widget> _results(ProviderMarketplaceProvider provider) {
    // A search that could not load, with no copy of it on the phone, left an
    // earlier search's page in place: it is not this search's answer.
    final shown = provider.providersAnswerFilters || provider.isLoading
        ? provider.providers
        : const <MarketplaceProvider>[];
    final rowHeight = providerRowHeight(context);
    Widget box(Widget child) => SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Density.pageHorizontal,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );
    if (provider.errorMessage != null && shown.isEmpty) {
      return [
        box(
          _DirectoryState(
            key: const ValueKey('marketplace-directory-error'),
            icon: LucideIcons.wifiOff,
            title: aarastText.providersLoadErrorTitle,
            body: aarastText.providersLoadErrorBody(context.gender),
            action: aarastText.providersRetry(context.gender),
            onAction: provider.loadMarketplace,
          ),
        ),
      ];
    }
    if (shown.isEmpty && provider.isLoading ||
        provider.showsWholeDirectory &&
            provider.shelvesLoading &&
            provider.shelves.isEmpty) {
      return [
        _rowCard(
          key: const ValueKey('providers-loading'),
          count: 4,
          row: (_) => ProviderRowSkeleton(minHeight: rowHeight),
        ),
      ];
    }
    if (shown.isEmpty) return [box(_emptyState(provider))];
    if (provider.showsWholeDirectory && provider.shelves.isNotEmpty) {
      return [
        for (final shelf in provider.shelves)
          SliverToBoxAdapter(child: _shelfOf(provider, shelf)),
      ];
    }
    // One height for the whole list, measured at the card's width: the
    // place line only when one of its rows has one, a second line for a
    // name, a price or a status only when one of them needs it.
    final facts = [for (final item in shown) _facts(provider, item)];
    return [
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final listRowHeight = providerRowsHeight(
            context,
            facts,
            cardWidth:
                constraints.crossAxisExtent -
                2 * AarastV3Density.pageHorizontal,
          );
          return _rowCard(
            key: const ValueKey('providers-rows'),
            count: shown.length,
            row: (index) {
              final item = shown[index];
              return ProviderRow(
                key: Key('provider-marketplace-card-${item.id}'),
                facts: facts[index],
                minHeight: listRowHeight,
                isFavorite: provider.favoriteProviderIds.contains(item.id),
                onFavorite: () => _toggleFavorite(provider, item.id),
                onOpen: () => _openProviderDetails(item.id),
              );
            },
          );
        },
      ),
      box(_loadMore(provider)),
    ];
  }

  /// A card's facts as this reader's plan says them.
  ProviderCardFacts _facts(
    ProviderMarketplaceProvider provider,
    MarketplaceProvider item,
  ) => providerCardFacts(
    item,
    bridePlan: context.journeyProfile.isBride,
    now: appNow(),
    askedDay: provider.eventDate,
    budget: provider.budgetMatchIntent,
    // The phone's copy keeps the prices of the whole directory: inside a
    // category it does not know his price there (the data layer drops it),
    // which is not «السعر عند الطلب».
    // And a row the copy kept from another list's answer (a shelf's) has no
    // price of this list: after a search offline it read «السعر عند الطلب»
    // for a provider with a published price.
    priceKnown:
        !(provider.listIsSavedCopy && _scopedList(provider)) &&
        !item.priceUnknownInCopy,
    // A list of one city says it in its count line; the rows say it only
    // under «كل المدن».
    showCity: provider.cityId == null,
    bookedByReader: provider.providersBookedByReader.contains(item.id),
  );

  /// A category's shelf, its cards one height.
  Widget _shelfOf(ProviderMarketplaceProvider provider, ProviderShelf shelf) {
    final facts = [for (final item in shelf.providers) _facts(provider, item)];
    return _Shelf(
      key: ValueKey('providers-shelf-${shelf.categoryId}'),
      title: _shelfTitle(provider, shelf.categoryId),
      categoryId: shelf.categoryId,
      facts: facts,
      cards: [
        for (final (index, item) in shelf.providers.indexed)
          ProviderShelfCard(
            key: ValueKey('provider-shelf-${item.id}'),
            facts: facts[index],
            isFavorite: provider.favoriteProviderIds.contains(item.id),
            onFavorite: () => _toggleFavorite(provider, item.id),
            onOpen: () => _openProviderDetails(item.id),
          ),
      ],
      onAll: () => _showCategory(provider, shelf.categoryId),
    );
  }

  /// A category's list starts at its top. The shelves and the list share
  /// one scroll: «عرض الكل» under the sixth shelf opened the category at
  /// that offset, past its first rows (and asked for the next page at once).
  void _showCategory(ProviderMarketplaceProvider provider, String? id) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(provider.setCategory(id));
  }

  bool _scopedList(ProviderMarketplaceProvider provider) =>
      provider.categoryId != null ||
      (provider.budgetMatchIntent?.providerCategoryIds.isNotEmpty ?? false);

  String _shelfTitle(ProviderMarketplaceProvider provider, String id) {
    final category = provider.categories.where((c) => c.id == id).firstOrNull;
    final name = providerKindName(context, category);
    final count = provider.categoryCounts?.countFor(id);
    return count == null || count == 0
        ? name
        : aarastText.providersChipWithCount(name, count);
  }

  Widget _loadMore(ProviderMarketplaceProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AarastV3Space.x3),
        child: Center(
          child: AarastInlineSpinner(dimension: AarastV3Icon.feature),
        ),
      );
    }
    if (provider.loadMoreErrorMessage != null) {
      return _QuietNote(
        key: const ValueKey('providers-load-more-error'),
        icon: LucideIcons.wifiOff,
        text: aarastText.providersLoadMoreFailed,
        action: aarastText.providersRetry(context.gender),
        onAction: provider.loadMoreProviders,
      );
    }
    if (!provider.hasMoreProviders) return const SizedBox.shrink();
    return Center(
      child: JourneyTextAction(
        key: const Key('providers-load-more'),
        label: aarastText.providersLoadMore,
        icon: LucideIcons.chevronDown,
        color: context.accent.primary,
        onPressed: provider.loadMoreProviders,
      ),
    );
  }

  /// Nothing to show: the directory is empty, a search found nobody (with
  /// the category its word names, «مصور» → «تصوير»), or the filter left
  /// nobody.
  Widget _emptyState(ProviderMarketplaceProvider provider) {
    final typed = _searchController.text.trim();
    if (!_hasDirectoryFilters(provider)) {
      return _DirectoryState(
        key: const ValueKey('marketplace-directory-empty'),
        icon: LucideIcons.store,
        title: aarastText.providersEmptyDirectoryTitle,
        body: aarastText.providersEmptyDirectoryBody,
      );
    }
    if (typed.isNotEmpty) {
      final named = providerCategoryNamedBy(
        typed,
        provider.categories,
        bridePlan: context.journeyProfile.isBride,
      );
      return _DirectoryState(
        key: const ValueKey('marketplace-search-miss'),
        icon: LucideIcons.searchX,
        title: aarastText.providersSearchMissTitle(typed),
        body: aarastText.providersSearchMissBody(context.gender),
        action: named == null
            ? aarastText.providersSearchClear
            : aarastText.providersSearchInCategory(
                providerKindName(context, named),
              ),
        onAction: named == null
            ? () => _clearSearch(provider)
            : () async {
                // One read: the box is emptied without its own search (the
                // listener's debounce finds nothing changed).
                final browsing = provider.browseCategory(named.id);
                _searchController.clear();
                await browsing;
              },
      );
    }
    return _DirectoryState(
      key: const ValueKey('marketplace-filtered-empty'),
      icon: LucideIcons.searchX,
      title: aarastText.providersFilterMissTitle,
      body: aarastText.providersFilterMissBody(context.gender),
      action: aarastText.providersFilterClear,
      onAction: () => _clearMarketplaceFilters(provider),
    );
  }
}

/// [count] rows in one paper card with a hairline between them
/// (REFINEMENT_SPEC 2.6: like things are rows in one card), drawn lazily.
Widget _rowCard({
  required Key key,
  required int count,
  required Widget Function(int index) row,
}) => SliverPadding(
  key: key,
  padding: const EdgeInsets.symmetric(
    horizontal: AarastV3Density.pageHorizontal,
  ),
  sliver: DecoratedSliver(
    decoration: JourneyBox.decorationOf(),
    sliver: SliverList.separated(
      itemCount: count,
      itemBuilder: (_, index) => row(index),
      separatorBuilder: (_, _) => const Divider(
        height: AarastV3Size.line,
        thickness: AarastV3Size.line,
        indent: AarastV3Space.x4,
        endIndent: AarastV3Space.x4,
        color: AarastV3Color.line,
      ),
    ),
  ),
);

/// A category's shelf while browsing everything: its name with its count,
/// «عرض الكل», and its first providers sideways, running to the screen's
/// edges.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.categoryId,
    required this.cards,
    required this.onAll,
    required this.facts,
    super.key,
  });

  final String title;
  final String categoryId;

  /// Its cards' facts: the shelf is as tall as the tallest card's lines.
  final List<ProviderCardFacts> facts;
  final List<Widget> cards;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final width = providerShelfCardWidth(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AarastV3Density.pageHorizontal,
              end: AarastV3Space.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.lead,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ),
                ),
                JourneyTextAction(
                  key: ValueKey('providers-shelf-all-$categoryId'),
                  label: aarastText.providersShelfAll,
                  color: context.accent.primary,
                  onPressed: onAll,
                ),
              ],
            ),
          ),
          SizedBox(
            height: providerShelfCardHeight(context, facts: facts),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AarastV3Density.pageHorizontal,
              ),
              itemCount: cards.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AarastV3Space.x3),
              itemBuilder: (_, index) =>
                  SizedBox(width: width, child: cards[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// In place of the list: what happened, in a sentence, and the one way on.
class _DirectoryState extends StatelessWidget {
  const _DirectoryState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x8),
      child: Column(
        children: [
          Icon(icon, size: AarastV3Icon.xl, color: AarastV3Color.textMuted),
          const SizedBox(height: AarastV3Space.x3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            body,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: AarastV3Space.x4),
            JourneyButton.outline(label: action, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// A plain line with its mark over the list: no box, no colour of its own
/// (one coloured note on a screen at most, REFINEMENT_SPEC 2.6).
class _QuietNote extends StatelessWidget {
  const _QuietNote({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
      child: Row(
        children: [
          Icon(icon, size: AarastV3Icon.sm, color: AarastV3Color.textMuted),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          if (action != null)
            JourneyTextAction(
              label: action,
              color: context.accent.primary,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

/// «أين عرسك؟»: the plan's place is incomplete, so its city cannot come
/// first; opens the plan's details.
class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
      child: JourneyBox(
        key: const Key('marketplace-location-prompt'),
        padding: EdgeInsets.zero,
        child: JourneyListRow(
          icon: LucideIcons.mapPin,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: aarastText.providersLocationTitle,
          subtitle: aarastText.providersLocationBody(context.gender),
          subtitleMaxLines: 2,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The list came from one of the plan's money items (G40): the item and
/// its amount (following «أخفِ المبالغ»), and the × that ends it.
class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.intent, required this.provider});

  final ProviderBudgetMatchIntent intent;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final shown =
        context.watch<FinanceProvider?>()?.shownAmount ?? (String text) => text;
    final text = intent.hasBudget
        ? aarastText.providersBudgetLineAmount(
            intent.budgetCategoryName,
            shown(
              fullMoneyParts(
                intent.allocatedValue,
                currencyCode: defaultCurrencyCode,
              ).plainText,
            ),
          )
        : aarastText.providersBudgetLine(intent.budgetCategoryName);
    return Row(
      key: const ValueKey('providers-budget-line'),
      children: [
        Icon(
          LucideIcons.wallet,
          size: AarastV3Icon.sm,
          color: context.accent.primary,
        ),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: context.accent.primaryDark,
            ),
          ),
        ),
        IconButton(
          tooltip: aarastText.providersBudgetClear,
          onPressed: provider.clearBudgetMatch,
          icon: Icon(
            LucideIcons.x,
            size: AarastV3Icon.md,
            color: context.accent.primary,
          ),
        ),
      ],
    );
  }
}
