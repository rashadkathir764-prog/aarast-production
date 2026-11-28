import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/media/aarast_network_image.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/utils/currency_label.dart' show defaultCurrencyCode;
import '../../../core/widgets/aarast_pressable.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import 'provider_prices.dart';

// «الدليل»'s one set of facts (REFINEMENT_SPEC 2.7, merged with the first
// proposal's card shapes, docs/project/refinement/COMPARISON.md): a row in a
// list (a category, a search, an item) and a card on a shelf or in the
// favourites say the same facts in the same order.
//
//   picture 4:3 (work photo → cover → logo on a quiet tint → initial), with
//   «مميز» small at its start;
//   1. the name and ✓ (موثّق)
//   2. the city, with the category he was found under when it is not his
//   3. «★ 4.8 (63)», or «جديد» (no review, under 30 days), or «لا تقييمات بعد»
//   4. «من X», or «السعر عند الطلب»
//   5. one status at most: «لا يستقبل طلبات العروض بعد», «مغلق يوم عرسك»,
//      «محجوز يوم عرسك», or how his price stands against the plan's item.
// The row's heart sits at its end, off the picture (the first proposal: a
// heart on a 4:3 thumbnail crowded it); a card's heart sits on its picture.
// Never «متاح»: nothing in the system proves it (D131).

/// The row's picture: 112 wide, 4:3 (84 tall), so the heart at the row's end
/// leaves the words their room. A width of this layout, not a spacing step;
/// the height is the ratio's.
const _rowPictureWidth = 112.0;

/// A shelf card's width: two cards and a good edge of a third on a phone,
/// smaller than a half screen so a shelf reads as a strip of choices, not
/// two posters (COMPARISON.md: «ببطاقة أصغر»); it grows with a large text
/// size up to [_shelfCardWidest].
const _shelfCardWidth = 136.0;
const _shelfCardWidest = 184.0;

/// The share of the picture a logo takes when it stands in for a photo:
/// whole, never cut, on a quiet tint around it.
const _logoShare = 0.7;

/// «bride» or «groom», the `plan` select of an entry that follows the plan.
String planSideOf(BuildContext context) =>
    context.journeyProfile.isBride ? 'bride' : 'groom';

/// A category as the plan says it: the catalog has one venue kind for both,
/// which a groom's plan calls «قاعة» and a bride's «صالة»; every other kind
/// is the catalog's own name.
String providerKindName(BuildContext context, ProviderCategory? category) =>
    providerKindNameFor(category, bridePlan: context.journeyProfile.isBride);

String providerKindNameFor(
  ProviderCategory? category, {
  required bool bridePlan,
}) {
  if (category == null) return '';
  if (category.slug == venueCategorySlug) {
    return aarastText.providersVenueKind(bridePlan ? 'bride' : 'groom');
  }
  return category.nameAr.trim();
}

/// What is proven of the plan's wedding day [askedDay] in his calendar, in
/// the card's and the page's words; null when no day was asked, the day is
/// past, or nothing is known (D131: never «free»).
String? providerDayLine(
  DateTime? askedDay,
  ProviderDayStatus? status, {
  required DateTime now,
}) {
  if (askedDay == null || status == null) return null;
  if (planDayIsPast(askedDay, now)) return null;
  return switch (status) {
    ProviderDayStatus.closed => aarastText.providersDayClosed,
    ProviderDayStatus.full => aarastText.providersDayFull,
  };
}

/// The day is before today: nothing is said of it, and hiding the busy is
/// not offered.
bool planDayIsPast(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(day.year, day.month, day.day).isBefore(today);
}

/// The listing takes no request until its owner claims it (w33).
String get providerUnclaimedMessage => aarastText.providersUnclaimedLine;

/// The price line when he published no price.
String get providerPriceOnRequest => aarastText.providersPriceOnRequest;

/// The one status a card may carry, with its colour and its mark.
typedef ProviderStatusLine = ({String text, IconData icon, Color color});

/// What the rating line says.
enum ProviderRatingKind { stars, isNew, none }

/// The facts of one card, in their order, from the server's row alone:
/// what the row and the shelf card draw, and what the tests read.
class ProviderCardFacts {
  const ProviderCardFacts({
    required this.id,
    required this.name,
    required this.verified,
    required this.ratingAverage,
    required this.ratingCount,
    required this.ratingKind,
    required this.featured,
    this.place,
    this.price,
    this.status,
    this.photoUrl,
    this.logoUrl,
  });

  final String id;
  final String name;

