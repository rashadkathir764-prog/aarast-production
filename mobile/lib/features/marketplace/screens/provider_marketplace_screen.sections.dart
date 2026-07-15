part of 'provider_marketplace_screen.dart';

class _TopMarketplaceCommandCard extends StatelessWidget {
  const _TopMarketplaceCommandCard({
    required this.embedded,
    required this.provider,
  });

  final bool embedded;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final quotes = provider.quoteRequests;
    final offersReceived = _offersReceivedCount(quotes);
    final acceptedProviders = _acceptedProviderCount(quotes);

    // ترويسة مكشوفة موحدة مع بقية التبويبات: عنوان + شارة + إجراءات.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              child: Text(
                'الموردون والعروض',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.title),
              ),
            ),
            const SizedBox(width: 10),
            AarastStatusPill(
              label: provider.includesAccountData ? 'حساب محفوظ' : 'تصفح عام',
              color: AppTheme.gold,
              backgroundColor: AppTheme.goldSoft,
              icon: provider.includesAccountData
                  ? LucideIcons.shieldCheck
                  : LucideIcons.eye,
            ),
            if (provider.includesAccountData)
              IconButton(
                key: const Key('user-conversations-action'),
                onPressed: () => context.push(AppRouter.conversations),
                icon: const Icon(LucideIcons.messagesSquare),
                tooltip: 'المحادثات',
              ),
          ],
        ),
        if (provider.includesAccountData) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniStat(
                  label: 'طلبات مرسلة',
                  value: quotes.length.toString(),
                  color: AppTheme.muted,
                ),
                _MiniStat(
                  label: 'عروض وصلت',
                  value: offersReceived.toString(),
                  color: AppTheme.gold,
                ),
                _MiniStat(
                  label: 'عروض مقبولة',
                  value: acceptedProviders.toString(),
                  color: AppTheme.success,
                ),
                _MiniStat(
                  label: 'محفوظة',
                  value: provider.favoriteProviderIds.length.toString(),
                  color: AppTheme.burgundy,
                  onTap: () => context.push(AppRouter.favoriteProviders),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          const _PublicBrowseNote(),
        ],
      ],
    );
  }
}

class _PublicBrowseNote extends StatelessWidget {
  const _PublicBrowseNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ivory.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, color: AppTheme.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'التصفح مفتوح للجميع. إرسال طلب عرض ومتابعة الردود يحتاج حسابًا محفوظًا.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: content,
    );
  }
}

class _ImportantNowCard extends StatelessWidget {
  const _ImportantNowCard({
    required this.quotes,
    required this.includesAccountData,
    required this.onOpenPlanCenter,
  });

  final List<QuoteRequest> quotes;
  final bool includesAccountData;
  final void Function(QuoteRequest quote) onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final important = _importantQuotes(quotes);
    if (important.isEmpty) return const SizedBox.shrink();

    final title = 'أهم ما يحتاج قرار الآن';
    final message = !includesAccountData
        ? 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود.'
        : 'راجع العروض الواصلة أو الطلبات المنتظرة بناءً على بيانات حسابك.';

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertCircle, color: AppTheme.burgundy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          for (final quote in important) ...[
            _ImportantQuoteRow(
              quote: quote,
              onOpenPlanCenter: () => onOpenPlanCenter(quote),
            ),
            if (quote != important.last)
              const Divider(height: 18, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _ImportantQuoteRow extends StatelessWidget {
  const _ImportantQuoteRow({
    required this.quote,
    required this.onOpenPlanCenter,
  });

  final QuoteRequest quote;
  final VoidCallback onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final action = _quoteNextActionLabel(quote);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(
            LucideIcons.fileText,
            color: AppTheme.burgundy,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _quoteProviderLabel(quote),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                action,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (quote.weddingPlanId?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenPlanCenter,
                  icon: const Icon(LucideIcons.calendarDays, size: 18),
                  label: const Text('فتح مركز الخطة'),
                ),
              ],
            ],
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
          const SizedBox(width: 8),
          _CityFilterChip(provider: provider),
        ],
      ),
    );
  }
}

class _CityFilterChip extends StatelessWidget {
  const _CityFilterChip({required this.provider});

  final ProviderMarketplaceProvider provider;

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

    return PopupMenuButton<String?>(
      onSelected: provider.setCity,
      tooltip: 'تصفية حسب المدينة',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('كل المدن')),
        for (final city in provider.cities)
          PopupMenuItem<String?>(value: city.id, child: Text(city.nameAr)),
      ],
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
              LucideIcons.slidersHorizontal,
              size: 16,
              color: AppTheme.burgundy,
            ),
            if (cityLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                cityLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
