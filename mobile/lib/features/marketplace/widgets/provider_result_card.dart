import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';

/// A fixed dimension of this layout, not a spacing step (D74): how wide the
/// photo stands beside the card's words.
const _photoWidth = 112.0;

/// The provider's letter without a photo: a small square by the name, not a
/// band as tall as the card (Rashad 2026-11-17: a coloured quarter of every
/// card held one letter).
const _letterSize = 44.0;

/// What the name leaves for the heart's 48 target in the card's corner,
/// past the card's own padding.
const _heartRoom = 36.0;

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
/// facts that matter (ضمن بندك، موثّق، جديد، غير مفعّل) and the price with
/// how old it is (w33). Only real facts; nothing is invented.
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
    this.detailsButtonKey,
    this.favoriteButtonKey,
    super.key,
  });

  final String businessName;
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
    final url = _clean(imageUrl);
    // g02 «توفير البيانات»: no photo loads in the list.
    final dataSaver = context.watch<DevicePreferences?>()?.dataSaver ?? false;
    final photoUrl = dataSaver ? null : url;
    final textStart = photoUrl != null
        ? _photoWidth + AarastV3Space.x3
        : AarastV3Space.x3 + _letterSize + AarastV3Space.x3;
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
      if (isFeatured)
        Semantics(
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
              soft: context.accent.primarySoft,
            ),
          ),
        ),
    ];
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
          // RA-MO-316: the photo stands beside what the card says, as tall
          // as the card, so a face is kept whole and nothing is left blank
          // under it. It was a strip across the card, 120 high: a portrait
          // showed a nose and a mouth, and without a photo half the card
          // was an empty band.
          child: Stack(
            children: [
              // The words set the card's height; the photo fills it.
              if (photoUrl != null)
                PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  start: 0,
                  width: _photoWidth,
                  child: _Photo(imageUrl: photoUrl, name: businessName),
                )
              else
                PositionedDirectional(
                  top: AarastV3Space.x3,
                  start: AarastV3Space.x3,
                  child: _Letter(name: businessName),
                ),
              ConstrainedBox(
                // As wide as the list gives it, whatever the words' length.
                constraints: BoxConstraints(
                  minHeight: photoUrl != null ? _photoWidth : 0,
                  minWidth: double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    textStart,
                    AarastV3Space.x3,
                    AarastV3Space.x3,
                    AarastV3Space.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The name stops short of the heart in the corner.
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: _heartRoom,
                        ),
                        child: Text(
                          businessName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: JourneyType.of(
                            JourneyType.title,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      if (where.isNotEmpty || ratingCount > 0)
                        // The place gives way first; with large text
                        // the rating goes under it.
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
                            if (ratingCount > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Critique ز2: one dark colour for the
                                  // star, as on the provider's page; the
                                  // saffron read 2.0 on white.
                                  const Icon(
                                    LucideIcons.star,
                                    size: 15,
                                    color: AarastV3Color.brandAccentStrong,
                                  ),
                                  Flexible(
                                    child: Text(
                                      ' ${ratingAverage.toStringAsFixed(1)} ($ratingCount)',
                                      textDirection: TextDirection.ltr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: JourneyType.of(
                                        JourneyType.small,
                                        weight: JourneyType.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      const SizedBox(height: AarastV3Space.x2),
                      // No badge, no empty row between the place and price.
                      if (badges.isNotEmpty) ...[
                        Wrap(spacing: 6, runSpacing: 6, children: badges),
                        const SizedBox(height: AarastV3Space.x2),
                      ],
                      ..._priceLines(context, price),
                    ],
                  ),
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

  /// The price with how old it is (w33), or what to do without one.
  List<Widget> _priceLines(BuildContext context, String? price) {
    return [
      if (price != null)
        Text(
          [price, ?_clean(priceAgeLabel)].join(' · '),
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
            price == null ? JourneyType.bodyLarge : JourneyType.small,
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

/// The provider's photo as tall as the card: a portrait keeps its face and
/// a wide cover its middle. A photo that fails to load leaves a plain tint
/// with the letter.
class _Photo extends StatelessWidget {
  const _Photo({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    // Flush with the card's edge, which rounds its outer corners.
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

/// Without a photo: the provider's letter in a small rounded square.
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
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final enabled = onTap != null;

    Widget heart = Icon(
      LucideIcons.heart,
      color: (isFavorite ? AarastV3Color.rose : AarastV3Color.textMuted)
          .withValues(alpha: enabled ? 1 : 0.42),
      size: 22,
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
          // Critique ز3: saved is a filled disc behind the heart, not its
          // colour alone (the icon set has no filled heart).
          child: Center(
            child: isFavorite
                ? DecoratedBox(
                    key: const ValueKey('favorite-heart-saved'),
                    decoration: const BoxDecoration(
                      color: AarastV3Color.roseSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AarastV3Space.x1),
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