  /// ✓ beside the name: documents checked, on a listing someone answers for.
  final bool verified;

  /// «صنعاء», or «تصوير · صنعاء» when he was found under a category that is
  /// not his own.
  final String? place;
  final double ratingAverage;
  final int ratingCount;
  final ProviderRatingKind ratingKind;

  /// «من X», «السعر عند الطلب», or null (an unclaimed listing with no
  /// price, or a saved provider whose prices are still being read).
  final String? price;
  final ProviderStatusLine? status;
  final String? photoUrl;
  final String? logoUrl;

  /// «مميز» now (a paid placement, B-43).
  final bool featured;

  bool get priceOnRequest => price == aarastText.providersPriceOnRequest;
}

/// [provider]'s card. [span] stands in for the row's own prices (a saved
/// provider's, read from his page); [priceKnown] false leaves the price out
/// while they are read. [budget]: the list came from one of the plan's
/// money items, so a card may say how his price stands against it.
ProviderCardFacts providerCardFacts(
  MarketplaceProvider provider, {
  required bool bridePlan,
  required DateTime now,
  DateTime? askedDay,
  ProviderPriceSpan? span,
  bool priceKnown = true,
  ProviderBudgetMatchIntent? budget,
  String? photoUrl,
  bool showCity = true,
  bool bookedByReader = false,
}) {
  final prices = span ?? providerPublishedSpan(provider);
  // A list scoped to one city says it once, in its count line («5
  // مزوّدين في صنعاء»); its rows do not repeat it ([showCity] false).
  final city = showCity ? provider.city?.nameAr.trim() : null;
  final matched = provider.matchedCategory;
  final ownKind = provider.primaryCategory?.id ?? provider.primaryCategoryId;
  final kind = matched != null && matched.id != ownKind
      ? providerKindNameFor(matched, bridePlan: bridePlan)
      : '';
  final place = switch ((kind.isEmpty, city == null || city.isEmpty)) {
    (true, true) => null,
    (true, false) => city,
    (false, true) => kind,
    (false, false) => aarastText.providersKindAndCity(kind, city!),
  };
  final ratingKind = provider.ratingCount > 0
      ? ProviderRatingKind.stars
      : provider.isNewAt(now)
      ? ProviderRatingKind.isNew
      : ProviderRatingKind.none;
  final String? price;
  if (!priceKnown) {
    price = null;
  } else {
    price =
        providerFromPriceShort(prices) ??
        (provider.isClaimed ? aarastText.providersPriceOnRequest : null);
  }
  return ProviderCardFacts(
    id: provider.id,
    name: provider.businessName,
    verified: provider.isClaimed && provider.isVerified,
    place: place,
    ratingAverage: provider.ratingAverage,
    ratingCount: provider.ratingCount,
    ratingKind: ratingKind,
    price: price,
    status: _status(provider, askedDay, now, prices, budget, bookedByReader),
    photoUrl:
        _clean(photoUrl) ??
        _clean(provider.cardPhotoUrl) ??
        _clean(provider.cardCoverUrl),
    logoUrl: _clean(provider.cardLogoUrl),
    featured: provider.isFeaturedAt(now),
  );
}

ProviderStatusLine? _status(
  MarketplaceProvider provider,
  DateTime? askedDay,
  DateTime now,
  ProviderPriceSpan? prices,
  ProviderBudgetMatchIntent? budget,
  bool bookedByReader,
) {
  if (!provider.isClaimed) {
    return (
      text: aarastText.providersUnclaimedLine,
      icon: LucideIcons.phone,
      color: AarastV3Color.textMuted,
    );
  }
  // His wedding-day booking is the reader's own: said as theirs, whatever
  // the day's count says (their booking is part of it).
  if (bookedByReader && askedDay != null && !planDayIsPast(askedDay, now)) {
    return (
      text: aarastText.providersDayYours,
      icon: LucideIcons.calendarCheck,
      color: AarastV3Color.mint,
    );
  }
  final day = providerDayLine(askedDay, provider.dayStatus, now: now);
  if (day != null) {
    return (
      text: day,
      icon: LucideIcons.calendarX,
      color: AarastV3Color.danger,
    );
  }
  if (budget == null || !budget.hasBudget || prices == null) return null;
  // A price in another currency is not compared with the item in riyals.
  if (prices.currency != defaultCurrencyCode) return null;
  // One rule with his page (`priceFitsItem`): the row said «ضمن بندك» of a
  // price up to a fifth over the item, and «أقل من بندك» where the page
  // said «ضمن بندك» of the same provider.
  if (priceFitsItem(prices.min, budget.allocatedValue)) {
    return (
      text: aarastText.providersBudgetWithin,
      icon: LucideIcons.checkCircle2,
      color: AarastV3Color.mint,
    );
  }
  return (
    text: aarastText.providersBudgetAbove,
    icon: LucideIcons.trendingUp,
    color: AarastV3Color.brandAccentStrong,
  );
}

