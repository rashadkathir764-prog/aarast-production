part of 'provider_marketplace_screen.dart';

class _TopMarketplaceCommandCard extends StatelessWidget {
  const _TopMarketplaceCommandCard({
    required this.embedded,
    required this.provider,
    required this.onOpenFavorites,
    required this.onOpenConversations,
  });

  final bool embedded;
  final ProviderMarketplaceProvider provider;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenConversations;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          _CircleButton(
            icon: LucideIcons.chevronRight,
            onTap: () {
              if (context.canPop()) context.pop();
            },
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموردون',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.title,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'ابحث وقارن، ثم افتح المورد المناسب لطلب عرض.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (provider.includesAccountData) ...[
          const SizedBox(width: 8),
          _MarketplaceHeaderAction(
            key: const Key('favorite-providers-action'),
            icon: LucideIcons.heart,
            tooltip: 'الموردون المحفوظون',
            badgeValue: provider.favoriteProviderIds.length,
            onTap: onOpenFavorites,
          ),
          const SizedBox(width: 6),
          _MarketplaceHeaderAction(
            key: const Key('user-conversations-action'),
            icon: LucideIcons.messagesSquare,
            tooltip: 'المحادثات',
            onTap: onOpenConversations,
          ),
        ],
      ],
    );
  }
}

class _MarketplaceHeaderAction extends StatelessWidget {
  const _MarketplaceHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeValue = 0,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeValue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: AppTheme.surface,
            shape: CircleBorder(side: BorderSide(color: AppTheme.border)),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 20, color: AppTheme.burgundy),
              ),
            ),
          ),
        ),
        if (badgeValue > 0)
          PositionedDirectional(
            top: -4,
            end: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.burgundy,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.ivory, width: 2),
              ),
              child: Text(
                badgeValue > 99 ? '99+' : '$badgeValue',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
            hintText: 'ابحث عن مورد أو خدمة',
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
            color: hasCity ? AppTheme.burgundySoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: hasCity ? AppTheme.burgundy : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 15,
                color: AppTheme.burgundy,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  cityLabel ?? 'المدينة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: AppTheme.burgundy,
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
                    color: AppTheme.muted,
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
        ? 'لم نجد خدمة بسعر منشور قريب من $amount. سنعرض لك موردين من نفس البند، وطلب العرض سيحمل ميزانيتك تلقائيًا حتى يرد المورد بسعر واضح.'
        : 'لم نجد خدمة بسعر منشور لهذا البند. اختر مورداً مناسباً واطلب عرضاً لتأكيد السعر.';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.search, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لا توجد أسعار مطابقة تماماً',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
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
                    label: const Text('عرض كل الموردين'),
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
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.wallet, color: AppTheme.gold),
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
                    color: AppTheme.burgundyDeep,
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
                    color: AppTheme.muted,
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
