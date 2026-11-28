import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/media/aarast_network_image.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../models/provider_portfolio.dart';
import 'provider_photo_gallery.dart';
import 'provider_prices.dart';
import 'provider_result_card.dart';
import 'provider_trust_signals.dart';
import 'rating_star.dart';

export 'provider_prices.dart';

/// The reviews shown before «كل التقييمات (N)»: the newest three.
const _reviewsPreview = 3;

/// The summary with its stars' spread shows from this many reviews up; under
/// it the spread of a handful says nothing the reviews do not.
const _summaryFromReviews = 6;

/// How far the logo hangs below the photos: half of it.
const _badgeOverhang = AarastV3Size.markLarge / 2;

/// f03, a provider's page (REFINEMENT_SPEC 2.7). Bold in one place, his
/// work photos; then who he is, one price line and what is known of the
/// wedding day; then his sections in the order his kind is chosen by (a
/// venue or a caterer is chosen by its packages and its place, an artist by
/// who he is). Asking for a quote, calling and WhatsApp sit in the screen's
/// footer. Presentation only: the screen reads and acts.
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
    this.reviewSummary,
    this.hasMoreReviews = false,
    this.loadingMoreReviews = false,
    this.onLoadMoreReviews,
    this.portfolio,
    this.onReportReview,
    this.readerUserId,
    this.eventDate,
    this.bookedByReader = false,
    this.isFavorite = false,
    this.onFavorite,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final VoidCallback onBack;

  /// A package or a service was tapped: ask for a quote on its service.
  /// Null when no quote can be asked (an unclaimed listing).
  final ValueChanged<String?>? onOpenOffer;

  /// His lowest riyal price fits the plan's item for his kind.
  final bool withinBudget;

  /// The page or one of its sections could not be refreshed.
  final String? detailsErrorMessage;
  final VoidCallback? onRetryDetails;

  /// The clock; tests pin it.
  final DateTime? now;

  /// «توفير البيانات»: the photos load only once opened.
  final bool dataSaver;

  /// His published reviews read so far, newest first, and the summary of
  /// them all.
  final List<ProviderReview> reviews;
  final ProviderReviewSummary? reviewSummary;
  final bool hasMoreReviews;
  final bool loadingMoreReviews;
  final VoidCallback? onLoadMoreReviews;

  /// His approved photos this reader may see (the women's album a bride
  /// only, B-16) and his links.
  final PublicPortfolio? portfolio;

  /// «الإبلاغ عن التقييم»; never on the reader's own review.
  final ValueChanged<ProviderReview>? onReportReview;
  final String? readerUserId;

  /// The plan's wedding day; the page's `dayStatus` answers it.
  final DateTime? eventDate;

  /// The reader's own confirmed booking holds him on [eventDate]: the day
  /// line says «محجوز لك», not that the day is taken.
  final bool bookedByReader;

  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? appNow();
    final gallery = providerGalleryPhotos(provider, portfolio);
    final womenAlbum = providerWomenAlbum(portfolio);
    // His main kind, else the one his services carry.
    final kind =
        [
              provider.primaryCategory,
              for (final service in services) service.category,
            ]
            .map((category) => providerKindName(context, category))
            .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final city = provider.city?.nameAr.trim() ?? '';
    final activePackages = [
      for (final item in packages)
        if (item.isActive) item,
    ];
    // An unclaimed listing takes no request, so «السعر عند الطلب» would
    // promise one; without a price it says none.
    final price = providerFromPriceFull(
      providerOwnKindSpan(provider, services, activePackages),
    );
    final showPrice = price != null || provider.isClaimed;
    final responds = providerRespondsLabel(provider.responsiveness);
    final published = [
      for (final review in reviews)
        if (review.isPublished) review,
    ];
    final links = portfolio?.socialLinks ?? const <String, String>{};
    final address = provider.address?.trim() ?? '';
    final hasMap = provider.latitude != null && provider.longitude != null;

    final sections = <ProviderPageSection, List<Widget>>{
      if (activePackages.isNotEmpty)
        ProviderPageSection.packages: [
          _OfferCard(
            offers: [
              for (final item in activePackages)
                (
                  key: item.id,
                  title: item.title,
                  detail: _lines(item.items ?? item.description),
                  price: providerMoneyLabel(item.price, item.currency),
                  unit: null,
                  serviceId: item.serviceId,
                ),
            ],
            onOpenOffer: onOpenOffer,
          ),
        ],
      if (address.isNotEmpty || hasMap)
        ProviderPageSection.location: [
          _LocationCard(
            // A provider often writes the city in his address («حدة،
            // صنعاء»): the city is not said twice («صنعاء، حدة، صنعاء»).
            address: [
              if (city.isNotEmpty && !address.contains(city)) city,
              if (address.isNotEmpty) address,
            ].join(aarastText.providersListSeparator),
            latitude: provider.latitude,
            longitude: provider.longitude,
          ),
        ],
      if (services.isNotEmpty)
        ProviderPageSection.services: [
          _OfferCard(
            offers: [
              for (final service in services)
                (
                  key: service.id,
                  title: service.title,
                  detail: _lines(service.description),
                  price: providerMoneyLabel(
                    service.basePrice,
                    service.currency,
                  ),
                  unit: _clean(service.priceUnit),
                  serviceId: service.id,
                ),
            ],
            onOpenOffer: onOpenOffer,
          ),
        ],
      if (_clean(provider.description) case final about?)
        ProviderPageSection.about: [
          JourneyBox(
            key: const ValueKey('provider-details-about'),
            padding: AarastV3Density.cardInsets,
            child: Text(
              about,
              style: JourneyType.of(
                JourneyType.body,
                height: AarastV3Line.reading,
              ),
            ),
          ),
        ],
      if (links.isNotEmpty)
        ProviderPageSection.links: [
          Wrap(
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x2,
            children: [
              for (final network in portfolioSocialNetworks)
                if (links[network] case final link?)
                  JourneyChip(
                    key: ValueKey('provider-social-$network'),
                    label: portfolioSocialLabel(network),
                    icon: LucideIcons.externalLink,
                    onTap: () => openOutsideApp(
                      context,
                      Uri.tryParse(link),
                      aarastText.providersLinkFailed,
                    ),
                  ),
            ],
          ),
        ],
      if (published.isNotEmpty)
        ProviderPageSection.reviews: [
          _Reviews(
            reviews: published,
            summary: reviewSummary,
            providerName: provider.businessName,
            hasMore: hasMoreReviews,
            loadingMore: loadingMoreReviews,
            onLoadMore: onLoadMoreReviews,
            onReport: (review) =>
                onReportReview == null ||
                    (readerUserId != null && review.userId == readerUserId)
                ? null
                : () => onReportReview!(review),
          ),
        ],
    };

    // His logo hangs over the photos' bottom edge (the first proposal): his
    // face where the eye leaves the photos for the words. Without photos it
    // sits beside his name instead, and without a logo nothing stands in.
    final badge = gallery.isNotEmpty && _clean(provider.wideLogoUrl) != null;
    return ListView(
      key: const ValueKey('provider-details-page'),
      padding: const EdgeInsets.only(bottom: AarastV3Space.x8),
      children: [
        if (gallery.isEmpty)
          _SlimHead(
            onBack: onBack,
            isFavorite: isFavorite,
            onFavorite: onFavorite,
          )
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Gallery(
                photos: gallery,
                dataSaver: dataSaver,
                onBack: onBack,
                isFavorite: isFavorite,
                onFavorite: onFavorite,
              ),
              if (badge)
                PositionedDirectional(
                  start: AarastV3Space.x4,
                  bottom: -_badgeOverhang,
                  child: ProviderLogoBadge(
                    name: provider.businessName,
                    logoUrl: provider.wideLogoUrl,
                  ),
                ),
            ],
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            gallery.isEmpty
                ? 0
                : badge
                ? _badgeOverhang + AarastV3Space.x2
                : AarastV3Space.x4,
            AarastV3Space.x4,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detailsErrorMessage != null) ...[
                _StaleLine(onRetry: onRetryDetails),
                const SizedBox(height: AarastV3Space.x3),
              ],
              _Identity(
                provider: provider,
                now: clock,
                showLogo: gallery.isEmpty,
                kindAndCity: [
                  if (kind.isNotEmpty) kind,
                  if (city.isNotEmpty) city,
                ],
                responds: responds,
              ),
              if (womenAlbum.isNotEmpty) ...[
                const SizedBox(height: AarastV3Space.x2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('provider-details-women-album'),
                    label: aarastText.providersWomenAlbum(womenAlbum.length),
                    icon: LucideIcons.image,
                    color: context.accent.primary,
                    onPressed: () => showProviderPhotoGallery(
                      context,
                      images: womenAlbum,
                      initialIndex: 0,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AarastV3Space.x3),
              const Divider(
                height: AarastV3Size.line,
                thickness: AarastV3Size.line,
                color: AarastV3Color.line,
              ),
              const SizedBox(height: AarastV3Space.x3),
              if (showPrice)
                _PriceLine(price: price, withinBudget: withinBudget),
              if (_dayLine(context, clock) case final day?) ...[
                if (showPrice) const SizedBox(height: AarastV3Space.x2),
                day,
              ],
              for (final section in providerPageSectionOrder(
                provider.primaryCategory?.slug,
              ))
                if (sections[section] case final children?) ...[
                  JourneySectionTitle(_sectionTitle(section)),
                  ...children,
                ],
            ],
          ),
        ),
      ],
    );
  }

  /// The wedding day against his calendar, from the page's own `dayStatus`:
  /// closed or full, said in the danger's colour; unknown, said as unknown
  /// with what to do. Nothing without a day or for a day already past.
  Widget? _dayLine(BuildContext context, DateTime clock) {
    final day = eventDate;
    if (day == null || planDayIsPast(day, clock)) return null;
    // The reader's own booking holds him that day: theirs, in the good
    // colour, whatever the day's count says.
    final known = bookedByReader
        ? aarastText.providersDayYours
        : providerDayLine(day, provider.dayStatus, now: clock);
    final text =
        known ??
        (provider.isClaimed
            ? aarastText.providersDayUnknown(context.gender)
            : aarastText.providersDayUnknownCall(context.gender));
    final color = known == null
        ? AarastV3Color.textMuted
        : bookedByReader
        ? AarastV3Color.mint
        : AarastV3Color.danger;
    return Row(
      key: const ValueKey('provider-details-day'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          known == null
              ? LucideIcons.calendarSearch
              : bookedByReader
              ? LucideIcons.calendarCheck
              : LucideIcons.calendarX,
          size: AarastV3Icon.md,
          color: color,
        ),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Text(
            text,
            style: JourneyType.of(
              JourneyType.body,
              weight: known == null ? FontWeight.w400 : JourneyType.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// The sections of a provider's page.
enum ProviderPageSection { packages, location, services, about, links, reviews }

/// The order his sections come in, by what his kind is chosen by
/// (REFINEMENT_SPEC 2.7): a venue and a caterer by their packages and
/// their place; a photographer, an artist, a beauty provider (and every
/// other kind) by who he is, then what he offers.
List<ProviderPageSection> providerPageSectionOrder(String? categorySlug) =>
    switch (categorySlug) {
      venueCategorySlug || cateringCategorySlug => const [
        ProviderPageSection.packages,
        ProviderPageSection.location,
        ProviderPageSection.services,
        ProviderPageSection.about,
        ProviderPageSection.links,
        ProviderPageSection.reviews,
      ],
      _ => const [
        ProviderPageSection.about,
        ProviderPageSection.packages,
        ProviderPageSection.services,
        ProviderPageSection.links,
        ProviderPageSection.location,
        ProviderPageSection.reviews,
      ],
    };

String _sectionTitle(ProviderPageSection section) => switch (section) {
  ProviderPageSection.packages => aarastText.providersSectionPackages,
  ProviderPageSection.location => aarastText.providersSectionLocation,
  ProviderPageSection.services => aarastText.providersSectionServices,
  ProviderPageSection.about => aarastText.providersSectionAbout,
  ProviderPageSection.links => aarastText.providersSectionLinks,
  ProviderPageSection.reviews => aarastText.providersSectionReviews,
};

/// His approved work photos outside the women's album, then his cover, once
/// each: the page's gallery. The logo is no photo.
List<String> providerGalleryPhotos(
  MarketplaceProvider provider,
  PublicPortfolio? portfolio,
) => <String>{
  for (final photo in portfolio?.items ?? const <PublicPortfolioPhoto>[])
    if (!photo.forWomen && photo.imageUrl.trim().isNotEmpty)
      photo.imageUrl.trim(),
  ?_clean(provider.wideCoverUrl),
}.toList();

/// The women's album, apart: the server sends it to a bride alone (B-16).
List<String> providerWomenAlbum(PublicPortfolio? portfolio) => [
  for (final photo in portfolio?.items ?? const <PublicPortfolioPhoto>[])
    if (photo.forWomen && photo.imageUrl.trim().isNotEmpty)
      photo.imageUrl.trim(),
];

/// A page with no photo: no empty block, the way back and the heart on the
/// canvas in a slim band.
class _SlimHead extends StatelessWidget {
  const _SlimHead({
    required this.onBack,
    required this.isFavorite,
    required this.onFavorite,
  });

  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final onFavorite = this.onFavorite;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x2,
          vertical: AarastV3Space.x1,
        ),
        child: Row(
          children: [
            JourneyRoundButton(
              key: const ValueKey('provider-details-back'),
              icon: LucideIcons.arrowRight,
              tooltip: aarastText.providersBack,
              onPressed: onBack,
            ),
            const Spacer(),
            if (onFavorite != null)
              ProviderFavoriteHeart(
                buttonKey: const ValueKey('provider-details-favorite'),
                isFavorite: isFavorite,
                onTap: onFavorite,
                // A paper disc like the way back beside it.
                onPhoto: true,
              ),
          ],
        ),
      ),
    );
  }
}

