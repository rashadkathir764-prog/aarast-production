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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('marketplace-search-field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          decoration: InputDecoration(
            hintText: 'ابحث عن مزود أو خدمة',
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
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

/// شريط فئات أفقي أنيق — "الكل" ثم فئات المزودين على شكل حبوب،
/// المحددة بلون العنّاب، مع زر تصفية للمدينة على اليسار.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = provider.categoryId;
    final categories = provider.categories;

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          _CityFilterChip(provider: provider),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                AarastFilterPill(
                  label: 'الكل',
                  selected: selectedCategory == null,
                  onTap: () => provider.setCategory(null),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: 8),
                  AarastFilterPill(
                    label: category.nameAr,
                    selected: selectedCategory == category.id,
                    onTap: () => provider.setCategory(category.id),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityFilterChip extends StatelessWidget {
  const _CityFilterChip({required this.provider});

  final ProviderMarketplaceProvider provider;

  // معرّفات المدن UUIDs من الخادم — لا تصادم مع هذا الحارس.
  static const _allCitiesSentinel = '__all_cities__';

  @override
  Widget build(BuildContext context) {
    final selectedCity = provider.cityId;
    final hasCity = selectedCity != null;
    final cityLabel = hasCity
        ? provider.cities
              .firstWhere(
                (city) => city.id == selectedCity,
                orElse: () => const MarketplaceCity(id: '', nameAr: 'المدينة'),
              )
              .nameAr
        : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: InkWell(
        key: const Key('city-filter-trigger'),
        onTap: () => _showCityPicker(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hasCity ? AppTheme.brandMuted : AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: hasCity ? AppTheme.brand : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.mapPin, size: 15, color: AppTheme.brand),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  cityLabel ?? 'المدينة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: AppTheme.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// لوحة صغيرة أنيقة مثبتة من اليمين: المدن حبوب مرصوصة في صفّين-ثلاثة
  /// بهوية شرائح الفلترة الموحدة — بدل القائمة الطويلة الوردية السابقة.
  Future<void> _showCityPicker(BuildContext context) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final trigger = context.findRenderObject()! as RenderBox;
    final anchor = trigger.localToGlobal(Offset.zero, ancestor: overlay);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay.size.width,
        anchor.dy + trigger.size.height + 8,
        16,
        0,
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 268),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المدينة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    AarastFilterPill(
                      key: const ValueKey('city-pill-all'),
                      label: 'كل المدن',
                      selected: provider.cityId == null,
                      onTap: () => Navigator.pop(context, _allCitiesSentinel),
                    ),
                    for (final city in provider.cities)
                      AarastFilterPill(
                        key: ValueKey('city-pill-${city.id}'),
                        label: city.nameAr,
                        selected: provider.cityId == city.id,
                        onTap: () => Navigator.pop(context, city.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (result == null) return;
    await provider.setCity(result == _allCitiesSentinel ? null : result);
  }
}

class _NoBudgetMatchesCard extends StatelessWidget {
  const _NoBudgetMatchesCard({required this.intent, required this.onClear});

  final ProviderBudgetMatchIntent intent;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final amount = intent.hasBudget
        ? '${_formatMoney(intent.allocatedValue)} ر.ي'
        : 'بدون مبلغ محدد';
    final message = intent.hasBudget
        ? 'لم نجد خدمة بسعر منشور قريب من $amount. سنعرض لك مزودين من نفس البند، وطلب العرض سيحمل ميزانيتك تلقائيًا حتى يرد المزود بسعر واضح.'
        : 'لم نجد خدمة بسعر منشور لهذا البند. اختر مزوداً مناسباً واطلب عرضاً لتأكيد السعر.';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.canvas,
      border: Border.all(color: AppTheme.brandMuted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.search, color: AppTheme.focus),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لا توجد أسعار مطابقة تماماً',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                    label: const Text('عرض كل المزودين'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    final budgetLabel = intent.hasBudget
        ? '${_formatMoney(intent.allocatedValue)} ر.ي'
        : 'بدون مبلغ محدد';
    final rangeLabel = intent.hasBudget
        ? '${_formatMoney(intent.minPrice!)} - ${_formatMoney(intent.maxPrice!)} ر.ي'
        : 'حسب فئة البند فقط';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.canvas,
      border: Border.all(color: AppTheme.brandMuted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.wallet, color: AppTheme.focus),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حسب ميزانية بند ${intent.budgetCategoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName == null
                      ? '$budgetLabel · $rangeLabel'
                      : '$categoryName · $budgetLabel · $rangeLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إزالة فلتر الميزانية',
            onPressed: onClear,
            icon: const Icon(LucideIcons.x),
          ),
        ],
      ),
    );
  }
}
