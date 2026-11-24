import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/aarast_network_image.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import 'provider_board_view.dart' show providerServiceIcon;

/// The picture at a row's start (Rashad 2026-11-19, «شكل الكروت سيء»): a
/// square as tall as three lines of words, so a row is a row and not half
/// the screen. The cover, else the logo whole, else the letter.
const _thumbSide = AarastV3Size.markHero;

/// The logo's disc on a shelf card without a cover, and its paper ring.
const _shelfLogoSide = AarastV3Media.logoLarge;
const _shelfLogoRing = 3.0;

/// Where a row stands in its group: the group is one paper surface with a
/// hair between rows (Rashad 2026-11-19), so only its outer corners round.
enum ProviderRowPlace { only, first, middle, last }

/// The place of row [index] in a group of [count].
ProviderRowPlace providerRowPlace(int index, int count) {
  if (count <= 1) return ProviderRowPlace.only;
  if (index == 0) return ProviderRowPlace.first;
  if (index == count - 1) return ProviderRowPlace.last;
  return ProviderRowPlace.middle;
}

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
          style: JourneyType.of(JourneyType.lead),
        ),
      ],
    ),
  );
}

/// f02 a provider in «استكشف», as a row (Rashad 2026-11-19): the picture
/// small at the start, then the name, the rating and where, the facts that
/// matter (ضمن بندك، غير مفعّل، مميز) and the price with how old it is
/// (w33). The heart at the end. Only real facts; nothing is invented.
///
/// Rows sit in one paper group with a hair between them ([place]), as a
/// list of choices to compare, not a pile of separate boxes.
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
    this.place = ProviderRowPlace.only,
    this.detailsButtonKey,
    this.favoriteButtonKey,
    super.key,
  });

  final String businessName;

  /// The provider's logo: the row's picture when there is no cover photo.
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

  /// The kind; left out under a kind's own title, where it would repeat it.
  final String? categoryLabel;
  final String? locationLabel;
  final String? priceLabel;

  /// «محدّث هذا الشهر», «محدّث قبل 8 شهور».
  final String? priceAgeLabel;
  final String? budgetStatusLabel;
  final Color? budgetStatusColor;
  final String? imageUrl;

  /// Where the row stands in its group.
  final ProviderRowPlace place;
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
        ),
      // The drawn «مميز» (f02). It is a paid placement (B-43), so a tap
      // says so plainly: not a recommendation from اعّرست.
      if (isFeatured) const _FeaturedTag(),
    ];
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NameLine(
          name: businessName,
          // Critique ز1: only «موثّق» is said, and a listing nobody answers
          // for never is. A mark by the name, not a tag on every card.
          verified: isClaimed && isVerified,
        ),
        if (ratingCount > 0 || where.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x1),
          _MetaLine(
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            where: where,
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x2),
          Wrap(
            spacing: AarastV3Space.x1,
            runSpacing: AarastV3Space.x1,
            children: badges,
          ),
        ],
        const SizedBox(height: AarastV3Space.x2),
        ..._priceLines(context, price),
      ],
    );
    final corner = Radius.circular(AarastV3Radius.card);
    final top =
        place == ProviderRowPlace.only || place == ProviderRowPlace.first;
    final bottom =
        place == ProviderRowPlace.only || place == ProviderRowPlace.last;
    return Semantics(
      button: true,
      label: 'عرض تفاصيل $businessName',
      child: Material(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.vertical(
          top: top ? corner : Radius.zero,
          bottom: bottom ? corner : Radius.zero,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: detailsButtonKey,
          onTap: onDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!top)
                const Divider(
                  height: AarastV3Size.line,
                  thickness: AarastV3Size.line,
                  indent: AarastV3Space.x3,
                  endIndent: AarastV3Space.x3,
                  color: AarastV3Color.line,
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AarastV3Space.x3,
                  top: AarastV3Space.x3,
                  bottom: AarastV3Space.x3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                      child: SizedBox.square(
                        dimension: _thumbSide,
                        child: _Thumb(
                          photoUrl: photoUrl,
                          logoUrl: logo,
                          name: businessName,
                        ),
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x3),
                    Expanded(child: words),
                    _FavoriteHeart(
                      isFavorite: isFavorite,
                      onTap: onFavorite,
                      buttonKey: favoriteButtonKey,
                    ),
                  ],
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
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
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
            JourneyType.small,
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

/// The name, on two lines at most, and «موثّق» as a mark beside it.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.name, required this.verified});

  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (verified)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AarastV3Space.x1,
                ),
                child: Semantics(
                  label: 'موثّق',
                  child: Icon(
                    LucideIcons.badgeCheck,
                    key: const Key('provider-card-verified'),
                    size: AarastV3Icon.sm,
                    color: context.accent.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
    );
  }
}

