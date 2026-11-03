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

/// أفضل صورة تمثّل المزود في القائمة: الغلاف ثم الشعار. صور الخدمات ما
/// تنعرض للعرسان لأنها ما تتراجع (D62).
String? _providerImageUrl(MarketplaceProvider provider) {
  final cover = provider.coverUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  final logo = provider.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
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
