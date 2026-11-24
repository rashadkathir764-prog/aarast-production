part of 'provider_marketplace_screen.dart';

class _MarketplaceSearch extends StatelessWidget {
  const _MarketplaceSearch({
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
      borderRadius: BorderRadius.circular(AarastV3Radius.card),
      borderSide: BorderSide(color: color, width: width),
    );
    final city = provider.cities
        .where((city) => city.id == provider.cityId)
        .firstOrNull;
    // w30 «فلتر» inside the box, at its end (Rashad 2026-11-18): a box of
    // its own beside the search was width lost. A place picked says its
    // name, softly: it is a reminder, not the screen's action.
    final picked = city != null;
    void open() => showJourneySheet<void>(
      context: context,
      builder: (_) => _DirectoryFilterSheet(provider: provider),
    );
    final filter = Semantics(
      button: true,
      label: picked ? 'فلتر: ${city.nameAr}' : 'فلتر',
      // RA-MO-361: the InkWell is hidden with its words; the tap is said
      // here, or a screen reader's double tap did nothing.
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('city-filter-trigger'),
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        onTap: open,
        // The 48 target; the drawn pill inside it.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AarastV3Space.x12,
            minHeight: AarastV3Space.x12,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: picked ? AarastV3Space.x2 : AarastV3Space.x1,
                vertical: AarastV3Space.x1,
              ),
              decoration: BoxDecoration(
                color: picked ? context.accent.primarySoft : null,
                borderRadius: BorderRadius.circular(AarastV3Radius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: AarastV3Icon.md,
                    color: picked
                        ? context.accent.primary
                        : AarastV3Color.textMuted,
                  ),
                  if (picked) ...[
                    const SizedBox(width: AarastV3Space.x1),
                    Text(
                      city.nameAr,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('marketplace-search-field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          cursorColor: context.accent.primary,
          decoration: InputDecoration(
            // The kinds people look for, in their words.
            hintText: context.say(
              'دوّر قاعة، مصور، فنان…',
              'دوّري صالة، مصورة، كوافيرة…',
            ),
            hintMaxLines: 1,
            hintStyle: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textFaint,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AarastV3Space.x3,
            ),
            filled: true,
            fillColor: AarastV3Color.paper,
            prefixIcon: const Icon(
              LucideIcons.search,
              size: AarastV3Icon.md,
              color: AarastV3Color.textMuted,
            ),
            border: border(AarastV3Color.line, 1),
            enabledBorder: border(AarastV3Color.line, 1),
            focusedBorder: border(context.accent.primary, 2),
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: AarastV3Space.x1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      tooltip: context.say('امسح البحث', 'امسحي البحث'),
                      onPressed: () {
                        controller.clear();
                        provider.setSearch('');
                      },
                      icon: const Icon(LucideIcons.x, size: AarastV3Icon.md),
                    ),
                  filter,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// f02 the kinds of providers as chips; «فلتر» (w30) for the place sits at
/// the search box's end (Rashad 2026-11-18).
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = provider.categoryId;
    // G40: a search from a money item filters by all of its categories; its
    // chip comes first, selected, so it is never cut off the screen (f02
    // draws the searched kind first).
    final item = provider.budgetMatchIntent;
    final itemChip = item != null && item.providerCategoryIds.isNotEmpty
        ? item
        : null;
    // The strip is a chip's touch band tall, so every chip keeps its 48.
    return SizedBox(
      height: AarastV3Size.touch,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          if (itemChip != null) ...[
            JourneyChip(
              key: const ValueKey('category-chip-item'),
              label: itemChip.budgetCategoryName,
              icon: providerServiceIcon(itemChip.budgetCategoryName),
              selected: true,
              selectedColor: context.accent.primary,
              onTap: () {},
            ),
            const SizedBox(width: AarastV3Space.x2),
          ],
          JourneyChip(
            key: const ValueKey('category-chip-all'),
            label: 'الكل',
            selected: selectedCategory == null && itemChip == null,
            selectedColor: context.accent.primary,
            onTap: () => provider.setCategory(null),
          ),
          for (final category in provider.categories) ...[
            const SizedBox(width: AarastV3Space.x2),
            JourneyChip(
              key: ValueKey('category-chip-${category.id}'),
              label: providerKindName(context, category),
              icon: providerServiceIcon(category.nameAr),
              selected: selectedCategory == category.id,
              selectedColor: context.accent.primary,
              onTap: () => provider.setCategory(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// w30 «فلتر»: the kind and the place, and how many that shows.
class _DirectoryFilterSheet extends StatelessWidget {
  const _DirectoryFilterSheet({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
          child: Text(
            text,
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: AarastV3Color.textMuted,
            ),
          ),
        );
        final total = provider.totalProviders;
        return JourneySheetBody(
          title: 'فلتر',
          children: [
            label('القسم'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                JourneyChip(
                  label: 'الكل',
                  selected:
                      provider.categoryId == null &&
                      (provider
                              .budgetMatchIntent
                              ?.providerCategoryIds
                              .isEmpty ??
                          true),
                  selectedColor: context.accent.primary,
                  onTap: () => provider.setCategory(null),
                ),
                for (final category in provider.categories)
                  JourneyChip(
                    label: providerKindName(context, category),
                    selected: provider.categoryId == category.id,
                    selectedColor: context.accent.primary,
                    onTap: () => provider.setCategory(category.id),
                  ),
              ],
            ),
            const SizedBox(height: AarastV3Space.x3),
            label('المكان'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                JourneyChip(
                  key: const ValueKey('city-pill-all'),
                  label: 'كل المدن',
                  selected: provider.cityId == null,
                  selectedColor: context.accent.primary,
                  onTap: () => provider.setCity(null),
                ),
                for (final city in provider.cities)
                  JourneyChip(
                    key: ValueKey('city-pill-${city.id}'),
                    label: city.nameAr,
                    selected: provider.cityId == city.id,
                    selectedColor: context.accent.primary,
                    onTap: () => provider.setCity(city.id),
                  ),
              ],
            ),
            const SizedBox(height: AarastV3Space.x4),
            JourneyButton(
              key: const ValueKey('directory-filter-apply'),
              label: provider.isLoading
                  ? 'نحسب…'
                  : total == 0
                  ? 'ما في مزودين بهذا الفلتر'
                  : 'اعرض ${arabicCount(total, one: 'مزود واحد', two: 'مزودين اثنين', few: 'مزودين', many: 'مزود')}',
              background: context.accent.primary,
              expand: true,
              large: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// f02 «قريبين من بندك 500 ألف»: why these providers come first.
class _BudgetMatchContextCard extends StatelessWidget {
  const _BudgetMatchContextCard({
    required this.intent,
    required this.categoryName,
    required this.onClear,
  });

  final ProviderBudgetMatchIntent intent;
  final String? categoryName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final shown =
        context.watch<FinanceProvider?>()?.shownAmount ?? (String text) => text;
    final text = intent.hasBudget
        ? 'قريبين من بند ${intent.budgetCategoryName} ${shown(fullMoneyParts(intent.allocatedValue, currencyCode: defaultCurrencyCode).plainText)}'
        : 'حسب بند ${intent.budgetCategoryName}';
    return JourneyBox(
      color: context.accent.primarySoft,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AarastV3Space.x3,
        AarastV3Space.x1,
        AarastV3Space.x1,
        AarastV3Space.x1,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.sparkles,
            size: AarastV3Icon.md,
            color: context.accent.primary,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: context.accent.primary,
              ),
            ),
          ),
          IconButton(
            // RA-MO-262: the filter is the plan's item, not «الميزانية».
            tooltip: 'إلغاء فلتر البند',
            onPressed: onClear,
            icon: Icon(LucideIcons.x, color: context.accent.primary),
          ),
        ],
      ),
    );
  }
}