/// His work photos at 16:9 across the page (the first proposal: 4:3 took
/// half the screen before a word about him): the way back and the heart
/// over them, and «كل الصور» with which photo of how many at the bottom
/// end, away from his logo at the bottom start.
class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.photos,
    required this.dataSaver,
    required this.onBack,
    required this.isFavorite,
    required this.onFavorite,
  });

  final List<String> photos;
  final bool dataSaver;
  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _Gallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.photos.length) _index = widget.photos.length - 1;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _open() => showProviderPhotoGallery(
    context,
    images: widget.photos,
    initialIndex: _index,
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final soft = context.accent.primarySoft;
    final onFavorite = widget.onFavorite;
    return AspectRatio(
      aspectRatio: AarastV3Media.photo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AarastPressable(
            onTap: _open,
            semanticLabel: aarastText.providersOpenPhotos(context.gender),
            scale: 1,
            child: widget.dataSaver
                ? ColoredBox(
                    key: const Key('provider-media-fallback'),
                    color: soft,
                    child: Icon(
                      LucideIcons.image,
                      size: AarastV3Icon.hero,
                      color: context.accent.primary,
                    ),
                  )
                : PageView.builder(
                    key: const ValueKey('provider-details-photos'),
                    controller: _pages,
                    itemCount: photos.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => AarastNetworkImage(
                      photos[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: soft),
                    ),
                  ),
          ),
          PositionedDirectional(
            top: 0,
            start: AarastV3Space.x2,
            child: SafeArea(
              bottom: false,
              child: JourneyRoundButton(
                key: const ValueKey('provider-details-back'),
                icon: LucideIcons.arrowRight,
                tooltip: aarastText.providersBack,
                onPressed: widget.onBack,
              ),
            ),
          ),
          if (onFavorite != null)
            PositionedDirectional(
              top: 0,
              end: AarastV3Space.x2,
              child: SafeArea(
                bottom: false,
                child: ProviderFavoriteHeart(
                  buttonKey: const ValueKey('provider-details-favorite'),
                  isFavorite: widget.isFavorite,
                  onTap: onFavorite,
                  onPhoto: true,
                ),
              ),
            ),
          if (photos.length > 1)
            PositionedDirectional(
              bottom: AarastV3Space.x2,
              end: AarastV3Space.x3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JourneyChip(
                    key: const ValueKey('provider-details-all-photos'),
                    label: aarastText.providersAllPhotos,
                    icon: LucideIcons.layoutGrid,
                    onTap: _open,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  IgnorePointer(
                    child: JourneyTag(
                      key: const ValueKey('provider-details-photo-count'),
                      label: aarastText.providersPhotoCounter(
                        _index + 1,
                        photos.length,
                      ),
                      color: AarastV3Color.onPrimary,
                      soft: AarastV3Color.ink,
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

/// Who he is: the name and ✓, his kind and city, his rating, and how he
/// answers requests.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.provider,
    required this.now,
    required this.showLogo,
    required this.kindAndCity,
    required this.responds,
  });

  final MarketplaceProvider provider;
  final DateTime now;
  final bool showLogo;
  final List<String> kindAndCity;
  final String? responds;

  @override
  Widget build(BuildContext context) {
    final responds = this.responds;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: provider.businessName),
              if (provider.isVerified && provider.isClaimed)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AarastV3Space.x1,
                    ),
                    child: Icon(
                      LucideIcons.badgeCheck,
                      size: AarastV3Icon.md,
                      color: context.accent.primary,
                      semanticLabel: aarastText.providersVerified,
                    ),
                  ),
                ),
            ],
          ),
          key: const ValueKey('provider-details-name'),
          style: JourneyType.of(
            JourneyType.pageTitle,
            weight: JourneyType.bold,
          ),
        ),
        if (kindAndCity.isNotEmpty)
          Text(
            // One dot at most in a line (REFINEMENT_SPEC 2.6).
            kindAndCity.length == 2
                ? aarastText.providersKindAndCity(
                    kindAndCity.first,
                    kindAndCity.last,
                  )
                : kindAndCity.single,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        const SizedBox(height: AarastV3Space.x1),
        ProviderRating(
          key: const ValueKey('provider-details-rating'),
          average: provider.ratingAverage,
          count: provider.ratingCount,
          kind: provider.ratingCount > 0
              ? ProviderRatingKind.stars
              : provider.isNewAt(now)
              ? ProviderRatingKind.isNew
              : ProviderRatingKind.none,
          size: JourneyType.body,
        ),
        if (responds != null) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(
            responds,
            key: const ValueKey('provider-details-responds'),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ],
    );
    if (!showLogo) return words;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProviderLogoBadge(
          name: provider.businessName,
          logoUrl: provider.wideLogoUrl,
        ),
        const SizedBox(width: AarastV3Space.x3),
        Expanded(child: words),
      ],
    );
  }
}

