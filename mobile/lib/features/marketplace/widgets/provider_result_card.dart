import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import 'provider_board_view.dart' show providerServiceIcon;

/// The photo's shape on the list card (Rashad 2026-11-18, «استكشف» made
/// anew): across the card's top, four high for every three wide, so a
/// portrait keeps the face and the shoulders, and a hall shows its room.
/// RA-MO-316's strip (120 high across the card) showed a nose and a mouth;
/// this is three times its height on a phone.
const _photoAspect = 4 / 3;

/// The provider's letter without a photo: a small square by the name, not a
/// band as tall as the card (Rashad 2026-11-17: a coloured quarter of every
/// card held one letter).
const _letterSize = 44.0;

/// What the name leaves for the heart's 48 target in the card's corner,
/// past the card's own padding.
const _heartRoom = 36.0;

/// A fixed dimension of this layout, not a spacing step (D74): the photo's
/// height on a shelf card, the sideways rows of «استكشف».
const _shelfPhotoHeight = 132.0;

/// Fixed dimensions of this layout (D74): the logo's disc on a shelf card
/// without a cover, and the paper ring around it.
const _shelfLogoSize = 76.0;
const _shelfLogoRing = 3.0;

/// Fixed dimensions of this layout (D74): the profile card's soft band and
/// the logo's disc that sits half on its edge.
const _bandHeight = 84.0;
const _profileLogoSize = 84.0;

/// w33 how old a published price is: «محدّث هذا الشهر», «محدّث قبل 8
/// شهور». An old price may have changed; a quote confirms it.
String? providerPriceAgeLabel(DateTime? updatedAt, {DateTime? now}) {
  if (updatedAt == null) return null;
  final days = (now ?? appNow()).difference(updatedAt).inDays;
  if (days < 31) return 'محدّث هذا الشهر';
  final months = days ~/ 30;
  return 'محدّث قبل ${arabicCount(months, one: 'شهر', two: 'شهرين', few: 'شهور', many: 'شهر')}';
}

/// What «مميز» means, from the badge on a provider's card (an undrawn sheet
/// on the journey kit; the handoff's design differences): he paid to come up
/// first; it is no recommendation from اعّرست.
Future<void> showProviderFeaturedSheet(BuildContext context) {
  return showJourneySheet<void>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const Key('provider-featured-sheet'),
      title: 'مميز',
      bottom: JourneyButton(
        label: 'فهمت',
        expand: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
      ),
      children: [
        Text(
          'هذا المزود دفع عشان يطلع أول. مو ترشيح من اعّرست.',
          style: JourneyType.of(JourneyType.bodyLarge),
        ),
      ],
    ),
  );
}

/// f02 a provider in «استكشف»: the photo, the name and rating, where, the
/// facts that matter (ضمن بندك، موثّق، غير مفعّل، مميز) and the price with
/// how old it is (w33). Only real facts; nothing is invented.
///
/// Rashad 2026-11-18: with a photo, the photo is the card's top, wide and
/// tall, the heart on it; the words under it take the card's width, so a
/// price and its age sit on one line. Without one there is no band: the
/// letter's small square by the name, as before.
class ProviderResultCard extends StatelessWidget {
  const ProviderResultCard({
    required this.businessName,
    required this.isFeatured,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetails,
    this.isVerified = false,
    this.isClaimed = true,
    this.categoryLabel,
    this.locationLabel,
    this.priceLabel,
    this.priceAgeLabel,
    this.budgetStatusLabel,
    this.budgetStatusColor,
    this.imageUrl,
    this.logoUrl,
    this.detailsButtonKey,
    this.favoriteButtonKey,
    super.key,
  });

  final String businessName;

  /// The provider's logo: in the small square by the name when there is no
  /// cover photo, never stretched over the card's top.
  final String? logoUrl;
  final bool isFeatured;
  final double ratingAverage;
  final int ratingCount;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback onDetails;

  /// An admin checked the provider's documents.
  final bool isVerified;

  /// False for a listing added from a public directory that its owner has
  /// not taken over yet: it does not take requests.
  final bool isClaimed;
  final String? categoryLabel;
  final String? locationLabel;
  final String? priceLabel;