/// A provider in a list of «الدليل» (a category, a search, a money item, an
/// order picked by hand): the picture small at the start with «مميز» on it,
/// the five lines beside it, and the heart at the row's end in the plan's
/// colour (the first proposal's row, REFINEMENT_SPEC 2.6). Every row of a
/// list is one height ([minHeight]) so the list reads in one rhythm; a
/// figure that needs a second line at the largest text grows its row rather
/// than being cut.
class ProviderRow extends StatelessWidget {
  const ProviderRow({
    required this.facts,
    required this.isFavorite,
    required this.onFavorite,
    required this.onOpen,
    required this.minHeight,
    super.key,
  });

  final ProviderCardFacts facts;
  final bool isFavorite;

  /// Null leaves the heart out.
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  /// [providerRowHeight] of the list, the same for every row.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final onFavorite = this.onFavorite;
    return Semantics(
      button: true,
      label: aarastText.providersOpenDetails(facts.name),
      // Its own ink layer: the row sits on the card's paper, which would
      // hide a splash drawn on the screen's material below it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('provider-row-${facts.id}'),
          onTap: onOpen,
          child: Padding(
            // The heart's 48 target takes the row's end inset, so its drawn
            // heart lines up with the card's edge and the words keep room.
            padding: onFavorite == null
                ? AarastV3Density.rowInsets
                : _rowInsetsWithHeart,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: providerRowPictureWidth(context),
                    child: ProviderCardPicture(facts: facts),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(child: ProviderFactLines(facts: facts)),
                  if (onFavorite != null)
                    ProviderFavoriteHeart(
                      isFavorite: isFavorite,
                      onTap: onFavorite,
                      buttonKey: Key('provider-heart-${facts.id}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row's inset when its heart closes it: the heart's own 48 target stands
/// in for the end inset (its drawn heart still sits 14 from the card's
/// edge), as in the first proposal's row.
const _rowInsetsWithHeart = EdgeInsetsDirectional.only(
  start: AarastV3Space.x4,
  top: AarastV3Space.x3,
  bottom: AarastV3Space.x3,
);

/// A provider on a category's shelf while browsing «الكل», and in the
/// favourites' grid: the first proposal's card. The picture across its top
/// with its corners round, the heart on its top corner and «مميز» at its
/// bottom start; the same five lines under it on the page.
///
/// In the favourites ([boxed]) the card is a paper box, so a pick for the
/// comparison ([pick], on the picture's top start) can outline it
/// ([picked]).
class ProviderShelfCard extends StatelessWidget {
  const ProviderShelfCard({
    required this.facts,
    required this.isFavorite,
    required this.onFavorite,
    required this.onOpen,
    this.boxed = false,
    this.picked = false,
    this.pick,
    super.key,
  });

  final ProviderCardFacts facts;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  /// A paper box around the card (the favourites' grid).
  final bool boxed;

  /// Picked for the comparison: the box takes the plan's edge.
  final bool picked;

  /// The comparison's box on the picture's top start.
  final Widget? pick;

  @override
  Widget build(BuildContext context) {
    final onFavorite = this.onFavorite;
    final pick = this.pick;
    final radius = BorderRadius.circular(AarastV3Radius.card);
    final picture = ProviderCardPicture(
      facts: facts,
      large: true,
      round: !boxed,
      topEnd: onFavorite == null
          ? null
          : ProviderFavoriteHeart(
              isFavorite: isFavorite,
              onTap: onFavorite,
              buttonKey: Key('provider-heart-${facts.id}'),
              onPhoto: true,
            ),
      topStart: pick,
    );
    final lines = ProviderFactLines(facts: facts);
    final Widget card = boxed
        ? DecoratedBox(
            key: picked ? const Key('provider-card-picked') : null,
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: picked
                  ? Border.all(
                      color: context.accent.primary,
                      width: AarastV3Size.lineStrong,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: AarastV3Color.paper,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    picture,
                    Padding(padding: _boxedCardInsets, child: lines),
                  ],
                ),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              picture,
              const SizedBox(height: AarastV3Space.x2),
              lines,
            ],
          );
    return Semantics(
      button: true,
      label: aarastText.providersOpenDetails(facts.name),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('provider-shelf-card-${facts.id}'),
          onTap: onOpen,
          borderRadius: radius,
          child: card,
        ),
      ),
    );
  }
}

/// The words' inset inside a boxed card.
const _boxedCardInsets = EdgeInsets.all(AarastV3Space.x3);

/// A shelf card's width at the reader's text size.
double providerShelfCardWidth(BuildContext context) => MediaQuery.textScalerOf(
  context,
).scale(_shelfCardWidth).clamp(_shelfCardWidth, _shelfCardWidest);

/// A card's height at [width]: its picture, the gap (or the box's insets),
/// the lines. Every card of a shelf or of the favourites' grid is this tall,
/// so they read in one rhythm.
double providerCardHeight(
  BuildContext context, {
  required double width,
  bool withPlace = true,
  bool boxed = false,
  Iterable<ProviderCardFacts>? facts,
}) =>
    width / AarastV3Media.feature +
    (boxed ? _boxedCardInsets.vertical : AarastV3Space.x2) +
    (facts == null
        ? providerFactLinesHeight(context, withPlace: withPlace)
        : providerFactsHeight(
            context,
            facts,
            width: boxed ? width - _boxedCardInsets.horizontal : width,
          ));

/// The five lines' height at the reader's text size, measured as the text
/// draws them, not guessed.
double providerFactLinesHeight(BuildContext context, {bool withPlace = true}) {
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: _lineProbe, style: style),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final name = line(JourneyType.of(JourneyType.body, weight: JourneyType.bold));
  final small = math.max(
    line(JourneyType.of(JourneyType.small, weight: JourneyType.bold)),
    AarastV3Icon.sm,
  );
  // The place line is reserved only when one card of the list has one.
  return name + AarastV3Space.half + (withPlace ? 4 : 3) * small;
}

