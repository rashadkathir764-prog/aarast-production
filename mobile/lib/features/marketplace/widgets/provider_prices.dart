import '../../../core/l10n/aarast_text.dart';
import '../../../core/utils/compact_money_figure.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/keep_currency_on_line.dart';
import '../../../core/utils/money_formatters.dart'
    show fullMoneyFromText, fullMoneyParts;
import '../models/marketplace_models.dart';

/// The one reading of a provider's prices, for his card, his page and the
/// comparison (2026-11-26 review): where his published prices start, «من
/// X», from his services and his packages together, in one currency.

/// A price the server sends as text, in full («550,000 ر.ي»); null when it
/// is not a number (critique ب2: the money formatter's one reading).
String? providerMoneyLabel(String? amount, String? currency) =>
    fullMoneyFromText(amount, currency);

/// The span of published prices, in one currency: the first priced one's.
/// A price in another currency is not put beside it, so «من 1,500 ر.ي» never
/// comes from a price in dollars.
typedef ProviderPriceSpan = ({num min, num max, String currency});

ProviderPriceSpan? providerPriceSpan(
  List<MarketplaceService> services, {
  List<ProviderPackage> packages = const [],
}) {
  num? min;
  num? max;
  String? unitCode;
  void take(String? amount, String? currency) {
    final price = _amountOrNull(amount);
    if (price == null) return;
    final code = currencyCodeFromDisplayInput(currency);
    unitCode ??= code;
    if (code != unitCode) return;
    min = min == null || price < min! ? price : min;
    max = max == null || price > max! ? price : max;
  }

  for (final service in services) {
    if (service.isActive) take(service.basePrice, service.currency);
  }
  for (final item in packages) {
    if (item.isActive) take(item.price, item.currency);
  }
  if (min == null || max == null || unitCode == null) return null;
  return (min: min!, max: max!, currency: unitCode!);
}

/// His page's «من X»: the prices of his own kind (a venue's hall, not the
/// per-person meal it also sells), as the list scopes a row to the asked
/// category: his services of his main category, and the packages under
/// them or under no service (the server files those under his main kind).
/// Every price when his own kind has none.
ProviderPriceSpan? providerOwnKindSpan(
  MarketplaceProvider provider,
  List<MarketplaceService> services,
  List<ProviderPackage> packages,
) {
  final kind =
      provider.primaryCategory?.id ??
      provider.primaryCategoryId ??
      services.map((service) => service.category?.id).nonNulls.firstOrNull;
  if (kind == null) return providerPriceSpan(services, packages: packages);
  final own = [
    for (final service in services)
      if ((service.category?.id ?? service.categoryId ?? kind) == kind) service,
  ];
  final ownIds = {for (final service in own) service.id};
  final ownPackages = [
    for (final item in packages)
      if (item.serviceId == null || ownIds.contains(item.serviceId)) item,
  ];
  return providerPriceSpan(own, packages: ownPackages) ??
      providerPriceSpan(services, packages: packages);
}

/// A provider's published prices: the list's own summary when it has one
/// (scoped by the server to the asked category, packages included), else
/// what his page read ([services] and [packages]).
ProviderPriceSpan? providerPublishedSpan(
  MarketplaceProvider provider, {
  List<MarketplaceService>? services,
  List<ProviderPackage> packages = const [],
}) {
  final summary = provider.serviceSummary;
  final summaryMin = _amountOrNull(summary?.minPrice);
  if (summaryMin != null) {
    final summaryMax = _amountOrNull(summary?.maxPrice) ?? summaryMin;
    return (
      min: summaryMin,
      max: summaryMax < summaryMin ? summaryMin : summaryMax,
      currency: currencyCodeFromDisplayInput(summary?.currency),
    );
  }
  return providerPriceSpan(services ?? provider.services, packages: packages);
}

/// «450,000 - 900,000 ر.ي», or the one price; written whole.
String providerPriceText(num min, num max, String? currency) {
  final code = currencyCodeFromDisplayInput(currency);
  final unit = currencyLabelAr(code);
  final low = fullMoneyParts(min, currencyCode: code).number;
  if (min == max) return keepCurrencyOnLine('$low $unit');
  final high = fullMoneyParts(max, currencyCode: code).number;
  return keepCurrencyOnLine('$low - $high $unit');
}

/// His whole span, for the comparison: his services and his packages, as
/// every card reads them. The column read the services alone, so a provider
/// priced in his packages said «السعر عند الطلب» over their prices.
String? providerPriceRange(
  List<MarketplaceService> services, {
  List<ProviderPackage> packages = const [],
}) {
  final span = providerPriceSpan(services, packages: packages);
  return span == null
      ? null
      : providerPriceText(span.min, span.max, span.currency);
}

/// His page's price line: «من 250,000 ر.ي», the amount whole; null when he
/// published none.
String? providerFromPriceFull(ProviderPriceSpan? span) => span == null
    ? null
    : aarastText.providersPriceFrom(
        providerPriceText(span.min, span.min, span.currency),
      );

/// A card's price line (LANGUAGE.md §4.7: short in a summary when nothing
/// is lost): «من 250 ألفًا», «من 2 مليون», «من 12.5 مليون», else whole
/// («من 1,850,000 ر.ي»). The short figure names no currency, so it is the
/// app's own alone: another one is written whole with its sign («من 15,000
/// ر.س», not «من 15 ألفًا» among riyal rows). Null when he published none.
String? providerFromPriceShort(ProviderPriceSpan? span) {
  if (span == null) return null;
  final value = span.min;
  final whole = providerPriceText(value, value, span.currency);
  final short =
      currencyCodeFromDisplayInput(span.currency) == defaultCurrencyCode &&
          value.abs() >= 10000 &&
          shortensWithoutLoss(value)
      ? compactMoneyFigure(value, currencyCode: span.currency)
      : whole;
  return aarastText.providersPriceFrom(short);
}

num? _amountOrNull(String? value) =>
    num.tryParse(value?.replaceAll(',', '').trim() ?? '');
