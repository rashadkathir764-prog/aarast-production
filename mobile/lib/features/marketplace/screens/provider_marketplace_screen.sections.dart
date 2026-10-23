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
      borderRadius: BorderRadius.circular(18),
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
          style: JourneyType.of(JourneyType.bodyLarge, weight: JourneyType.bold),
          cursorColor: AarastV3Color.cobalt,
          decoration: InputDecoration(
            hintText: 'دوّر على مزود أو خدمة',
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
            focusedBorder: border(AarastV3Color.cobalt, 2),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'امسح البحث',
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
    final city = provider.cities
        .where((city) => city.id == provider.cityId)
        .firstOrNull;
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                JourneyChip(
                  key: const ValueKey('category-chip-all'),
                  label: 'الكل',
                  selected: selectedCategory == null,
                  selectedColor: AarastV3Color.cobalt,
                  onTap: () => provider.setCategory(null),
                ),
                for (final category in provider.categories) ...[
                  const SizedBox(width: 8),
                  JourneyChip(
                    key: ValueKey('category-chip-${category.id}'),
                    label: category.nameAr,
                    icon: providerServiceIcon(category.nameAr),
                    selected: selectedCategory == category.id,
                    selectedColor: AarastV3Color.cobalt,
                    onTap: () => provider.setCategory(category.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          JourneyChip(
            key: const Key('city-filter-trigger'),
            label: city?.nameAr ?? 'فلتر',
            icon: LucideIcons.slidersHorizontal,
            selected: city != null,
            selectedColor: AarastV3Color.cobalt,
            onTap: () => showAarastBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
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
          padding: const EdgeInsets.only(bottom: 8),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'فلتر',
                style: JourneyType.of(
                  JourneyType.display,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: 14),
              label('القسم'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  JourneyChip(
                    label: 'الكل',
                    selected: provider.categoryId == null,
                    selectedColor: AarastV3Color.cobalt,
                    onTap: () => provider.setCategory(null),
                  ),
                  for (final category in provider.categories)
                    JourneyChip(
                      label: category.nameAr,
                      selected: provider.categoryId == category.id,
                      selectedColor: AarastV3Color.cobalt,
                      onTap: () => provider.setCategory(category.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              label('المكان'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  JourneyChip(
                    key: const ValueKey('city-pill-all'),
                    label: 'كل المدن',
                    selected: provider.cityId == null,
                    selectedColor: AarastV3Color.cobalt,
                    onTap: () => provider.setCity(null),
                  ),
                  for (final city in provider.cities)
                    JourneyChip(
                      key: ValueKey('city-pill-${city.id}'),
                      label: city.nameAr,
                      selected: provider.cityId == city.id,
                      selectedColor: AarastV3Color.cobalt,
                      onTap: () => provider.setCity(city.id),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              JourneyButton(
                key: const ValueKey('directory-filter-apply'),
                label: provider.isLoading
                    ? 'نحسب…'
                    : total == 0
                    ? 'ما في مزودين بهذا الفلتر'
                    : 'اعرض ${arabicCount(total, one: 'مزود واحد', two: 'مزودين اثنين', few: 'مزودين', many: 'مزود')}',
                background: AarastV3Color.cobalt,
                expand: true,
                large: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoBudgetMatchesCard extends StatelessWidget {
  const _NoBudgetMatchesCard({required this.intent, required this.onClear});

  final ProviderBudgetMatchIntent intent;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // D9: an amount inside a sentence is the plain form.
    final amount = intent.hasBudget
        ? compactYemeniMoneyParts(intent.allocatedValue).plainText
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyNote(
          text: amount == null
              ? 'ما لقينا سعر منشور لهذا البند. اختر مزود واطلب منه عرض.'
              : 'ما لقينا سعر منشور قريب من $amount. هذي مزودين من نفس القسم، واطلب منهم عرض.',
          icon: LucideIcons.search,
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            label: 'اعرض كل المزودين',
            icon: LucideIcons.slidersHorizontal,
            color: AarastV3Color.cobalt,
            onPressed: onClear,
          ),
        ),
      ],
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
    final text = intent.hasBudget
        ? 'قريبين من بند ${intent.budgetCategoryName} ${compactYemeniMoneyParts(intent.allocatedValue).plainText}'
        : 'حسب بند ${intent.budgetCategoryName}';
    return JourneyBox(
      color: AarastV3Color.cobaltSoft,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
      child: Row(
        children: [
          const Icon(
            LucideIcons.sparkles,
            size: 18,
            color: AarastV3Color.cobalt,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: AarastV3Color.cobalt,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إزالة فلتر الميزانية',
            onPressed: onClear,
            icon: const Icon(LucideIcons.x, color: AarastV3Color.cobalt),
          ),
        ],
      ),
    );
  }
}