/// One letter whose line height is a text line's: a measure, not words.
const _lineProbe = 'أ';

/// Whether any of [facts] has a place line, which sets the list's one
/// height ([providerRowHeight], [providerShelfCardHeight]).
bool providerFactsHavePlace(Iterable<ProviderCardFacts> facts) =>
    facts.any((item) => item.place != null);

/// The tallest of [facts]' lines laid out at [width], as [ProviderFactLines]
/// draws them: a name on two lines at most (the first proposal: a name cut
/// to «قاعة ق…» at the reader's text size says nothing), the price and the
/// status on two at most, never under the one-line height of
/// [providerFactLinesHeight]. Measured, not guessed, so every row or card of
/// one list takes this one height and none is cut.
double providerFactsHeight(
  BuildContext context,
  Iterable<ProviderCardFacts> facts, {
  required double width,
}) {
  final withPlace = providerFactsHavePlace(facts);
  final scaler = MediaQuery.textScalerOf(context);
  double measure(String text, TextStyle style, double room, int lines) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, room));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final nameStyle = JourneyType.of(JourneyType.body, weight: JourneyType.bold);
  final smallBold = JourneyType.of(JourneyType.small, weight: JourneyType.bold);
  final small = math.max(
    measure(_lineProbe, smallBold, width, 1),
    AarastV3Icon.sm,
  );
  final mark = AarastV3Icon.sm + AarastV3Space.x1;
  var tallest = providerFactLinesHeight(context, withPlace: withPlace);
  for (final item in facts) {
    final status = item.status;
    final price = item.price;
    final height =
        measure(
          item.name,
          nameStyle,
          width - (item.verified ? mark : 0),
          AarastV3Size.titleLines,
        ) +
        AarastV3Space.half +
        (withPlace ? small : 0) +
        small +
        (price == null
            ? small
            : math.max(small, measure(price, smallBold, width, 2))) +
        (status == null
            ? small
            : math.max(
                small,
                measure(status.text, smallBold, width - mark, 2),
              ));
    tallest = math.max(tallest, height);
  }
  return tallest;
}

/// The words' width in a row of a card [cardWidth] wide: what the picture,
/// the gap and the heart leave.
double providerRowWordsWidth(
  BuildContext context, {
  required double cardWidth,
  bool heart = true,
}) =>
    cardWidth -
    AarastV3Space.x4 -
    providerRowPictureWidth(context) -
    AarastV3Space.x3 -
    (heart ? AarastV3Size.touch : AarastV3Space.x4);

