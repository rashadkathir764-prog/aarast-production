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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('marketplace-search-field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          style: JourneyType.of(
            JourneyType.bodyLarge,
            weight: JourneyType.bold,
          ),
          cursorColor: context.accent.primary,
          decoration: InputDecoration(
            hintText: context.say(
              'دوّر على مزود أو خدمة',
              'دوّري على مزود أو خدمة',
            ),
            hintStyle: JourneyType.of(
              JourneyType.bodyLarge,
              color: AarastV3Color.textFaint,
            ),
            filled: true,
            fillColor: AarastV3Color.paper,
            prefixIcon: const Icon(
              LucideIcons.search,
              color: AarastV3Color.textMuted,
            ),
            border: border(AarastV3Color.line, 1),
            enabledBorder: border(AarastV3Color.line, 1),
            focusedBorder: border(context.accent.primary, 2),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.say('امسح البحث', 'امسحي البحث'),
                    onPressed: () {
                      controller.clear();
                      provider.setSearch('');
                    },
                    icon: const Icon(LucideIcons.x),
                  ),
          ),
        );
      },
    );
  }
}

/// f02 the kinds of providers as chips, and «فلتر» (w30) for the place.
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
    final city = provider.cities
        .where((city) => city.id == provider.cityId)
        .firstOrNull;
    return SizedBox(
      height: AarastV3Space.x10,
      child: Row(
        children: [
          Expanded(
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
                    label: category.nameAr,
                    icon: providerServiceIcon(category.nameAr),
                    selected: selectedCategory == category.id,
                    selectedColor: context.accent.primary,
                    onTap: () => provider.setCategory(category.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          JourneyChip(
            key: const Key('city-filter-trigger'),
            label: city?.nameAr ?? 'فلتر',
            icon: LucideIcons.slidersHorizontal,
            selected: city != null,
            selectedColor: context.accent.primary,
            onTap: () => showJourneySheet<void>(
              context: context,
              builder: (_) => _DirectoryFilterSheet(provider: provider),
            ),
          ),
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
                    label: category.nameAr,
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
        ? 'قريبين من بند ${intent.budgetCategoryName} ${shown(compactYemeniMoneyParts(intent.allocatedValue).plainText)}'
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
          Icon(LucideIcons.sparkles, size: 18, color: context.accent.primary),
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
