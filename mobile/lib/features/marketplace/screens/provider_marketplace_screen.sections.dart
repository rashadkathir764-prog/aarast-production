part of 'provider_marketplace_screen.dart';

/// The two rows that stay while «الدليل» scrolls (REFINEMENT_SPEC 2.7): the
/// search with the filter's pill and its count inside it, at its end (the
/// first proposal's compact box), then the categories with their icons and
/// counts. The title and the tabs scroll away above them.
class _DirectoryControls extends StatelessWidget {
  const _DirectoryControls({
    required this.controller,
    required this.focusNode,
    required this.provider,
    required this.onPickCategory,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ProviderMarketplaceProvider provider;

  /// A chip's category (null: «الكل»), opened from the list's top.
  final ValueChanged<String?> onPickCategory;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('providers-controls'),
      color: AarastV3Color.canvas,
      child: Padding(
        padding: const EdgeInsets.only(top: AarastV3Space.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AarastV3Density.pageHorizontal,
              ),
              child: _SearchBox(
                controller: controller,
                focusNode: focusNode,
                provider: provider,
              ),
            ),
            _CategoryChips(provider: provider, onPick: onPickCategory),
          ],
        ),
      ),
    );
  }
}

/// The search box: it searches as the reader types (Rashad's phone
/// 2026-11-18); the × clears it, and the filter's pill closes it (a box of
/// its own beside the search was width lost, and a second loud block).
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.provider,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      borderSide: BorderSide(color: color, width: width),
    );
    return SizedBox(
      height: AarastV3Size.action,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          key: const Key('marketplace-search-field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          cursorColor: context.accent.primary,
          decoration: InputDecoration(
            hintText: aarastText.providersSearchHint(planSideOf(context)),
            hintMaxLines: 1,
            hintStyle: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textFaint,
            ),
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: AarastV3Color.paper,
            prefixIcon: const Icon(
              LucideIcons.search,
              size: AarastV3Icon.md,
              color: AarastV3Color.textMuted,
            ),
            border: border(AarastV3Color.fieldEdge, AarastV3Size.line),
            enabledBorder: border(AarastV3Color.fieldEdge, AarastV3Size.line),
            focusedBorder: border(
              context.accent.primary,
              AarastV3Size.lineStrong,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.isNotEmpty)
                  IconButton(
                    tooltip: aarastText.providersSearchClear,
                    onPressed: () {
                      controller.clear();
                      provider.setSearch('');
                    },
                    icon: const Icon(LucideIcons.x, size: AarastV3Icon.md),
                  ),
                _FilterPill(provider: provider),
                const SizedBox(width: AarastV3Space.x1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How many filters are on: the city and hiding the busy. The category is
/// its chip, the order its own line.
int _activeFilters(ProviderMarketplaceProvider provider) =>
    (provider.cityId != null ? 1 : 0) + (provider.hideBusy ? 1 : 0);

/// The filter inside the search box, at its end (the first proposal): the
/// sliders alone while nothing is on; a soft pill in the plan's colour with
/// how many filters are on (the second's count) once one is. It opens the
/// city and hiding the busy; touched in 48.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final active = _activeFilters(provider);
    final accent = context.accent;
    final on = active > 0;
    return Semantics(
      button: true,
      label: aarastText.providersFilterButton(active),
      excludeSemantics: true,
      onTap: () => _openFilterSheet(context, provider),
      child: AarastPressable(
        key: const Key('city-filter-trigger'),
        onTap: () => _openFilterSheet(context, provider),
        clip: false,
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AarastV3Size.touch,
            minHeight: AarastV3Size.touch,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              key: const ValueKey('providers-filter-pill'),
              padding: EdgeInsets.symmetric(
                horizontal: on ? AarastV3Space.x2 : AarastV3Space.x1,
                vertical: AarastV3Space.x1,
              ),
              decoration: BoxDecoration(
                color: on ? accent.primarySoft : null,
                borderRadius: BorderRadius.circular(AarastV3Radius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: AarastV3Icon.md,
                    color: on ? accent.primaryDark : AarastV3Color.textMuted,
                  ),
                  if (on) ...[
                    const SizedBox(width: AarastV3Space.x1),
                    Text(
                      '$active',
                      key: const ValueKey('providers-filter-count'),
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: accent.primaryDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openFilterSheet(
  BuildContext context,
  ProviderMarketplaceProvider provider,
) => showJourneySheet<void>(
  context: context,
  builder: (_) => _FilterSheet(provider: provider),
);

/// The categories as chips, each with its kind's icon (the first proposal)
/// and how many it opens under the filter (the server's counts, D131); a
/// category with nobody is not shown. The row is a chip's touch band tall,
/// so each keeps its 48.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.provider, required this.onPick});

  final ProviderMarketplaceProvider provider;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = provider.categoryId;
    final counts = provider.categoryCounts;
    // G40: a search from a money item filters by all of its categories; its
    // chip comes first, chosen, and «الكل» or a category replaces it.
    final item = provider.budgetMatchIntent;
    final itemChip = item != null && item.providerCategoryIds.isNotEmpty
        ? item
        : null;
    String label(String name, int? count) => count == null || count == 0
        ? name
        : aarastText.providersChipWithCount(name, count);
    final chips = <Widget>[
      if (itemChip != null)
        JourneyChip(
          key: const ValueKey('category-chip-item'),
          label: itemChip.budgetCategoryName,
          icon: providerServiceIcon(itemChip.budgetCategoryName),
          selected: true,
        ),
      JourneyChip(
        key: const ValueKey('category-chip-all'),
        label: label(aarastText.providersChipAll, counts?.total),
        selected: selected == null && itemChip == null,
        onTap: () => onPick(null),
      ),
      for (final category in provider.categories)
        if (counts == null ||
            counts.countFor(category.id) > 0 ||
            category.id == selected)
          JourneyChip(
            key: ValueKey('category-chip-${category.id}'),
            label: label(
              providerKindName(context, category),
              counts?.countFor(category.id),
            ),
            icon: providerServiceIcon(category.nameAr),
            selected: selected == category.id,
            onTap: () => onPick(category.id),
          ),
    ];
    return SizedBox(
      height: AarastV3Size.touch,
      child: ListView.separated(
        key: const ValueKey('providers-category-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Density.pageHorizontal,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AarastV3Space.x2),
        itemBuilder: (_, index) => Center(child: chips[index]),
      ),
    );
  }
}

/// The order, as the reader reads it.
String providerSortLabel(ProviderSort sort) => switch (sort) {
  ProviderSort.best => aarastText.providersSortBest,
  ProviderSort.rating => aarastText.providersSortRating,
  ProviderSort.price => aarastText.providersSortPrice,
};

/// The line at the top of the list (REFINEMENT_SPEC 2.7): «32 مزوّدًا في
/// صنعاء» from the page's own total, and the order the list is really in
/// («الأنسب ▾», the server's `sort`), which opens the order's sheet. The
/// phone's saved copy says «نسخة محفوظة» there instead: no order was applied
/// to it. No «0» while it loads, nor an earlier filter's number.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.totalProviders;
    final answered =
        provider.providers.isNotEmpty &&
        provider.providersAnswerFilters &&
        total > 0;
    if (!answered) {
      // The line keeps its room while a filter loads.
      return const SizedBox(height: AarastV3Size.touch);
    }
    final city = provider.cities
        .where((city) => city.id == provider.cityId)
        .firstOrNull
        ?.nameAr;
    final count = aarastText.providersCount(total);
    // The order the server says it applied; before any answer, the asked.
    final applied = provider.appliedSort ?? provider.sort;
    final Widget end;
    if (provider.saysSavedCopy) {
      end = Row(
        key: const ValueKey('providers-saved-copy'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.wifiOff,
            size: AarastV3Icon.sm,
            color: AarastV3Color.textMuted,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Text(
            aarastText.providersSavedCopy,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      );
    } else {
      end = Semantics(
        button: true,
        label: aarastText.providersSortButtonLabel(providerSortLabel(applied)),
        excludeSemantics: true,
        onTap: () => _openSortSheet(context, provider),
        child: AarastPressable(
          key: const ValueKey('providers-sort-button'),
          onTap: () => _openSortSheet(context, provider),
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AarastV3Size.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    providerSortLabel(applied),
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: context.accent.primary,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Icon(
                    LucideIcons.chevronDown,
                    size: AarastV3Icon.sm,
                    color: context.accent.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AarastV3Size.touch),
      child: Row(
        children: [
          Expanded(
            child: Text(
              city == null || city.trim().isEmpty
                  ? count
                  : aarastText.providersCountInCity(count, city),
              key: const ValueKey('providers-results-count'),
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          end,
        ],
      ),
    );
  }
}

Future<void> _openSortSheet(
  BuildContext context,
  ProviderMarketplaceProvider provider,
) => showJourneySheet<void>(
  context: context,
  builder: (_) => _SortSheet(provider: provider),
);

/// «الترتيب»: the three orders, «الأقل سعرًا» only with a category (prices
/// compare inside one kind), and «كيف نرتّب؟» opening in place how each
/// works (PROVIDER_RANKING.md), so the reader sees why the list is in its
/// order without leaving the choice.
class _SortSheet extends StatefulWidget {
  const _SortSheet({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  bool _how = false;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    Widget step(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
      child: Text(
        text,
        style: JourneyType.of(
          JourneyType.small,
          color: AarastV3Color.textMuted,
          height: AarastV3Line.reading,
        ),
      ),
    );
    return JourneySheetBody(
      key: const ValueKey('providers-sort-sheet'),
      title: aarastText.providersSortTitle,
      children: [
        for (final sort in ProviderSort.values) ...[
          JourneyOption(
            key: ValueKey('providers-sort-${sort.wire}'),
            title: providerSortLabel(sort),
            subtitle: sort == ProviderSort.price && !provider.priceSortOffered
                ? aarastText.providersSortPriceNeedsCategory
                : null,
            selected: provider.sort == sort,
            onTap: sort == ProviderSort.price && !provider.priceSortOffered
                ? null
                : () {
                    Navigator.of(context).pop();
                    provider.setSort(sort);
                  },
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('providers-sort-how'),
            label: aarastText.providersSortHow,
            icon: _how ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            color: context.accent.primary,
            onPressed: () => setState(() => _how = !_how),
          ),
        ),
        if (_how)
          Column(
            key: const ValueKey('providers-ranking-sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              step(aarastText.providersSortHowBest1),
              step(aarastText.providersSortHowBest2),
              step(aarastText.providersSortHowBest3),
              step(aarastText.providersSortHowRating),
              step(aarastText.providersSortHowPrice),
            ],
          ),
      ],
    );
  }
}

/// «التصفية»: the city and, with a wedding day still to come, hiding those
/// known to take nothing that day; the button says how many that shows.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final day = provider.eventDate;
        final canHide = day != null && !planDayIsPast(day, appNow());
        Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
          child: Text(
            text,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        );
        return JourneySheetBody(
          key: const ValueKey('providers-filter-sheet'),
          title: aarastText.providersFilterTitle,
          bottom: JourneyButton(
            key: const ValueKey('directory-filter-apply'),
            label: provider.isLoading
                ? aarastText.providersFilterCounting
                : aarastText.providersFilterShow(provider.totalProviders),
            expand: true,
            large: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          children: [
            label(aarastText.providersFilterCity),
            Wrap(
              spacing: AarastV3Space.x2,
              runSpacing: AarastV3Space.x2,
              children: [
                JourneyChip(
                  key: const ValueKey('city-pill-all'),
                  label: aarastText.providersFilterAllCities,
                  selected: provider.cityId == null,
                  onTap: () => provider.setCity(null),
                ),
                for (final city in provider.cities)
                  JourneyChip(
                    key: ValueKey('city-pill-${city.id}'),
                    label: city.nameAr,
                    selected: provider.cityId == city.id,
                    onTap: () => provider.setCity(city.id),
                  ),
              ],
            ),
            if (canHide) ...[
              const SizedBox(height: AarastV3Space.x4),
              AarastPressable(
                key: const ValueKey('providers-hide-busy'),
                onTap: () => provider.setHideBusy(!provider.hideBusy),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AarastV3Size.row,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aarastText.providersFilterHideBusy,
                              style: JourneyType.of(
                                JourneyType.body,
                                weight: JourneyType.bold,
                              ),
                            ),
                            Text(
                              aarastText.providersFilterHideBusyHelp,
                              style: JourneyType.of(
                                JourneyType.small,
                                color: AarastV3Color.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x3),
                      JourneyToggle(
                        value: provider.hideBusy,
                        semanticLabel: aarastText.providersFilterHideBusy,
                        onChanged: provider.setHideBusy,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_activeFilters(provider) > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: JourneyTextAction(
                  key: const ValueKey('providers-filter-clear'),
                  label: aarastText.providersFilterClear,
                  color: context.accent.primary,
                  onPressed: () async {
                    await provider.setCity(null);
                    await provider.setHideBusy(false);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