/// One height for every row of [facts] in a card [cardWidth] wide: the
/// picture's or the tallest lines', the larger.
double providerRowsHeight(
  BuildContext context,
  Iterable<ProviderCardFacts> facts, {
  required double cardWidth,
  bool heart = true,
}) => math.max(
  providerRowPictureWidth(context) / AarastV3Media.feature,
  providerFactsHeight(
    context,
    facts,
    width: providerRowWordsWidth(context, cardWidth: cardWidth, heart: heart),
  ),
);

/// The row picture's share of the screen at most (112 of a 360 phone): on
/// the narrowest phone a fixed width left the words, between the picture
/// and the heart, too little for a name at the reader's text size.
const _rowPictureShare = 0.3125;

/// The text size up to which the row's picture keeps its whole width (the
/// owner's phone reads at 1.3); past it the picture yields to the words, to
/// [_rowPictureLeast] of itself, since a price split over two lines at the
/// largest text costs more than a smaller thumbnail.
const _rowPictureFullUpTo = 1.3;
const _rowPictureLeast = 0.65;

/// The row's picture width: 112, or less on the narrowest phone or past the
/// text size [_rowPictureFullUpTo].
double providerRowPictureWidth(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final kept = (_rowPictureFullUpTo / scale).clamp(_rowPictureLeast, 1.0);
  return math.min(
        _rowPictureWidth,
        MediaQuery.sizeOf(context).width * _rowPictureShare,
      ) *
      kept;
}

/// Every row of a list: the picture's height or the lines', the larger.
double providerRowHeight(BuildContext context, {bool withPlace = true}) =>
    math.max(
      providerRowPictureWidth(context) / AarastV3Media.feature,
      providerFactLinesHeight(context, withPlace: withPlace),
    );

/// A shelf's card height: its picture, the gap, the lines of [facts] at
/// its width.
double providerShelfCardHeight(
  BuildContext context, {
  bool withPlace = true,
  Iterable<ProviderCardFacts>? facts,
}) => providerCardHeight(
  context,
  width: providerShelfCardWidth(context),
  withPlace: withPlace,
  facts: facts,
);

/// The five lines of a card: the name (two lines at most), where, the
/// rating, the price, one status (each two lines at most before a cut, as
/// [providerFactsHeight] measures them).
class ProviderFactLines extends StatelessWidget {
  const ProviderFactLines({required this.facts, super.key});

  final ProviderCardFacts facts;

