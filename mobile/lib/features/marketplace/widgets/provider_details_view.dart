import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../models/marketplace_models.dart';
import '../models/provider_portfolio.dart';
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
    this.dataSaver = false,
    this.reviews = const [],
    this.portfolio,
    super.key,
  });

  /// g02 «توفير البيانات»: the photos load only once opened.
  final bool dataSaver;

  /// B-16: his approved «معرض الشغل» photos this reader may see (the women's
  /// album a bride only) and his TikTok, Instagram and Facebook links.
  final PublicPortfolio? portfolio;

  /// The published reviews, newest first, each with the provider's reply
  /// once published (B-09). f03 draws no reviews list; it is the place a
  /// groom reads what others said and what the provider answered.
  final List<ProviderReview> reviews;

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
    final photos = _photoUrls(provider, portfolio);
    final links = portfolio?.socialLinks ?? const <String, String>{};
    final category = _categoryName(provider, services);
    final price = providerPriceRange(services);
    final priceUpdatedAt =
        latestPriceUpdate(services) ?? provider.serviceSummary?.pricesUpdatedAt;
    final priceAge = priceUpdatedAt == null
        ? null
        : priceAgeLine(
            priceUpdatedAt,
            now ?? appNow(),
            profile: context.journeyProfile,
          );
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
          dataSaver: dataSaver,
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
                    Tooltip(
                      message: 'موثّق',
                      child: Icon(
                        LucideIcons.badgeCheck,
                        size: 22,
                        color: context.accent.primary,
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
                          color: context.accent.primary,
                          soft: context.accent.primarySoft,
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
              if (links.isNotEmpty) ...[
                // Not drawn on f03 (recorded, D62): the links, words neutral (D55).
                const JourneySectionTitle('روابط الشغل'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final network in portfolioSocialNetworks)
                      if (links[network] != null)
                        JourneyChip(
                          key: ValueKey('provider-social-$network'),
                          label: portfolioSocialLabel(network),
                          onTap: () => _openLink(context, links[network]!),
                        ),
                  ],
                ),
              ],
              if (reviews.any((review) => review.isPublished)) ...[
                const JourneySectionTitle('التقييمات'),
                for (final review in reviews)
                  if (review.isPublished) ...[
                    _ReviewWithReply(
                      review: review,
                      providerName: provider.businessName,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The photo across the top, the way back, and how many photos there are.
/// A review as customers read it: the name, the stars, the words, and the
/// provider's published reply under them («رد استوديو ضوء صنعاء»).
class _ReviewWithReply extends StatelessWidget {
  const _ReviewWithReply({required this.review, required this.providerName});

  final ProviderReview review;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final name = review.userName?.trim().isNotEmpty == true
        ? review.userName!.trim()
        : 'من اعّرست';
    final comment = review.comment?.trim() ?? '';
    final rating = review.rating.clamp(0, 5);
    final reply = review.reply;
    return JourneyBox(
      key: ValueKey('provider-details-review-${review.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: '$rating من 5',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          LucideIcons.star,
                          size: 15,
                          color: star <= rating
                              ? AarastV3Color.saffron
                              : AarastV3Color.line,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '«$comment»',
              style: JourneyType.of(JourneyType.body, height: 1.6),
            ),
          ],
          if (reply != null && reply.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey('provider-details-review-reply-${review.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AarastV3Color.canvas,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رد $providerName',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.body.trim(),
                    style: JourneyType.of(JourneyType.body, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.photos,
    required this.icon,
    required this.onBack,
    required this.dataSaver,
  });

  final bool dataSaver;

  final List<String> photos;
  final IconData icon;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      key: const Key('provider-media-fallback'),
      color: context.accent.primary,
      child: Center(
        child: Icon(icon, size: 70, color: context.accent.primarySoft),
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
              semanticLabel: context.say('افتح الصور', 'افتحي الصور'),
              scale: 1,
              child: dataSaver
                  ? placeholder
                  : Image.network(
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
      color: context.accent.primarySoft,
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
                        color: context.accent.primary,
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

/// His TikTok, Instagram or Facebook page, outside the app (the server keeps
/// only https profile links on those hosts, D62).
Future<void> _openLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  final opened =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    AarastToast.showError(context, 'ما قدرنا نفتح الرابط.');
  }
}

/// The cover first, then his approved portfolio photos (B-16), once each.
/// Only reviewed photos reach customers (D62): the services' own photos,
/// never reviewed, are not shown.
List<String> _photoUrls(MarketplaceProvider provider, PublicPortfolio? portfolio) {
  final cover = provider.coverUrl?.trim();
  return <String>{
    if (cover != null && cover.isNotEmpty) cover,
    for (final photo in portfolio?.items ?? const <PublicPortfolioPhoto>[])
      if (photo.imageUrl.trim().isNotEmpty) photo.imageUrl.trim(),
  }.toList();
}
