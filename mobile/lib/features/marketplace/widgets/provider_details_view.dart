import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../models/marketplace_models.dart';
import 'provider_board_view.dart' show providerServiceIcon;
import 'provider_photo_gallery.dart';
import 'provider_trust_signals.dart';

/// f03 «صفحة المزود»: the photos, who the provider is and how they answer,
/// their prices and how old they are, and their packages. Asking for a quote
/// and WhatsApp sit in the screen's footer.
class ProviderDetailsView extends StatelessWidget {
  const ProviderDetailsView({
    required this.provider,
    required this.services,
    required this.packages,
    required this.onBack,
    this.onOpenOffer,
    this.withinBudget = false,
    this.detailsErrorMessage,
    this.onRetryDetails,
    this.now,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final VoidCallback onBack;

  /// A package or priced service was tapped: ask for a quote on its service
  /// (null when the package names none). Null when no quote can be asked.
  final ValueChanged<String?>? onOpenOffer;

  /// The lowest price fits the plan's item for this kind of service.
  final bool withinBudget;

  /// The page, its services or its packages failed to refresh, so what is
  /// shown may be old or incomplete.
  final String? detailsErrorMessage;
  final VoidCallback? onRetryDetails;

  /// The clock for "last price update"; tests pin it.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final photos = _photoUrls(provider, services);
    final category = _categoryName(provider, services);
    final price = providerPriceRange(services);
    final priceUpdatedAt =
        latestPriceUpdate(services) ?? provider.serviceSummary?.pricesUpdatedAt;
    final priceAge = priceUpdatedAt == null
        ? null
        : priceAgeLine(priceUpdatedAt, now ?? DateTime.now());
    final offers = _offers(packages, services);
    final responds = providerRespondsLabel(provider.responsiveness);
    final place = _place(provider);

    return ListView(
      key: const ValueKey('provider-details-page'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _ProviderHero(
          photos: photos,
          icon: providerServiceIcon(category ?? ''),
          onBack: onBack,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detailsErrorMessage != null) ...[
                JourneyListNotice(offline: false, onRetry: onRetryDetails),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        provider.businessName,
                        style: JourneyType.of(
                          JourneyType.display,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                  ),
                  if (provider.isVerified) ...[
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'موثّق',
                      child: Icon(
                        LucideIcons.badgeCheck,
                        size: 22,
                        color: AarastV3Color.cobalt,
                        semanticLabel: 'موثّق',
                      ),
                    ),
                  ],
                ],
              ),
              if (provider.ratingCount > 0 || place != null) ...[
                const SizedBox(height: 2),
                _RatingLine(
                  average: provider.ratingAverage,
                  count: provider.ratingCount,
                  place: place,
                ),
              ],
              if (responds != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    JourneyTag(
                      key: const ValueKey('provider-details-responds'),
                      label: responds,
                      color: AarastV3Color.mint,
                      soft: AarastV3Color.mintSoft,
                    ),
                  ],
                ),
              ],
              if (price != null) ...[
                const SizedBox(height: 12),
                _PriceBox(
                  price: price,
                  withinBudget: withinBudget,
                  age: priceAge,
                ),
              ],
              if (offers.isNotEmpty) ...[
                const JourneySectionTitle('الباقات'),
                JourneyBox(
                  padding: EdgeInsets.zero,
                  child: JourneyList(
                    children: [
                      for (final offer in offers)
                        JourneyListRow(
                          key: ValueKey('provider-offer-${offer.key}'),
                          icon: providerServiceIcon(offer.category ?? ''),
                          color: AarastV3Color.cobalt,
                          soft: AarastV3Color.cobaltSoft,
                          title: offer.title,
                          subtitle: offer.detail,
                          trailing: offer.price == null
                              ? null
                              : Text(
                                  offer.price!,
                                  style: JourneyType.of(
                                    JourneyType.body,
                                    weight: JourneyType.bold,
                                  ),
                                ),
                          onTap: onOpenOffer == null
                              ? null
                              : () => onOpenOffer!(offer.serviceId),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The photo across the top, the way back, and how many photos there are.
class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.photos,
    required this.icon,
    required this.onBack,
  });

  final List<String> photos;
  final IconData icon;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      key: const Key('provider-media-fallback'),
      color: AarastV3Color.cobalt,
      child: Center(
        child: Icon(icon, size: 70, color: AarastV3Color.cobaltSoft),
      ),
    );
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            placeholder
          else
            AarastPressable(
              onTap: () => showProviderPhotoGallery(
                context,
                images: photos,
                initialIndex: 0,
              ),
              semanticLabel: 'افتح الصور',
              scale: 1,
              child: Image.network(
                photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
          PositionedDirectional(
            top: 12,
            start: 16,
            child: SafeArea(
              bottom: false,
              child: JourneyRoundButton(
                key: const ValueKey('provider-details-back'),
                icon: LucideIcons.arrowRight,
                tooltip: 'رجوع',
                size: 42,
                onPressed: onBack,
              ),
            ),
          ),
          if (photos.isNotEmpty)
            PositionedDirectional(
              bottom: 14,
              end: 16,
              child: IgnorePointer(
                child: JourneyTag(
                  label: '1 / ${photos.length} صورة',
                  color: AarastV3Color.onPrimary,
                  soft: AarastV3Color.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «★ 4.8 (63) · صنعاء، حدة».
class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.average,
    required this.count,
    required this.place,
  });

  final double average;
  final int count;
  final String? place;

  @override
  Widget build(BuildContext context) {
    final muted = JourneyType.of(
      JourneyType.body,
      color: AarastV3Color.textMuted,
    );
    return Text.rich(
      TextSpan(
        children: [
          if (count > 0) ...[
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                LucideIcons.star,
                size: 16,
                color: AarastV3Color.brandAccentStrong,
              ),
            ),
            TextSpan(
              text: ' ${average.toStringAsFixed(1)}',
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
            TextSpan(text: ' ($count)', style: muted),
            if (place != null) TextSpan(text: ' · ', style: muted),
          ],
          if (place != null) TextSpan(text: place, style: muted),
        ],
      ),
    );
  }
}

/// The price range, whether it fits the item, and how old it is.
class _PriceBox extends StatelessWidget {
  const _PriceBox({
    required this.price,
    required this.withinBudget,
    required this.age,
  });

  final String price;
  final bool withinBudget;
  final String? age;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('provider-details-price'),
      color: AarastV3Color.cobaltSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أسعاره',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    Text(
                      price,
                      style: JourneyType.of(
                        JourneyType.figure,
                        weight: JourneyType.bold,
                        color: AarastV3Color.cobalt,
                      ),
                    ),
                  ],
                ),
              ),
              if (withinBudget) ...[
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.checkCircle2,
                  size: 16,
                  color: AarastV3Color.mint,
                ),
                const SizedBox(width: 4),
                Text(
                  'ضمن بندك',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: AarastV3Color.mint,
                  ),
                ),
              ],
            ],
          ),
          if (age != null) ...[
            const SizedBox(height: 4),
            Text(
              age!,
              style: JourneyType.of(
                JourneyType.caption,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row under «الباقات»: a package, or a priced service when the provider
/// published no packages.
typedef _Offer = ({
  String key,
  String title,
  String detail,
  String? price,
  String? serviceId,
  String? category,
});

List<_Offer> _offers(
  List<ProviderPackage> packages,
  List<MarketplaceService> services,
) {
  final byId = {for (final service in services) service.id: service};
  final active = packages.where((item) => item.isActive).toList();
  if (active.isNotEmpty) {
    return [
      for (final item in active)
        (
          key: item.id,
          title: item.title,
          detail:
              _lines(item.items ?? item.description) ?? item.serviceTitle ?? '',
          price: providerMoneyLabel(item.price, item.currency),
          serviceId: item.serviceId,
          category: byId[item.serviceId]?.category?.nameAr,
        ),
    ];
  }
  return [
    for (final service in services)
      if (providerMoneyLabel(service.basePrice, service.currency) case final price?)
        (
          key: service.id,
          title: service.title,
          detail: _lines(service.description) ?? '',
          price: price,
          serviceId: service.id,
          category: service.category?.nameAr,
        ),
  ];
}

/// «مصور واحد · 300 صورة» from a package's lines.
String? _lines(String? text) {
  final lines = (text ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.isEmpty ? null : lines.join(' · ');
}

String? providerMoneyLabel(String? amount, String? currency) {
  final value = num.tryParse(amount?.replaceAll(',', '').trim() ?? '');
  if (value == null) return null;
  return '${_grouped(value)} ${currencyLabelAr(currency)}';
}

/// The range of the services priced in the first priced service's currency;
/// prices in another currency never join it.
String? providerPriceRange(List<MarketplaceService> services) {
  num? min;
  num? max;
  String? unitCode;
  for (final service in services) {
    final price = num.tryParse(
      service.basePrice?.replaceAll(',', '').trim() ?? '',
    );
    if (price == null) continue;
    final code = currencyCodeFromDisplayInput(service.currency);
    unitCode ??= code;
    if (code != unitCode) continue;
    min = min == null || price < min ? price : min;
    max = max == null || price > max ? price : max;
  }
  if (min == null || max == null) return null;
  final unit = currencyLabelAr(unitCode);
  if (min == max) return '${_grouped(min)} $unit';
  return '${_grouped(min)} - ${_grouped(max)} $unit';
}

String _grouped(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

/// «صنعاء، حدة».
String? _place(MarketplaceProvider provider) {
  final parts = [
    provider.city?.nameAr.trim(),
    provider.address?.trim(),
  ].whereType<String>().where((part) => part.isNotEmpty);
  return parts.isEmpty ? null : parts.join('، ');
}

String? _categoryName(
  MarketplaceProvider provider,
  List<MarketplaceService> services,
) {
  final primary = provider.primaryCategory?.nameAr.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  for (final service in services) {
    final name = service.category?.nameAr.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}

/// The cover first, then the services' photos, once each.
List<String> _photoUrls(
  MarketplaceProvider provider,
  List<MarketplaceService> services,
) {
  final cover = provider.coverUrl?.trim();
  return <String>{
    if (cover != null && cover.isNotEmpty) cover,
    for (final service in services)
      for (final image in service.images)
        if (image.imageUrl.trim().isNotEmpty) image.imageUrl.trim(),
  }.toList();
}