  @override
  Widget build(BuildContext context) {
    final price = facts.price;
    final status = facts.status;
    final place = facts.place;
    TextStyle small({
      Color color = AarastV3Color.textMuted,
      bool bold = false,
    }) => JourneyType.of(
      JourneyType.small,
      color: color,
      weight: bold ? JourneyType.bold : FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameLine(name: facts.name, verified: facts.verified),
        const SizedBox(height: AarastV3Space.half),
        if (place != null)
          Text(
            place,
            key: const Key('provider-card-place'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small(),
          ),
        ProviderRating(
          average: facts.ratingAverage,
          count: facts.ratingCount,
          kind: facts.ratingKind,
        ),
        if (price != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final style = small(
                color: facts.priceOnRequest
                    ? AarastV3Color.textMuted
                    : AarastV3Color.ink,
                bold: true,
              );
              // The amount stays with its unit on one line (D118); only
              // when that line is wider than the words' room, at the
              // largest text, may the unit go to a second line rather
              // than the figure be cut.
              var fits = true;
              for (final chunk in price.split(' ')) {
                final painter = TextPainter(
                  text: TextSpan(text: chunk, style: style),
                  textDirection: TextDirection.rtl,
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                fits = fits && painter.width <= constraints.maxWidth;
                painter.dispose();
              }
              return Text(
                fits ? price : price.replaceAll(' ', ' '),
                key: const Key('provider-card-price'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              );
            },
          ),
        if (status != null)
          Row(
            key: const Key('provider-card-status'),
            children: [
              Icon(status.icon, size: AarastV3Icon.sm, color: status.color),
              const SizedBox(width: AarastV3Space.x1),
              Flexible(
                child: Text(
                  status.text,
                  // «مغلق يوم ع…» says less than nothing: a second line
                  // before a cut, measured in the list's one height.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: small(color: status.color, bold: true),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The name on two lines at most (the first proposal), and ✓ beside it when
/// his documents were checked.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.name, required this.verified});

  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final style = JourneyType.of(JourneyType.body, weight: JourneyType.bold);
    // ✓ stays beside the name when a long name ends in «…», level with its
    // first line when it takes two.
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final firstLine = painter.height;
    painter.dispose();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            name,
            key: const Key('provider-card-name'),
            maxLines: AarastV3Size.titleLines,
            overflow: TextOverflow.ellipsis,
            // As wide as its longest line, so ✓ follows the words and
            // does not drift to the far edge of a two-line name.
            textWidthBasis: TextWidthBasis.longestLine,
            style: style,
          ),
        ),
        if (verified) ...[
          const SizedBox(width: AarastV3Space.x1),
          Padding(
            padding: EdgeInsets.only(
              top: _centredOnLine(firstLine, AarastV3Icon.sm),
            ),
            child: Icon(
              LucideIcons.badgeCheck,
              key: const Key('provider-card-verified'),
              size: AarastV3Icon.sm,
              color: context.accent.primary,
              semanticLabel: aarastText.providersVerified,
            ),
          ),
        ],
      ],
    );
  }
}

/// «★ 4.8 (63)», the star in the saffron's text colour; «جديد» or «لا
/// تقييمات بعد» without a review, never empty stars.
class ProviderRating extends StatelessWidget {
  const ProviderRating({
    required this.average,
    required this.count,
    this.kind,
    this.size = JourneyType.small,
    super.key,
  });

  final double average;
  final int count;

  /// What to say; by [count] alone when null («لا تقييمات بعد» without one).
  final ProviderRatingKind? kind;

  /// The type size; the star follows it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind =
        this.kind ??
        (count > 0 ? ProviderRatingKind.stars : ProviderRatingKind.none);
    if (kind != ProviderRatingKind.stars) {
      return Text(
        kind == ProviderRatingKind.isNew
            ? aarastText.providersNew
            : aarastText.providersNoReviews,
        key: Key(
          kind == ProviderRatingKind.isNew
              ? 'provider-rating-new'
              : 'provider-rating-none',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: JourneyType.of(
          size,
          weight: kind == ProviderRatingKind.isNew
              ? JourneyType.bold
              : FontWeight.w400,
          color: kind == ProviderRatingKind.isNew
              ? context.accent.primary
              : AarastV3Color.textMuted,
        ),
      );
    }
    final figure = average.toStringAsFixed(1);
    return Semantics(
      label: aarastText.providersRatingSpoken(
        figure,
        aarastText.providersReviewCount(count),
      ),
      excludeSemantics: true,
      child: Row(
        key: const Key('provider-rating'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.star,
            size: size > JourneyType.small ? AarastV3Icon.md : AarastV3Icon.sm,
            color: AarastV3Color.brandAccentStrong,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: figure,
                    style: JourneyType.of(size, weight: JourneyType.bold),
                  ),
                  TextSpan(
                    text: ' ($count)',
                    style: JourneyType.of(size, color: AarastV3Color.textMuted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's 4:3 picture with «مميز» on it: at the top start of a row's
/// small picture, at the bottom start of a card's ([large]), where the
/// heart ([topEnd]) and the comparison's box ([topStart]) leave it room.
/// The one source order of a picture (REFINEMENT_SPEC 2.7): the work photo
/// the server chose (outside the women's album), else the cover; else the
/// logo whole in the middle of a quiet tint; else the initial. A picture
/// that fails to load falls to the next. «توفير البيانات» loads none.
class ProviderCardPicture extends StatelessWidget {
  const ProviderCardPicture({
    required this.facts,
    this.large = false,
    this.round = true,
    this.topEnd,
    this.topStart,
    super.key,
  });

  final ProviderCardFacts facts;

  /// A card's picture, not a row's: a larger letter and corner.
  final bool large;

  /// Its own corners; false inside a box that rounds them.
  final bool round;
  final Widget? topEnd;
  final Widget? topStart;

  @override
  Widget build(BuildContext context) {
    final topEnd = this.topEnd;
    final topStart = this.topStart;
    final picture = AspectRatio(
      aspectRatio: AarastV3Media.feature,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProviderPicture(
            name: facts.name,
            photoUrl: facts.photoUrl,
            logoUrl: facts.logoUrl,
            large: large,
          ),
          if (facts.featured)
            PositionedDirectional(
              top: large ? null : AarastV3Space.x1,
              bottom: large ? AarastV3Space.x2 : null,
              start: large ? AarastV3Space.x2 : AarastV3Space.x1,
              child: const ProviderFeaturedBadge(),
            ),
          if (topStart != null)
            PositionedDirectional(top: 0, start: 0, child: topStart),
          if (topEnd != null)
            PositionedDirectional(top: 0, end: 0, child: topEnd),
        ],
      ),
    );
    if (!round) return picture;
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        large ? AarastV3Radius.card : AarastV3Radius.control,
      ),
      child: picture,
    );
  }
}

/// A provider's picture with no marks: [photoUrl], else [logoUrl] whole on a
/// quiet tint, else the initial on the plan's soft colour.
class ProviderPicture extends StatelessWidget {
  const ProviderPicture({
    required this.name,
    this.photoUrl,
    this.logoUrl,
    this.large = false,
    super.key,
  });

  final String name;
  final String? photoUrl;
  final String? logoUrl;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final dataSaver = context.watch<DevicePreferences?>()?.dataSaver ?? false;
    final photo = dataSaver ? null : _clean(photoUrl);
    final logo = dataSaver ? null : _clean(logoUrl);
    final letter = ColoredBox(
      key: const Key('provider-card-letter'),
      color: context.accent.primarySoft,
      child: Center(
        child: _Initial(name: name, large: large),
      ),
    );
    final Widget logoOrLetter = logo == null
        ? letter
        : ColoredBox(
            key: const Key('provider-card-logo'),
            // The plan's soft colour, as the first proposal drew it: the
            // page's own grey left a shelf card's logo floating with no
            // picture around it.
            color: context.accent.primarySoft,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: _logoShare,
                heightFactor: _logoShare,
                child: AarastNetworkImage(
                  logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => letter,
                ),
              ),
            ),
          );
    if (photo == null) return logoOrLetter;
    return SizedBox.expand(
      key: const Key('provider-card-photo'),
      child: AarastNetworkImage(
        photo,
        fit: BoxFit.cover,
        // What is cut off a tall photo is its bottom, not the face.
        alignment: const Alignment(0, -0.6),
        errorBuilder: (_, _, _) => logoOrLetter,
      ),
    );
  }
}

/// The letter that stands for a name: its first word's first letter past
/// «ال», so «الفنان أيمن» is «ف» and not the «ا» of every article.
String providerInitial(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  var word = words.isEmpty ? '' : words.first;
  if (word.startsWith('ال') && word.characters.length > 3) {
    word = word.substring(2);
  }
  return word.isEmpty ? '؟' : word.characters.first;
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.large});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        providerInitial(name),
        // A drawing standing for a picture, not words to read: it keeps its
        // box's size at any text size.
        textScaler: TextScaler.noScaling,
        style: JourneyType.of(
          large ? JourneyType.count : JourneyType.hero,
          weight: JourneyType.bold,
          color: context.accent.primary,
        ),
      ),
    );
  }
}