/// «★ 4.8 (63) · صنعاء»: the rating first, then where; the place gives
/// way first, and with large text it goes under the rating.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.ratingAverage,
    required this.ratingCount,
    required this.where,
    this.singleLine = false,
  });

  final double ratingAverage;
  final int ratingCount;
  final String where;

  /// A shelf card is measured for one meta line: there the rating and the
  /// place share it, each cut with an ellipsis. A long address that wrapped
  /// under the rating pushed the card's price out of its row. A list row
  /// grows with its words, so there they wrap.
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final rated = ratingCount > 0;
    final place = Text(
      where,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: JourneyType.of(JourneyType.small, color: AarastV3Color.textMuted),
    );
    if (singleLine) {
      return Row(
        children: [
          if (rated)
            Flexible(
              child: _Rating(average: ratingAverage, count: ratingCount),
            ),
          if (rated && where.isNotEmpty)
            const SizedBox(width: AarastV3Space.x2),
          if (where.isNotEmpty) Flexible(child: place),
        ],
      );
    }
    return Wrap(
      spacing: AarastV3Space.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rated) _Rating(average: ratingAverage, count: ratingCount),
        if (where.isNotEmpty) place,
      ],
    );
  }
}

/// A row's picture: the cover; else the logo whole; else the letter.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photoUrl,
    required this.logoUrl,
    required this.name,
  });

  final String? photoUrl;
  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    if (photo != null) return _Photo(imageUrl: photo, name: name);
    final logo = logoUrl;
    if (logo != null) {
      return SizedBox.expand(
        key: const Key('provider-card-logo'),
        child: AarastNetworkImage(
          logo,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.4),
          errorBuilder: (context, error, stack) => _Letter(name: name),
        ),
      );
    }
    return _Letter(name: name);
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
    final price = fromPriceLabel?.trim();
    final priced = isClaimed && price != null && price.isNotEmpty;
    // Rashad 2026-11-19: no box. The picture is the card, its corners
    // round; the words sit on the page under it, so a row of cards reads
    // light and a short name leaves no empty paper.
    return Semantics(
      button: true,
      label: 'عرض تفاصيل $businessName',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: detailsButtonKey,
          onTap: onDetails,
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AarastV3Radius.card),
                child: AspectRatio(
                  aspectRatio: 1,
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
                        top: 0,
                        end: 0,
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
              ),
              const SizedBox(height: AarastV3Space.x2),
              Text(
                businessName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              // Under its kind's title the kind is not said again.
              _MetaLine(
                ratingAverage: ratingAverage,
                ratingCount: ratingCount,
                where: place,
                singleLine: true,
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                !isClaimed
                    ? 'ما يستقبل طلبات بعد'
                    : priced
                    ? price
                    : context.say('اطلب عرض', 'اطلبي عرض'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: priced ? AarastV3Color.ink : AarastV3Color.textMuted,
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
      size: AarastV3Icon.xl,
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
              : _LogoDisc(logoUrl: logo, name: name, size: _shelfLogoSide),
        ),
      ),
    );
  }
}

/// «★ 4.8 (62)» in one dark colour (critique ز2: the saffron read 2.0 on
/// white).
class _Rating extends StatelessWidget {
  const _Rating({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.star,
          size: AarastV3Icon.sm,
          color: AarastV3Color.brandAccentStrong,
        ),
        // Gives way before the row does, on the narrowest phone at the
        // largest text.
        Flexible(
          child: Text(
            ' ${average.toStringAsFixed(1)} ($count)',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: JourneyType.of(JourneyType.small, weight: JourneyType.bold),
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
    void explain() => showProviderFeaturedSheet(context);
    // RA-MO-361: its own node with its own tap. Without them a screen
    // reader's double tap on «مميز» opened the provider's page under it.
    return Semantics(
      container: true,
      button: true,
      label: 'مميز: ليش يطلع أول؟',
      onTap: explain,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('provider-card-featured'),
        behavior: HitTestBehavior.opaque,
        onTap: explain,
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
      child: AarastNetworkImage(
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

/// Without a cover or a logo: the provider's letter on the plan's soft
/// colour, filling the row's square picture.
class _Letter extends StatelessWidget {
  const _Letter({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('provider-card-letter'),
      color: context.accent.primarySoft,
      child: Center(child: _LetterText(name: name)),
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
        child: AarastNetworkImage(
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
          JourneyType.lead,
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
      size: onPhoto ? AarastV3Icon.md : AarastV3Icon.lg,
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
