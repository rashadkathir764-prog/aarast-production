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
    this.place = ProviderRowPlace.only,
    this.showKind = true,
  });

  final MarketplaceProvider provider;
  final ProviderBudgetMatchIntent? budgetIntent;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  /// Where the row stands in its group.
  final ProviderRowPlace place;

  /// False under a kind's own title, where the kind would repeat it.
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final category = showKind ? _providerKindLabel(context, provider) : null;
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
      place: place,
      detailsButtonKey: Key('super5-provider-details-${provider.id}'),
    );
  }
}

/// A fixed dimension of this layout, not a spacing step (D74): a shelf
/// card's width (Rashad 2026-11-19). Two cards and the edge of a third on a
/// phone, so the row says it goes on; its picture is as tall as it is wide.
const _shelfCardWidth = 168.0;

/// The widest a shelf card grows with a large text size.
const _shelfCardWidestWidth = 216.0;

/// A section's title, with «الكل» to open the kind when it holds more than
/// what is shown.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.onAll,
    this.allKey,
    super.key,
  });

  final String title;
  final VoidCallback? onAll;
  final Key? allKey;

  @override
  Widget build(BuildContext context) {
    final all = onAll;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
          ),
        ),
        if (all != null)
          JourneyTextAction(
            key: allKey,
            label: 'الكل',
            icon: Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            color: context.accent.primary,
            onPressed: all,
          ),
      ],
    );
  }
}

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
    final width = scaler
        .scale(_shelfCardWidth)
        .clamp(_shelfCardWidth, _shelfCardWidestWidth);
    // The square picture, the gap under it, and the words as the text
    // draws them at the reader's size: the name on two lines, the rating,
    // the price. Measured, not guessed: a guessed room cut a two-line name
    // at a large text size.
    double line(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'أ', style: style),
        textDirection: TextDirection.rtl,
        textScaler: scaler,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final words =
        2 * line(JourneyType.of(JourneyType.body, weight: JourneyType.bold)) +
        math.max(line(JourneyType.of(JourneyType.small)), AarastV3Icon.sm) +
        line(JourneyType.of(JourneyType.small, weight: JourneyType.bold)) +
        3 * AarastV3Space.x1;
    final height = width + AarastV3Space.x2 + words;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: title,
          onAll: onAll,
          allKey: ValueKey('providers-shelf-all-${providers.first.id}'),
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
  final span = _providerPublishedSpan(provider);
  if (span == null) return null;
  final amount = providerPriceText(span.min, span.min, span.currency);
  return span.max > span.min ? 'من $amount' : amount;
}

/// The server's summary when it has one, else the services' own prices in
/// one currency ([providerPriceSpan]).
({num min, num max, String currency})? _providerPublishedSpan(
  MarketplaceProvider provider,
) {
  final summary = provider.serviceSummary;
  final summaryMin = _moneyValueOrNull(summary?.minPrice);
  if (summaryMin != null) {
    final summaryMax = _moneyValueOrNull(summary?.maxPrice) ?? summaryMin;
    return (
      min: summaryMin,
      max: summaryMax < summaryMin ? summaryMin : summaryMax,
      currency: currencyCodeFromDisplayInput(summary?.currency),
    );
  }
  return providerPriceSpan(provider.services);
}

/// صورة الغلاف وحدها تملأ رأس الكرت. الشعار يظهر صغيرًا جنب الاسم: شعار
/// مكبّر بعرض الكرت كان وجهًا مقصوصًا عند الفم (جوال رشاد 2026-11-18). صور
/// الخدمات ما تنعرض للعرسان لأنها ما تتراجع (D62).
String? _providerImageUrl(MarketplaceProvider provider) =>
    provider.cardCoverUrl;

/// RA-MO-364: the logo's 480px copy when the server made one.
String? _providerLogoUrl(MarketplaceProvider provider) => provider.cardLogoUrl;

/// نطاق أسعار المزود المنشورة (أقل–أعلى) عبر خدماته، أو سعر واحد عند التطابق.
String? _providerPriceRangeLabel(MarketplaceProvider provider) {
  final span = _providerPublishedSpan(provider);
  if (span != null) return providerPriceText(span.min, span.max, span.currency);
  final summary = provider.serviceSummary;
  final hasServices =
      (summary?.activeCount ?? 0) > 0 || provider.services.isNotEmpty;
  return hasServices ? 'السعر عبر طلب عرض' : null;
}