/// «مميز» on the picture's start: a paid placement (B-43); a tap says so.
class ProviderFeaturedBadge extends StatelessWidget {
  const ProviderFeaturedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    void explain() => showProviderFeaturedSheet(context);
    return Semantics(
      container: true,
      button: true,
      label: aarastText.providersFeaturedSpoken,
      onTap: explain,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('provider-card-featured'),
        behavior: HitTestBehavior.opaque,
        onTap: explain,
        child: JourneyTag(
          label: aarastText.providersFeatured,
          color: context.accent.primaryDark,
          soft: AarastV3Color.paper,
        ),
      ),
    );
  }
}

/// What «مميز» means: he paid to come up first; no recommendation.
Future<void> showProviderFeaturedSheet(BuildContext context) {
  return showJourneySheet<void>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const Key('provider-featured-sheet'),
      title: aarastText.providersFeatured,
      bottom: JourneyButton(
        label: aarastText.providersGotIt,
        expand: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
      ),
      children: [
        Text(
          aarastText.providersFeaturedWhy,
          style: JourneyType.of(JourneyType.lead),
        ),
      ],
    ),
  );
}

/// The heart that saves a provider, in the plan's colour (REFINEMENT_SPEC
/// 2.6), touched in 48. Saved and not differ in shape, not by colour alone:
///
/// - at a row's end (the first proposal's place): the bare outline, or a
///   soft disc of the plan's colour behind it once saved;
/// - on a picture ([onPhoto]): a paper disc so it reads on any photo, or
///   the plan's colour filling the disc once saved.
class ProviderFavoriteHeart extends StatelessWidget {
  const ProviderFavoriteHeart({
    required this.isFavorite,
    required this.onTap,
    this.buttonKey,
    this.onPhoto = false,
    super.key,
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final Key? buttonKey;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final Color? disc = onPhoto
        ? (isFavorite ? accent.primary : AarastV3Color.paper)
        : (isFavorite ? accent.primarySoft : null);
    final heart = onPhoto && isFavorite
        ? AarastV3Color.onPrimary
        : accent.primary;
    return Semantics(
      button: true,
      selected: isFavorite,
      label: isFavorite
          ? aarastText.providersFavoriteRemove
          : aarastText.providersFavoriteAdd,
      excludeSemantics: true,
      onTap: onTap,
      child: AarastPressable(
        key: buttonKey,
        onTap: onTap,
        clip: false,
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        child: SizedBox.square(
          dimension: AarastV3Size.touch,
          child: Align(
            // On a picture the disc keeps to its corner; at a row's end it
            // stands in the middle of its target.
            alignment: onPhoto
                ? AlignmentDirectional.topEnd
                : AlignmentDirectional.center,
            child: Padding(
              padding: onPhoto
                  ? const EdgeInsets.all(AarastV3Space.x1)
                  : EdgeInsets.zero,
              child: Container(
                key: isFavorite ? const Key('provider-heart-saved') : null,
                width: AarastV3Size.markSmall,
                height: AarastV3Size.markSmall,
                decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
                child: Icon(
                  LucideIcons.heart,
                  size: onPhoto ? AarastV3Icon.sm : AarastV3Icon.md,
                  color: heart,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The favourites' box that picks a saved provider for the comparison, on
/// his card's picture: 24 drawn in a 48 target, on paper so it reads on any
/// photo, filled with the plan's colour once picked.
class ProviderComparePick extends StatelessWidget {
  const ProviderComparePick({
    required this.picked,
    required this.onTap,
    super.key,
  });

  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Semantics(
      button: true,
      checked: picked,
      label: aarastText.providersComparePick,
      excludeSemantics: true,
      onTap: onTap,
      child: AarastPressable(
        onTap: onTap,
        clip: false,
        borderRadius: BorderRadius.circular(AarastV3Radius.xs),
        child: SizedBox.square(
          dimension: AarastV3Size.touch,
          child: Center(
            child: Container(
              width: AarastV3Size.check,
              height: AarastV3Size.check,
              decoration: BoxDecoration(
                color: picked ? accent.primary : AarastV3Color.paper,
                borderRadius: BorderRadius.circular(AarastV3Radius.xs),
                border: Border.all(
                  color: picked ? accent.primary : AarastV3Color.fieldEdge,
                  width: AarastV3Size.lineStrong,
                ),
              ),
              child: picked
                  ? const Icon(
                      LucideIcons.check,
                      size: AarastV3Icon.sm,
                      color: AarastV3Color.onPrimary,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row as it loads: the picture's block and the lines' bars, the row's
/// own shape and height, so the list does not jump when the rows come.
class ProviderRowSkeleton extends StatelessWidget {
  const ProviderRowSkeleton({required this.minHeight, super.key});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final lines = providerFactLinesHeight(context) / 5;
    Widget bar(double share) => Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: share,
        child: Container(
          height: lines - AarastV3Space.x2,
          decoration: BoxDecoration(
            color: AarastV3Color.line,
            borderRadius: BorderRadius.circular(AarastV3Radius.xs),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: AarastV3Density.rowInsets,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: providerRowPictureWidth(context),
                child: AspectRatio(
                  aspectRatio: AarastV3Media.feature,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AarastV3Color.line,
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [bar(0.8), bar(0.4), bar(0.5), bar(0.6)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider's logo in a paper-ringed disc, his face on his page; his
/// initial on a tint when there is none.
class ProviderLogoBadge extends StatelessWidget {
  const ProviderLogoBadge({
    required this.name,
    required this.logoUrl,
    this.size = AarastV3Size.markLarge,
    super.key,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dataSaver = context.watch<DevicePreferences?>()?.dataSaver ?? false;
    final logo = dataSaver ? null : _clean(logoUrl);
    final letter = ColoredBox(
      color: context.accent.primarySoft,
      child: Center(child: _Initial(name: name, large: false)),
    );
    return Container(
      key: const Key('provider-logo-badge'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        shape: BoxShape.circle,
        border: Border.all(color: AarastV3Color.line),
      ),
      child: ClipOval(
        child: logo == null
            ? letter
            : AarastNetworkImage(
                logo,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => letter,
              ),
      ),
    );
  }
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The top inset that centres an icon of [icon] on a text line of [line]:
/// the verified mark sits on the name's first line, whatever its size.
double _centredOnLine(double line, double icon) =>
    math.max(0, (line - icon) / 2);
