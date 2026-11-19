part of 'provider_marketplace_screen.dart';

class _LocationContextCard extends StatelessWidget {
  const _LocationContextCard({
    required this.location,
    required this.onCompleteLocation,
  });

  final WeddingLocationDraft? location;
  final VoidCallback onCompleteLocation;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const Key('marketplace-location-prompt'),
      padding: EdgeInsets.zero,
      child: JourneyListRow(
        icon: LucideIcons.mapPin,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
        title: 'وين عرسك؟',
        subtitle: context.say(
          'كمّل مكان العرس ونرتب لك مزودين مدينتك أول',
          'كمّلي مكان العرس ونرتب لك مزودين مدينتك أول',
        ),
        onTap: onCompleteLocation,
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.budgetIntent,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final MarketplaceProvider provider;
  final ProviderBudgetMatchIntent? budgetIntent;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final category = _providerKindLabel(context, provider);
    final location = _providerLocationLabel(provider);
    // RA-MO-259: the item is in riyals; a price in another currency is not
    // compared with it (as the provider's page does, f03), the card says
    // the category only.
    final summary = provider.serviceSummary;
    final summaryPrice = _moneyValueOrNull(summary?.minPrice);
    final (price, priceCurrency) = summaryPrice != null
        ? (summaryPrice, summary?.currency)
        : (_moneyValueOrNull(service?.basePrice), service?.currency);
    final comparable =
        currencyCodeFromDisplayInput(priceCurrency ?? defaultCurrencyCode) ==
        defaultCurrencyCode;
    final budgetStatus = budgetIntent == null
        ? null
        : price != null && !comparable
        ? _ServiceBudgetStatus.categoryOnly
        : _serviceBudgetStatus(budgetIntent!, price);
    final budgetColor = budgetStatus == null
        ? AarastV3Color.brandAccentStrong
        : _serviceBudgetStatusColor(context, budgetStatus);

    return ProviderResultCard(
      key: Key('provider-marketplace-card-${provider.id}'),
      businessName: provider.businessName,
      isFeatured: provider.isFeaturedAt(appNow()),
      isVerified: provider.isVerified,
      isClaimed: provider.isClaimed,
      ratingAverage: provider.ratingAverage,
      ratingCount: provider.ratingCount,
      categoryLabel: category,
      locationLabel: location,
      priceLabel: _providerPriceRangeLabel(provider),
      priceAgeLabel: providerPriceAgeLabel(
        provider.serviceSummary?.pricesUpdatedAt,
      ),
      imageUrl: _providerImageUrl(provider),
      logoUrl: _providerLogoUrl(provider),
      budgetStatusLabel: budgetStatus == null
          ? null
          : _serviceBudgetStatusLabel(budgetStatus),
      budgetStatusColor: budgetStatus == null ? null : budgetColor,
      isFavorite: isFavorite,
      onFavorite: onFavorite,
      onDetails: onTap,
      detailsButtonKey: Key('super5-provider-details-${provider.id}'),
    );
  }
}

/// A fixed dimension of this layout, not a spacing step (D74): a shelf
/// card's width, a little over half a phone, so the next card shows and
/// says the row goes on.
const _shelfCardWidth = 216.0;

/// One sideways row of «استكشف» (Rashad 2026-11-18): the kind's name with
/// «الكل», and its providers as shelf cards, running to the screen's edges.
class _ProviderShelfRow extends StatelessWidget {
  const _ProviderShelfRow({
    required this.title,
    required this.providers,
    required this.favorites,
    required this.onAll,
    required this.onFavorite,
    required this.onOpen,
    super.key,
  });