/// The one price line: «من 250,000 ر.ي», where his services' and packages'
/// prices start, with «ضمن بندك» when it fits the plan's item; «السعر عند
/// الطلب» when he published none.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.price, required this.withinBudget});

  final String? price;
  final bool withinBudget;

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    if (price == null) {
      return Text(
        aarastText.providersPriceOnRequest,
        key: const ValueKey('provider-details-price'),
        style: JourneyType.of(
          JourneyType.lead,
          weight: JourneyType.bold,
          color: AarastV3Color.textMuted,
        ),
      );
    }
    return Text(
      withinBudget ? aarastText.providersPriceWithinItem(price) : price,
      key: const ValueKey('provider-details-price'),
      style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
    );
  }
}

/// The page could not refresh whole: what is shown is the last copy.
class _StaleLine extends StatelessWidget {
  const _StaleLine({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('provider-details-stale'),
        children: [
          const Icon(
            LucideIcons.wifiOff,
            size: AarastV3Icon.md,
            color: AarastV3Color.textMuted,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              aarastText.providersDetailsStale,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          if (onRetry != null)
            JourneyTextAction(
              label: aarastText.providersRetry(context.gender),
              color: context.accent.primary,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// One row under «الباقات» or «الخدمات».
typedef _Offer = ({
  String key,
  String title,
  String? detail,
  String? price,
  String? unit,
  String? serviceId,
});

/// His packages or his services: one card, a row each, a hairline between.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offers, required this.onOpenOffer});

  final List<_Offer> offers;
  final ValueChanged<String?>? onOpenOffer;

  @override
  Widget build(BuildContext context) {
    final open = onOpenOffer;
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, offer) in offers.indexed) ...[
            if (index > 0)
              const Divider(
                height: AarastV3Size.line,
                thickness: AarastV3Size.line,
                indent: AarastV3Space.x4,
                endIndent: AarastV3Space.x4,
                color: AarastV3Color.line,
              ),
            AarastPressable(
              key: ValueKey('provider-offer-${offer.key}'),
              onTap: open == null ? null : () => open(offer.serviceId),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AarastV3Size.row),
                child: Padding(
                  padding: AarastV3Density.rowInsets,
                  child: JourneyEndRow(
                    share: JourneyEndRow.amountShare,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    start: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          maxLines: AarastV3Size.titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                        if (offer.detail case final detail?)
                          Text(
                            detail,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                      ],
                    ),
                    end: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          offer.price ?? aarastText.providersPriceOnRequest,
                          textAlign: TextAlign.end,
                          style: JourneyType.of(
                            offer.price == null
                                ? JourneyType.small
                                : JourneyType.body,
                            weight: JourneyType.bold,
                            color: offer.price == null
                                ? AarastV3Color.textMuted
                                : AarastV3Color.ink,
                          ),
                        ),
                        if (offer.price != null && offer.unit != null)
                          Text(
                            offer.unit!,
                            textAlign: TextAlign.end,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A venue's or a caterer's place: the address, and the phone's map from his
/// coordinates.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    return JourneyBox(
      key: const ValueKey('provider-details-location'),
      padding: AarastV3Density.cardInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.mapPin,
                size: AarastV3Icon.md,
                color: context.accent.primary,
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: Text(
                  address,
                  style: JourneyType.of(
                    JourneyType.body,
                    height: AarastV3Line.reading,
                  ),
                ),
              ),
            ],
          ),
          if (lat != null && lng != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('provider-details-map'),
                label: aarastText.providersOpenMap(context.gender),
                icon: LucideIcons.map,
                color: context.accent.primary,
                onPressed: () => openOutsideApp(
                  context,
                  providerMapUri(lat, lng),
                  aarastText.providersMapFailed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The phone's maps at his coordinates.
Uri providerMapUri(double latitude, double longitude) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$latitude,$longitude'},
);

/// The summary (from six reviews up: the average and how the stars spread),
/// the newest three, then «كل التقييمات (N)» and, past the first page,
/// «المزيد من التقييمات».
class _Reviews extends StatefulWidget {
  const _Reviews({
    required this.reviews,
    required this.summary,
    required this.providerName,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onReport,
  });

  final List<ProviderReview> reviews;
  final ProviderReviewSummary? summary;
  final String providerName;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final VoidCallback? Function(ProviderReview review) onReport;

  @override
  State<_Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<_Reviews> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    final summary = widget.summary;
    final total = summary?.count ?? reviews.length;
    final shown = _all ? reviews : reviews.take(_reviewsPreview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null &&
            summary.count >= _summaryFromReviews &&
            summary.average != null) ...[
          _ReviewSummary(summary: summary),
          const SizedBox(height: AarastV3Space.x3),
        ],
        JourneyBox(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, review) in shown.indexed) ...[
                if (index > 0)
                  const Divider(
                    height: AarastV3Size.line,
                    thickness: AarastV3Size.line,
                    indent: AarastV3Space.x4,
                    endIndent: AarastV3Space.x4,
                    color: AarastV3Color.line,
                  ),
                _ReviewRow(
                  review: review,
                  providerName: widget.providerName,
                  onReport: widget.onReport(review),
                ),
              ],
            ],
          ),
        ),
        if (!_all && total > shown.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('provider-details-all-reviews'),
              label: aarastText.providersReviewsAll(total),
              icon: LucideIcons.chevronDown,
              color: context.accent.primary,
              onPressed: () {
                setState(() => _all = true);
                if (reviews.length <= _reviewsPreview) {
                  widget.onLoadMore?.call();
                }
              },
            ),
          )
        else if (_all && widget.hasMore)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('provider-details-more-reviews'),
              label: aarastText.providersReviewsMore,
              icon: LucideIcons.chevronDown,
              color: context.accent.primary,
              onPressed: widget.loadingMore ? null : widget.onLoadMore,
            ),
          ),
      ],
    );
  }
}