  /// «محدّث هذا الشهر», «محدّث قبل 8 شهور».
  final String? priceAgeLabel;
  final String? budgetStatusLabel;
  final Color? budgetStatusColor;
  final String? imageUrl;
  final Key? detailsButtonKey;
  final Key? favoriteButtonKey;

  @override
  Widget build(BuildContext context) {
    final where = [?_clean(categoryLabel), ?_clean(locationLabel)].join(' · ');
    final price = _clean(priceLabel);
    // g02 «توفير البيانات»: no photo loads in the list.
    final dataSaver = context.watch<DevicePreferences?>()?.dataSaver ?? false;
    final photoUrl = dataSaver ? null : _clean(imageUrl);
    final logo = dataSaver ? null : _clean(logoUrl);
    // Rashad's phone 2026-11-18 («ما أعجبني»): a provider with a logo and
    // no cover was a small row. It is a profile card now: a soft band, the
    // logo large in a ringed disc on its edge, the words under it. Only a
    // provider with neither keeps the letter's row (no empty band).
    final profile = photoUrl == null && logo != null;
    final rich = photoUrl != null || profile;
    final badges = <Widget>[
      if (_clean(budgetStatusLabel) case final budget?)
        JourneyTag(
          label: budget,
          color: budgetStatusColor ?? AarastV3Color.mint,
          soft: (budgetStatusColor ?? AarastV3Color.mint).withValues(
            alpha: 0.12,
          ),
        ),
      if (!isClaimed)
        const JourneyTag(
          key: Key('provider-card-unclaimed'),
          label: 'غير مفعّل',
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
        )
      // Critique ز1: «جديد» stood for «not verified», so a provider with 125
      // reviews read as new. Only «موثّق» is said; the rest say nothing.
      else if (isVerified)
        JourneyTag(
          key: const Key('provider-card-verified'),
          label: 'موثّق',
          color: context.accent.primary,
          soft: context.accent.primarySoft,
        ),
      // The drawn «مميز» (f02). It is a paid placement (B-43), so a tap
      // says so plainly: not a recommendation from اعّرست.
      if (isFeatured) const _FeaturedTag(),
    ];
    final name = Text(
      businessName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // With a photo or a band the heart is on it, so the name and the
        // rating share the line; without one the name stops short of it.
        if (rich)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: name),
              if (ratingCount > 0) ...[
                const SizedBox(width: AarastV3Space.x2),
                _Rating(average: ratingAverage, count: ratingCount),
              ],
            ],
          )
        else
          Padding(
            padding: const EdgeInsetsDirectional.only(end: _heartRoom),
            child: name,
          ),
        if (where.isNotEmpty || (!rich && ratingCount > 0))
          // The place gives way first; with large text the rating goes
          // under it.
          Wrap(
            spacing: AarastV3Space.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (where.isNotEmpty)
                Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              if (!rich && ratingCount > 0)
                _Rating(average: ratingAverage, count: ratingCount),
            ],
          ),
        // No badge, no empty row between the place and the price.
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x2),
          Wrap(spacing: 6, runSpacing: 6, children: badges),
        ],
        const SizedBox(height: AarastV3Space.x2),
        ..._priceLines(context, price),
      ],
    );
    return Semantics(
      button: true,
      label: 'عرض تفاصيل $businessName',
      child: Material(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: detailsButtonKey,
          onTap: onDetails,
          child: photoUrl != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: _photoAspect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Photo(imageUrl: photoUrl, name: businessName),
                          PositionedDirectional(
                            top: AarastV3Space.x1,
                            end: AarastV3Space.x1,
                            child: _FavoriteHeart(
                              isFavorite: isFavorite,
                              onTap: onFavorite,
                              buttonKey: favoriteButtonKey,
                              onPhoto: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AarastV3Space.x4,
                        AarastV3Space.x3,
                        AarastV3Space.x4,
                        AarastV3Space.x4,
                      ),
                      child: words,
                    ),
                  ],
                )
              : profile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _bandHeight + _profileLogoSize / 2,
                      child: Stack(
                        children: [
                          PositionedDirectional(
                            top: 0,
                            start: 0,
                            end: 0,
                            height: _bandHeight,
                            // The hero's qamariya in faint paper lines,
                            // away from the logo (no gradient: D45).
                            child: ColoredBox(
                              key: const Key('provider-card-band'),
                              color: context.accent.primarySoft,
                              child: CustomPaint(
                                painter: JourneyQamariyaPainter(
                                  alpha: 0.75,
                                  centreX:
                                      Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? 0.2
                                      : 0.8,
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            top: _bandHeight - _profileLogoSize / 2,
                            start: AarastV3Space.x4,
                            child: _LogoDisc(
                              logoUrl: logo,
                              name: businessName,
                              size: _profileLogoSize,
                            ),
                          ),
                          PositionedDirectional(
                            top: AarastV3Space.x1,
                            end: AarastV3Space.x1,
                            child: _FavoriteHeart(
                              isFavorite: isFavorite,
                              onTap: onFavorite,
                              buttonKey: favoriteButtonKey,
                              onPhoto: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AarastV3Space.x4,
                        AarastV3Space.x2,
                        AarastV3Space.x4,
                        AarastV3Space.x4,
                      ),
                      child: words,
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AarastV3Space.x3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Letter(name: businessName),
                          const SizedBox(width: AarastV3Space.x3),
                          Expanded(child: words),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _FavoriteHeart(
                        isFavorite: isFavorite,
                        onTap: onFavorite,
                        buttonKey: favoriteButtonKey,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The price with how old it is (w33) on one line, the age quieter; or
  /// what to do without a price.
  List<Widget> _priceLines(BuildContext context, String? price) {
    final age = _clean(priceAgeLabel);
    return [
      if (price != null)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: price),
              if (age != null)
                TextSpan(
                  text: ' · $age',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: JourneyType.of(
            JourneyType.bodyLarge,
            weight: JourneyType.bold,
            color: context.accent.primary,
          ),
        ),
      // An unclaimed listing has no one to answer a request
      // (409 PROVIDER_NOT_CLAIMED), price or not.
      if (!isClaimed || price == null)
        Text(
          isClaimed
              ? context.say('اطلب عرض تعرف السعر', 'اطلبي عرض تعرفين السعر')
              : 'ما يستقبل طلبات لين يستلم صاحبه ملفه',
          key: isClaimed ? null : const Key('provider-card-unclaimed-note'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: JourneyType.of(
            price == null ? JourneyType.body : JourneyType.small,
            weight: JourneyType.bold,
            color: AarastV3Color.textMuted,
          ),
        ),
    ];
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// A provider on a sideways row of «استكشف» (Rashad 2026-11-18): the photo
/// across its top, its name, rating and kind, and where its prices start.
/// Without a cover its top is the plan's soft colour with the logo or the
/// service's icon, so a row keeps one height and no face is invented.
class ProviderShelfCard extends StatelessWidget {
  const ProviderShelfCard({
    required this.businessName,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetails,
    this.categoryLabel,
    this.locationLabel,
    this.fromPriceLabel,
    this.imageUrl,
    this.logoUrl,
    this.isFeatured = false,
    this.isClaimed = true,
    this.detailsButtonKey,
    super.key,
  });

  final String businessName;
  final double ratingAverage;
  final int ratingCount;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback onDetails;
  final String? categoryLabel;
  final String? locationLabel;

  /// «من 450,000 ر.ي»: the lowest published price, or what to do without.
  final String? fromPriceLabel;

  /// The cover photo; only it fills the card's top.
  final String? imageUrl;

  /// The logo, in a disc on the plan's colour when there is no cover.
  final String? logoUrl;
  final bool isFeatured;
  final bool isClaimed;
  final Key? detailsButtonKey;

  @override
  Widget build(BuildContext context) {
    final dataSaver = context.watch<DevicePreferences?>()?.dataSaver ?? false;
    final url = imageUrl?.trim();
    final photoUrl = dataSaver || url == null || url.isEmpty ? null : url;
    final kind = categoryLabel?.trim() ?? '';
    final place = locationLabel?.trim() ?? '';
    final where = [
      if (kind.isNotEmpty) kind,
      if (place.isNotEmpty) place,
    ].join(' · ');
    final price = fromPriceLabel?.trim();
    return Semantics(
      button: true,
      label: 'عرض تفاصيل $businessName',
      child: Material(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: detailsButtonKey,
          onTap: onDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _shelfPhotoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photoUrl != null)
                      _Photo(imageUrl: photoUrl, name: businessName)
                    else
                      _KindArt(
                        kind: kind,
                        name: businessName,
                        logoUrl: dataSaver ? null : logoUrl?.trim(),
                      ),
                    if (isFeatured)
                      const PositionedDirectional(
                        bottom: AarastV3Space.x2,
                        start: AarastV3Space.x2,
                        child: _FeaturedTag(onPhoto: true),
                      ),
                    PositionedDirectional(
                      top: AarastV3Space.x1,
                      end: AarastV3Space.x1,
                      child: _FavoriteHeart(
                        isFavorite: isFavorite,
                        onTap: onFavorite,
                        buttonKey: null,
                        onPhoto: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AarastV3Space.x3,
                    AarastV3Space.x2,
                    AarastV3Space.x3,
                    AarastV3Space.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (ratingCount > 0) ...[
                            _Rating(
                              average: ratingAverage,
                              count: ratingCount,
                              compact: true,
                            ),
                            if (where.isNotEmpty)
                              const SizedBox(width: AarastV3Space.x1),
                          ],
                          if (where.isNotEmpty)
                            Expanded(
                              child: Text(
                                where,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: JourneyType.of(
                                  JourneyType.caption,
                                  color: AarastV3Color.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        !isClaimed
                            ? 'ما يستقبل طلبات بعد'
                            : price == null || price.isEmpty
                            ? context.say('اطلب عرض', 'اطلبي عرض')
                            : price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: !isClaimed || price == null || price.isEmpty
                              ? AarastV3Color.textMuted
                              : context.accent.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shelf card's top without a cover photo: the plan's soft colour, and in
/// its middle the logo in a ringed disc, or the service's icon without one.
class _KindArt extends StatelessWidget {
  const _KindArt({required this.kind, required this.name, this.logoUrl});

  final String kind;
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      providerServiceIcon(kind),
      size: 34,
      color: context.accent.primary,
    );
    final logo = logoUrl;
    // Soft, as the app's tiles (Rashad's phone 2026-11-18): solid, two or
    // three in a row were a wall of green.
    return ColoredBox(
      key: const Key('provider-shelf-kind-art'),
      color: context.accent.primarySoft,
      child: SizedBox.expand(
        child: Center(
          child: logo == null || logo.isEmpty
              ? icon
              : _LogoDisc(logoUrl: logo, name: name, size: _shelfLogoSize),
        ),
      ),
    );
  }
}

/// «★ 4.8 (62)» in one dark colour (critique ز2: the saffron read 2.0 on
/// white).
class _Rating extends StatelessWidget {
  const _Rating({
    required this.average,
    required this.count,
    this.compact = false,
  });

  final double average;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.star,
          size: compact ? 13 : 15,
          color: AarastV3Color.brandAccentStrong,
        ),
        Text(
          ' ${average.toStringAsFixed(1)} ($count)',
          textDirection: TextDirection.ltr,
          maxLines: 1,
          style: JourneyType.of(
            compact ? JourneyType.caption : JourneyType.small,
            weight: JourneyType.bold,
          ),
        ),
      ],
    );
  }
}

/// The drawn «مميز» (f02): a paid placement (B-43); a tap says so.
class _FeaturedTag extends StatelessWidget {
  const _FeaturedTag({this.onPhoto = false});

  /// On a photo the tag is paper, so it reads over any picture.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'مميز: ليش يطلع أول؟',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('provider-card-featured'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showProviderFeaturedSheet(context),
        child: JourneyTag(
          label: 'مميز',
          color: context.accent.primary,
          soft: onPhoto ? AarastV3Color.paper : context.accent.primarySoft,
        ),
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
  return word.isEmpty ? 'م' : word.characters.first;
}

/// The provider's photo filling its frame from the top: a portrait keeps
/// its face and a wide cover its middle. A photo that fails to load leaves
/// a plain tint with the letter.
class _Photo extends StatelessWidget {
  const _Photo({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const Key('provider-card-photo'),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        // What is cut off a tall photo is its bottom, not the face.
        alignment: const Alignment(0, -0.6),
        errorBuilder: (context, error, stack) => ColoredBox(
          color: context.accent.primarySoft,
          child: Center(child: _LetterText(name: name)),
        ),
      ),
    );
  }
}

/// Without a cover photo: the provider's logo in a small rounded square, or
/// its letter when there is no logo (or it fails to load).
class _Letter extends StatelessWidget {
  const _Letter({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider-card-letter'),
      width: _letterSize,
      height: _letterSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.accent.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: _LetterText(name: name),
    );
  }
}

/// The provider's logo in a paper-ringed disc: the profile card's, on its
/// band's edge, and a shelf card's without a cover. Its letter on a tint
/// when the logo fails to load.
class _LogoDisc extends StatelessWidget {
  const _LogoDisc({
    required this.logoUrl,
    required this.name,
    required this.size,
  });

  final String logoUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider-card-logo'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(_shelfLogoRing),
      decoration: const BoxDecoration(
        color: AarastV3Color.paper,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          // A face sits in the top half of a portrait.
          alignment: const Alignment(0, -0.4),
          errorBuilder: (_, _, _) => ColoredBox(
            color: context.accent.primarySoft,
            child: Center(child: _LetterText(name: name)),
          ),
        ),
      ),
    );
  }
}

class _LetterText extends StatelessWidget {
  const _LetterText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        providerInitial(name),
        // A drawing, not text to read: it does not grow with the reader's
        // text size, or it would leave its square.
        textScaler: TextScaler.noScaling,
        style: JourneyType.of(
          JourneyType.title,
          weight: JourneyType.bold,
          color: context.accent.primary,
        ),
      ),
    );
  }
}

class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({
    required this.isFavorite,
    required this.onTap,
    required this.buttonKey,
    this.onPhoto = false,
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final Key? buttonKey;

  /// Over a photo the heart sits on a paper disc, so it reads on any
  /// picture.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final enabled = onTap != null;

    Widget heart = Icon(
      LucideIcons.heart,
      color: (isFavorite ? AarastV3Color.rose : AarastV3Color.textMuted)
          .withValues(alpha: enabled ? 1 : 0.42),
      size: onPhoto ? 20 : 22,
    );

    // A small pulse the moment it is saved.
    if (enabled && isFavorite && !reduceMotion) {
      heart = heart.animate().scale(
        begin: const Offset(0.6, 0.6),
        end: const Offset(1, 1),
        duration: 320.ms,
        curve: Curves.elasticOut,
      );
    }

    // Critique ز3: saved is a filled disc behind the heart, not its colour
    // alone (the icon set has no filled heart).
    final disc = isFavorite || onPhoto;
    return Semantics(
      button: true,
      enabled: enabled,
      label: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المزود',
      child: InkWell(
        key: buttonKey,
        onTap: enabled ? onTap : () {},
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        splashColor: enabled ? null : Colors.transparent,
        highlightColor: enabled ? null : Colors.transparent,
        hoverColor: enabled ? null : Colors.transparent,
        // A 48 target around the heart (DESIGN_SYSTEM: touch ≥ 48).
        child: SizedBox.square(
          dimension: AarastV3Space.x12,
          child: Center(
            child: disc
                ? DecoratedBox(
                    key: isFavorite
                        ? const ValueKey('favorite-heart-saved')
                        : null,
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? AarastV3Color.roseSoft
                          : AarastV3Color.paper,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        onPhoto ? AarastV3Space.x2 : AarastV3Space.x1,
                      ),
                      child: heart,
                    ),
                  )
                : heart,
          ),
        ),
      ),
    );
  }
}
