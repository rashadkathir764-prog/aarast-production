import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/media/aarast_network_image.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart'
    show fullMoneyFromText, fullMoneyParts;
import '../../../core/widgets/aarast_pressable.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../models/marketplace_models.dart';
import '../models/provider_portfolio.dart';
import 'provider_board_view.dart' show providerServiceIcon;
import 'provider_photo_gallery.dart';
import 'provider_result_card.dart' show providerDayLabel;
import 'provider_trust_signals.dart';
import 'rating_star.dart';
import '../../../core/utils/keep_currency_on_line.dart';

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
    this.onReportReview,
    this.readerUserId,
    this.eventDate,
    this.dayFree,
    super.key,
  });

  /// The plan's wedding day and whether he is free on it: said «فاضي يوم 21»
  /// or «مشغول يوم 21» as the list's card says it ([providerDayLabel]).
  final DateTime? eventDate;
  final bool? dayFree;
  String? get dayLabel => providerDayLabel(eventDate, dayFree);

  /// RA-ST-05 (D94): «بلّغ عن التقييم» on a review; null where it cannot be
  /// sent. Never offered on the reader's own review ([readerUserId]).
  final ValueChanged<ProviderReview>? onReportReview;
  final String? readerUserId;

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
      padding: const EdgeInsets.only(bottom: AarastV3Space.x6),
      children: [
        _ProviderHero(
          photos: photos,
          icon: providerServiceIcon(category ?? ''),
          onBack: onBack,
          dataSaver: dataSaver,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x5,
            AarastV3Space.x4,
            AarastV3Space.x5,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detailsErrorMessage != null) ...[
                JourneyListNotice(offline: false, onRetry: onRetryDetails),
                const SizedBox(height: AarastV3Space.x3),
              ],
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        provider.businessName,
                        style: JourneyType.of(
                          JourneyType.pageTitle,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                  ),
                  if (provider.isVerified) ...[
                    const SizedBox(width: AarastV3Space.x2),
                    Tooltip(
                      message: 'موثّق',
                      child: Icon(
                        LucideIcons.badgeCheck,
                        size: AarastV3Icon.lg,
                        color: context.accent.primary,
                        semanticLabel: 'موثّق',
                      ),
                    ),
                  ],
                ],
              ),
              if (provider.ratingCount > 0 || place != null) ...[
                const SizedBox(height: AarastV3Space.half),
                _RatingLine(
                  average: provider.ratingAverage,
                  count: provider.ratingCount,
                  place: place,
                ),
              ],
              if (responds != null ||
                  (dayLabel != null && dayFree != null)) ...[
                const SizedBox(height: AarastV3Space.x2),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Her wedding day against his calendar, as on the card
                    // she came from.
                    if (dayLabel case final day? when dayFree != null)
                      JourneyTag(
                        key: const ValueKey('provider-details-day'),
                        label: day,
                        color: dayFree!
                            ? AarastV3Color.mint
                            : AarastV3Color.textMuted,
                        soft: dayFree!
                            ? AarastV3Color.mintSoft
                            : AarastV3Color.line,
                      ),
                    if (responds != null)
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
                const SizedBox(height: AarastV3Space.x3),
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
                      onReport:
                          onReportReview == null ||
                              (readerUserId != null &&
                                  review.userId == readerUserId)
                          ? null
                          : () => onReportReview!(review),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
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
  const _ReviewWithReply({
    required this.review,
    required this.providerName,
    this.onReport,
  });

  final ProviderReview review;
  final String providerName;

  /// RA-ST-05: «بلّغ عن التقييم»; null on the reader's own review.
  final VoidCallback? onReport;

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
              Expanded(
                child: Row(
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
                    const SizedBox(width: AarastV3Space.x2),
                    Semantics(
                      label: '$rating من 5',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Given and empty differ in shape, not by
                            // colour alone.
                            for (var star = 1; star <= 5; star++)
                              RatingStar(
                                filled: star <= rating,
                                size: AarastV3Icon.sm,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // At the row's end; a 48 target (D74) makes the row taller.
              if (onReport != null)
                IconButton(
                  key: ValueKey('provider-details-review-report-${review.id}'),
                  tooltip: 'بلّغ عن التقييم',
                  onPressed: onReport,
                  icon: const Icon(
                    LucideIcons.flag,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              '«$comment»',
              style: JourneyType.of(
                JourneyType.body,
                height: AarastV3Line.reading,
              ),
            ),
          ],
          if (reply != null && reply.body.trim().isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x2),
            Container(
              key: ValueKey('provider-details-review-reply-${review.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(AarastV3Space.x3),
              decoration: BoxDecoration(
                color: AarastV3Color.canvas,
                borderRadius: BorderRadius.circular(AarastV3Radius.surface),
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
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    reply.body.trim(),
                    style: JourneyType.of(
                      JourneyType.body,
                      height: AarastV3Line.reading,
                    ),
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
        child: Icon(
          icon,
          size: AarastV3Icon.hero,
          color: context.accent.primarySoft,
        ),
      ),
    );
    // D118: a photo's proportion of the width, not 220 on every phone.
    return AspectRatio(
      aspectRatio: AarastV3Media.photo,
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
                  : AarastNetworkImage(
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
                size: AarastV3Size.mark,
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
                size: AarastV3Icon.sm,
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
                        JourneyType.pageTitle,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (withinBudget) ...[
                const SizedBox(width: AarastV3Space.x2),
                const Icon(
                  LucideIcons.checkCircle2,
                  size: AarastV3Icon.sm,
                  color: AarastV3Color.mint,
                ),
                const SizedBox(width: AarastV3Space.x1),
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
            const SizedBox(height: AarastV3Space.x1),
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
      if (providerMoneyLabel(service.basePrice, service.currency)
          case final price?)
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

/// A service's price in full; null when it has none (critique ب2: the
/// money formatter's one reading).
String? providerMoneyLabel(String? amount, String? currency) =>
    fullMoneyFromText(amount, currency);

/// The range of the services priced in the first priced service's currency;
/// prices in another currency never join it.
/// The span of a provider's published prices, in one currency: the first
/// priced service's. A price in another currency is not put beside it, so
/// «من 1,500 ر.ي» never comes from a price in dollars. The one reading of a
/// provider's prices (the page, the list row, the shelf card).
({num min, num max, String currency})? providerPriceSpan(
  List<MarketplaceService> services,
) {
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
  if (min == null || max == null || unitCode == null) return null;
  return (min: min, max: max, currency: unitCode);
}

/// «450,000 - 900,000 ر.ي», or the one price; written whole, as an offer's
/// price is (critique ب2).
String providerPriceText(num min, num max, String? currency) {
  final code = currencyCodeFromDisplayInput(currency);
  final unit = currencyLabelAr(code);
  final low = fullMoneyParts(min, currencyCode: code).number;
  if (min == max) return keepCurrencyOnLine('$low $unit');
  final high = fullMoneyParts(max, currencyCode: code).number;
  return keepCurrencyOnLine('$low - $high $unit');
}

String? providerPriceRange(List<MarketplaceService> services) {
  final span = providerPriceSpan(services);
  return span == null
      ? null
      : providerPriceText(span.min, span.max, span.currency);
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

/// The cover first (D88: the logo when he has no cover, the same face the
/// list shows), then his approved portfolio photos (B-16), once each.
/// Only reviewed photos reach customers (D62): the services' own photos,
/// never reviewed, are not shown.
List<String> _photoUrls(
  MarketplaceProvider provider,
  PublicPortfolio? portfolio,
) {
  // RA-MO-364: the 1080px copies the server made; the images themselves
  // when saved before them.
  final face = provider.wideCoverUrl ?? provider.wideLogoUrl;
  return <String>{
    ?face,
    for (final photo in portfolio?.items ?? const <PublicPortfolioPhoto>[])
      if (photo.imageUrl.trim().isNotEmpty) photo.imageUrl.trim(),
  }.toList();
}
