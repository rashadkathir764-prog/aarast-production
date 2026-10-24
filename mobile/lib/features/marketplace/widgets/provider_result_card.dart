import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/utils/arabic_count.dart';

/// w33 how old a published price is: «محدّث هذا الشهر», «محدّث قبل 8
/// شهور». An old price may have changed; a quote confirms it.
String? providerPriceAgeLabel(DateTime? updatedAt, {DateTime? now}) {
  if (updatedAt == null) return null;
  final days = (now ?? DateTime.now()).difference(updatedAt).inDays;
  if (days < 31) return 'محدّث هذا الشهر';
  final months = days ~/ 30;
  return 'محدّث قبل ${arabicCount(months, one: 'شهر', two: 'شهرين', few: 'شهور', many: 'شهر')}';
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
    final where = [
      ?_clean(categoryLabel),
      ?_clean(locationLabel),
    ].join(' · ');
    final price = _clean(priceLabel);
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
      else if (isVerified)
        const JourneyTag(
          key: Key('provider-card-verified'),
          label: 'موثّق',
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
        )
      else
        const JourneyTag(
          label: 'جديد',
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.line,
        ),
      if (isFeatured)
        const JourneyTag(
          label: 'مميز',
          color: AarastV3Color.primary,
          soft: AarastV3Color.primarySoft,
        ),
    ];
    return Semantics(
      button: true,
      label: 'عرض تفاصيل $businessName',
      child: Material(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: detailsButtonKey,
          onTap: onDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cover(
                imageUrl: imageUrl,
                name: businessName,
                isFavorite: isFavorite,
                onFavorite: onFavorite,
                favoriteButtonKey: favoriteButtonKey,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
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
                        if (ratingCount > 0) ...[
                          const Icon(
                            LucideIcons.star,
                            size: 15,
                            color: AarastV3Color.saffron,
                          ),
                          Text(
                            ' ${ratingAverage.toStringAsFixed(1)} ($ratingCount)',
                            textDirection: TextDirection.ltr,
                            style: JourneyType.of(
                              JourneyType.body,
                              weight: JourneyType.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
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
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                    const SizedBox(height: 8),
                    if (price != null)
                      Text(
                        [price, ?_clean(priceAgeLabel)].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                          color: AarastV3Color.cobalt,
                        ),
                      ),
                    // An unclaimed listing has no one to answer a request
                    // (409 PROVIDER_NOT_CLAIMED), price or not.
                    if (!isClaimed || price == null)
                      Text(
                        isClaimed
                            ? 'اطلب عرض تعرف السعر'
                            : 'ما يستقبل طلبات لين يستلم صاحبه ملفه',
                        key: isClaimed
                            ? null
                            : const Key('provider-card-unclaimed-note'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: JourneyType.of(
                          price == null ? JourneyType.bodyLarge : JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textMuted,
                        ),
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

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.imageUrl,
    required this.name,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteButtonKey,
  });

  final String? imageUrl;
  final String name;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final Key? favoriteButtonKey;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : 'م';
    final placeholder = ColoredBox(
      color: AarastV3Color.cobaltSoft,
      child: Center(
        child: Text(
          initial,
          style: JourneyType.of(
            JourneyType.count,
            weight: JourneyType.bold,
            color: AarastV3Color.cobalt,
          ),
        ),
      ),
    );
    return SizedBox(
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // g02 «توفير البيانات»: no photo loads in the list.
          if (url == null || url.isEmpty || (context.watch<DevicePreferences?>()?.dataSaver ?? false))
            placeholder
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => placeholder,
            ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AarastV3Color.paper.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: _FavoriteHeart(
                isFavorite: isFavorite,
                onTap: onFavorite,
                buttonKey: favoriteButtonKey,
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(99),
        splashColor: enabled ? null : Colors.transparent,
        highlightColor: enabled ? null : Colors.transparent,
        hoverColor: enabled ? null : Colors.transparent,
        child: SizedBox(width: 40, height: 40, child: Center(child: heart)),
      ),
    );
  }
}
