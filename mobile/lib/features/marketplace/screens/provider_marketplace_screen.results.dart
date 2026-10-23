part of 'provider_marketplace_screen.dart';

class _BudgetMatchedServicesSection extends StatelessWidget {
  const _BudgetMatchedServicesSection({
    required this.intent,
    required this.services,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final List<MarketplaceService> services;
  final ValueChanged<String> onOpenProvider;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final shown = services.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('خدمات قريبة من بندك'),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 360
                ? constraints.maxWidth - 20
                : 300.0;
            return SingleChildScrollView(
              key: const Key('budget-matched-services-carousel'),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < shown.length; index++) ...[
                    SizedBox(
                      width: cardWidth,
                      child: _BudgetMatchedServiceCard(
                        intent: intent,
                        service: shown[index],
                        onOpenProvider: () =>
                            onOpenProvider(shown[index].providerId),
                        onRequestQuote: () => onRequestQuote(shown[index]),
                      ),
                    ),
                    if (index < shown.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BudgetMatchedServiceCard extends StatelessWidget {
  const _BudgetMatchedServiceCard({
    required this.intent,
    required this.service,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final MarketplaceService service;
  final VoidCallback onOpenProvider;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final price = _moneyValueOrNull(service.basePrice);
    final status = _serviceBudgetStatus(intent, price);
    final color = _serviceBudgetStatusColor(status);
    final providerName = service.provider?.businessName ?? 'مزود';
    final category = service.category?.nameAr.trim() ?? '';
    final facts = [
      price == null
          ? 'السعر بالعرض'
          : formatCompactMoney(price, currencyCode: service.currency ?? 'YER'),
      if (category.isNotEmpty) category,
      ?service.city?.nameAr,
    ].join(' · ');
    return JourneyBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(
                icon: providerServiceIcon(service.category?.nameAr ?? service.title),
                color: AarastV3Color.cobalt,
                soft: AarastV3Color.cobaltSoft,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              JourneyTag(
                label: _serviceBudgetStatusLabel(status),
                color: color,
                soft: color.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            facts,
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: AarastV3Color.cobalt,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _serviceBudgetReason(intent, service, price, status),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: JourneyButton.quiet(
                  label: 'التفاصيل',
                  onPressed: onOpenProvider,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: JourneyButton(
                  label: 'اطلب عرض',
                  background: AarastV3Color.cobalt,
                  onPressed: onRequestQuote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        color: AarastV3Color.cobalt,
        soft: AarastV3Color.cobaltSoft,
        title: 'وين عرسك؟',
        subtitle: 'كمّل مكان العرس ونرتب لك مزودين مدينتك أول',
        onTap: onCompleteLocation,
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.cityLabel});

  final int count;
  final String? cityLabel;

  @override
  Widget build(BuildContext context) {
    final city = cityLabel?.trim();
    final where = city == null || city.isEmpty ? '' : ' في $city';
    return Text(
      '${arabicCount(count, one: 'مزود واحد', two: 'مزودين اثنين', few: 'مزودين', many: 'مزود')}$where',
      style: JourneyType.of(
        JourneyType.body,
        weight: JourneyType.bold,
        color: AarastV3Color.textMuted,
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
    final primaryCategory = provider.primaryCategory?.nameAr.trim();
    final summaryCategories = provider.serviceSummary?.categories;
    final summaryCategory =
        summaryCategories == null || summaryCategories.isEmpty
        ? null
        : summaryCategories.first.nameAr.trim();
    final category = primaryCategory?.isNotEmpty == true
        ? primaryCategory
        : summaryCategory?.isNotEmpty == true
        ? summaryCategory
        : service?.category?.nameAr.trim();
    final location = _providerLocationLabel(provider);
    final price =
        _moneyValueOrNull(provider.serviceSummary?.minPrice) ??
        _moneyValueOrNull(service?.basePrice);
    final budgetStatus = budgetIntent == null
        ? null
        : _serviceBudgetStatus(budgetIntent!, price);
    final budgetColor = budgetStatus == null
        ? AarastV3Color.brandAccentStrong
        : _serviceBudgetStatusColor(budgetStatus);

    return ProviderResultCard(
      key: Key('provider-marketplace-card-${provider.id}'),
      businessName: provider.businessName,
      isFeatured: provider.isFeatured,
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

/// أفضل صورة تمثّل المزود في القائمة: الغلاف ثم الشعار ثم أول صورة خدمة.
String? _providerImageUrl(MarketplaceProvider provider) {
  final cover = provider.coverUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  final logo = provider.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
  for (final service in provider.services) {
    for (final image in service.images) {
      final url = image.imageUrl.trim();
      if (url.isNotEmpty) return url;
    }
  }
  return null;
}

/// نطاق أسعار المزود المنشورة (أقل–أعلى) عبر خدماته، أو سعر واحد عند التطابق.
String? _providerPriceRangeLabel(MarketplaceProvider provider) {
  final summary = provider.serviceSummary;
  final summaryMin = _moneyValueOrNull(summary?.minPrice);
  final summaryMax = _moneyValueOrNull(summary?.maxPrice);
  if (summaryMin != null && summaryMax != null) {
    final unit = currencyLabelAr(summary?.currency);
    if (summaryMin == summaryMax) return '${_formatMoney(summaryMin)} $unit';
    return '${_formatMoney(summaryMin)} - ${_formatMoney(summaryMax)} $unit';
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
  if (min == max) return '${_formatMoney(min)} $unit';
  return '${_formatMoney(min)} - ${_formatMoney(max)} $unit';
}