/// The average large, its stars, how many, and how the stars spread, five
/// to one.
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.summary});

  final ProviderReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final average = summary.average!;
    final most = summary.distribution.values.fold<int>(
      0,
      (top, count) => count > top ? count : top,
    );
    return JourneyBox(
      key: const ValueKey('provider-details-review-summary'),
      padding: AarastV3Density.cardInsets,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: JourneyType.of(
                  JourneyType.count,
                  weight: JourneyType.bold,
                  height: AarastV3Line.numeral,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var star = 1; star <= 5; star++)
                    RatingStar(
                      filled: star <= average.round(),
                      size: AarastV3Icon.sm,
                    ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                aarastText.providersReviewCount(summary.count),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: AarastV3Space.x4),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AarastV3Space.half,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x2),
                        Expanded(
                          child: JourneyBar(
                            value: most == 0
                                ? 0
                                : (summary.distribution[star] ?? 0) / most,
                            color: AarastV3Color.brandAccentStrong,
                            height: AarastV3Size.bar,
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x2),
                        SizedBox(
                          width: AarastV3Space.x8,
                          child: Text(
                            '${summary.distribution[star] ?? 0}',
                            textAlign: TextAlign.end,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                        ),
                      ],
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

/// A review: the name and the stars, the words, and his published reply.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.review,
    required this.providerName,
    this.onReport,
  });

  final ProviderReview review;
  final String providerName;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final name =
        _clean(review.userName) ?? aarastText.providersReviewerFallback;
    final comment = review.comment?.trim() ?? '';
    final rating = review.rating.clamp(0, 5);
    final reply = _clean(review.reply?.body);
    return Padding(
      key: ValueKey('provider-details-review-${review.id}'),
      padding: AarastV3Density.rowInsets,
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
              const SizedBox(width: AarastV3Space.x2),
              Semantics(
                label: aarastText.providersStarsSpoken(rating),
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      RatingStar(filled: star <= rating, size: AarastV3Icon.sm),
                  ],
                ),
              ),
              const Spacer(),
              if (onReport != null)
                IconButton(
                  key: ValueKey('provider-details-review-report-${review.id}'),
                  tooltip: aarastText.providersReportReview,
                  onPressed: onReport,
                  icon: const Icon(
                    LucideIcons.flag,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
          if (comment.isNotEmpty)
            Text(
              comment,
              style: JourneyType.of(
                JourneyType.body,
                height: AarastV3Line.reading,
              ),
            ),
          if (reply != null) ...[
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
                    aarastText.providersReplyFrom(providerName),
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  Text(
                    reply,
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

/// A package's lines, «مصوران، فيلم 10 دقائق»: a natural line with commas,
/// not a chain of dots (REFINEMENT_SPEC 2.6).
String? _lines(String? text) {
  final lines = (text ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.isEmpty ? null : lines.join(aarastText.providersListSeparator);
}

/// Opens [uri] outside the app; says so when the phone cannot: it answers
/// no, or it throws (no app for the link, the plugin missing). The page's
/// map and work links caught nothing, so on such a phone the tap did
/// nothing and said nothing; the footer's copy of this did catch it.
Future<void> openOutsideApp(
  BuildContext context,
  Uri? uri,
  String failure,
) async {
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    }
  }
  if (!opened && context.mounted) AarastToast.showError(context, failure);
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