  final String title;
  final List<MarketplaceProvider> providers;
  final Set<String> favorites;
  final VoidCallback onAll;
  final ValueChanged<String> onFavorite;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // The photo, the padding, and three lines that grow with the text.
    final height = 132.0 + AarastV3Space.x5 + scaler.scale(66);
    final width = scaler.scale(_shelfCardWidth).clamp(_shelfCardWidth, 280.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                ),
              ),
            ),
            JourneyTextAction(
              key: ValueKey('providers-shelf-all-${providers.first.id}'),
              label: 'الكل',
              icon: Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.chevronLeft
                  : LucideIcons.chevronRight,
              color: context.accent.primary,
              onPressed: onAll,
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x1),
        // Past the list's own padding, so the row runs to the screen's
        // edges as it scrolls and its first card lines up with the page.
        // The row's own width plus the list's side padding, not the
        // screen's: the frame holds «استكشف» to 520 on a wide screen, and a
        // screen-wide row spilled off both sides there (walks 2026-11-18).
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              maxWidth: constraints.maxWidth + 2 * AarastV3Space.x4,
              minWidth: constraints.maxWidth + 2 * AarastV3Space.x4,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AarastV3Space.x4,
                ),
                itemCount: providers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AarastV3Space.x3),
                itemBuilder: (context, index) {
                  final item = providers[index];
                  return SizedBox(
                    width: width,
                    child: ProviderShelfCard(
                      key: Key('provider-shelf-card-${item.id}'),
                      businessName: item.businessName,
                      ratingAverage: item.ratingAverage,
                      ratingCount: item.ratingCount,
                      categoryLabel: _providerKindLabel(context, item),
                      locationLabel: _providerLocationLabel(item),
                      fromPriceLabel: _providerFromPriceLabel(item),
                      imageUrl: _providerImageUrl(item),
                      logoUrl: _providerLogoUrl(item),
                      isFeatured: item.isFeaturedAt(appNow()),
                      isClaimed: item.isClaimed,
                      isFavorite: favorites.contains(item.id),
                      onFavorite: () => onFavorite(item.id),
                      onDetails: () => onOpen(item.id),
                      detailsButtonKey: Key(
                        'super5-provider-details-${item.id}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The provider's kind in words: its primary kind, else its services', as
/// the plan says it ([providerKindName]). The list card and the row card
/// read this one.
String? _providerKindLabel(BuildContext context, MarketplaceProvider provider) {
  final summary = provider.serviceSummary?.categories;
  final service = provider.services.isEmpty ? null : provider.services.first;
  for (final category in [
    provider.primaryCategory,
    if (summary != null && summary.isNotEmpty) summary.first,
    service?.category,
  ]) {
    final name = providerKindName(context, category);
    if (name.isNotEmpty) return name;
  }
  return null;
}

/// «من 450,000 ر.ي»: where a provider's published prices start, or the one
/// price; null without a published price (the card then says to ask).
String? _providerFromPriceLabel(MarketplaceProvider provider) {
  final summary = provider.serviceSummary;
  var min = _moneyValueOrNull(summary?.minPrice);
  var max = _moneyValueOrNull(summary?.maxPrice);
  var currency = summary?.currency;
  if (min == null) {
    for (final service in provider.services) {
      final price = _moneyValueOrNull(service.basePrice);
      if (price == null) continue;
      currency ??= service.currency;
      min = min == null || price < min ? price : min;
      max = max == null || price > max ? price : max;
    }
  }
  if (min == null) return null;
  final amount = '${_formatMoney(min)} ${currencyLabelAr(currency)}';
  return max != null && max > min ? 'من $amount' : amount;
}

/// صورة الغلاف وحدها تملأ رأس الكرت. الشعار يظهر صغيرًا جنب الاسم: شعار
/// مكبّر بعرض الكرت كان وجهًا مقصوصًا عند الفم (جوال رشاد 2026-11-18). صور
/// الخدمات ما تنعرض للعرسان لأنها ما تتراجع (D62).
String? _providerImageUrl(MarketplaceProvider provider) {
  final cover = provider.coverUrl?.trim();
  return cover == null || cover.isEmpty ? null : cover;
}

String? _providerLogoUrl(MarketplaceProvider provider) {
  final logo = provider.logoUrl?.trim();
  return logo == null || logo.isEmpty ? null : logo;
}

/// نطاق أسعار المزود المنشورة (أقل–أعلى) عبر خدماته، أو سعر واحد عند التطابق.
String? _providerPriceRangeLabel(MarketplaceProvider provider) {
  final summary = provider.serviceSummary;
  final summaryMin = _moneyValueOrNull(summary?.minPrice);
  final summaryMax = _moneyValueOrNull(summary?.maxPrice);
  if (summaryMin != null && summaryMax != null) {
    final unit = currencyLabelAr(summary?.currency);
    if (summaryMin == summaryMax) {
      return keepCurrencyOnLine('${_formatMoney(summaryMin)} $unit');
    }
    return keepCurrencyOnLine(
      '${_formatMoney(summaryMin)} - ${_formatMoney(summaryMax)} $unit',
    );
  }

  double? min;
  double? max;
  String? currency;
  for (final service in provider.services) {
    final price = _moneyValueOrNull(service.basePrice);
    if (price == null) continue;
    currency ??= service.currency;
    min = min == null ? price : (price < min ? price : min);
    max = max == null ? price : (price > max ? price : max);
  }
  if (min == null || max == null) {
    final hasServices =
        (summary?.activeCount ?? 0) > 0 || provider.services.isNotEmpty;
    return hasServices ? 'السعر عبر طلب عرض' : null;
  }
  final unit = currencyLabelAr(currency);
  if (min == max) return keepCurrencyOnLine('${_formatMoney(min)} $unit');
  return keepCurrencyOnLine(
    '${_formatMoney(min)} - ${_formatMoney(max)} $unit',
  );
}
