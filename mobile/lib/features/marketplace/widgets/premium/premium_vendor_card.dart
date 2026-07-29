import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';

/// بطاقة المورد الأنيقة — صورة كبيرة على اليمين، ثم الاسم والفئة والتقييم
/// والموقع والسعر على اليسار، وزر "عرض التفاصيل" بلون العنّاب أسفل البطاقة.
/// تصميم مطابق لواجهة تبويب الموردين المعتمدة.
class PremiumVendorCard extends StatelessWidget {
  const PremiumVendorCard({
    required this.businessName,
    required this.isFeatured,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetails,
    this.categoryLabel,
    this.locationLabel,
    this.priceLabel,
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
  final String? categoryLabel;
  final String? locationLabel;
  final String? priceLabel;
  final String? budgetStatusLabel;
  final Color? budgetStatusColor;
  final String? imageUrl;
  final Key? detailsButtonKey;
  final Key? favoriteButtonKey;

  @override
  Widget build(BuildContext context) {
    final hasRating = ratingCount > 0;
    final hasCategory =
        categoryLabel != null && categoryLabel!.trim().isNotEmpty;
    final hasLocation =
        locationLabel != null && locationLabel!.trim().isNotEmpty;
    final hasPrice = priceLabel != null && priceLabel!.trim().isNotEmpty;
    final hasBudget =
        budgetStatusLabel != null && budgetStatusLabel!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(
              color: isFeatured
                  ? AarastDesignTokens.gold.withValues(alpha: 0.45)
                  : AarastDesignTokens.border,
            ),
            boxShadow: [
              BoxShadow(
                color: isFeatured
                    ? AarastDesignTokens.gold.withValues(alpha: 0.10)
                    : AarastDesignTokens.ink.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          businessName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AarastDesignTokens.ink,
                                fontWeight: FontWeight.w800,
                                height: 1.22,
                              ),
                        ),
                        if (hasCategory) ...[
                          const SizedBox(height: 2),
                          Text(
                            categoryLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AarastDesignTokens.burgundy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                        if (hasRating || hasLocation) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              if (hasRating)
                                _RatingChip(
                                  average: ratingAverage,
                                  count: ratingCount,
                                ),
                              if (hasRating && hasLocation)
                                const SizedBox(width: 12),
                              if (hasLocation)
                                Expanded(
                                  child: _LocationLabel(label: locationLabel!),
                                ),
                            ],
                          ),
                        ],
                        if (hasPrice) ...[
                          const SizedBox(height: 7),
                          Text(
                            priceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AarastDesignTokens.burgundy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                        if (hasBudget) ...[
                          const SizedBox(height: 7),
                          _BudgetChip(
                            label: budgetStatusLabel!,
                            color: budgetStatusColor ?? AarastDesignTokens.gold,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: FilledButton(
                            key: detailsButtonKey,
                            onPressed: onDetails,
                            style: FilledButton.styleFrom(
                              backgroundColor: AarastDesignTokens.burgundy,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AarastDesignTokens.radiusMd,
                                ),
                              ),
                              textStyle: Theme.of(context).textTheme.labelLarge,
                            ),
                            child: const Text('عرض التفاصيل'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _VendorImage(
                  imageUrl: imageUrl,
                  name: businessName,
                  isFeatured: isFeatured,
                  isFavorite: isFavorite,
                  onFavorite: onFavorite,
                  favoriteButtonKey: favoriteButtonKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorImage extends StatelessWidget {
  const _VendorImage({
    required this.imageUrl,
    required this.name,
    required this.isFeatured,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteButtonKey,
  });

  final String? imageUrl;
  final String name;
  final bool isFeatured;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final Key? favoriteButtonKey;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      width: 112,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadiusDirectional.only(
          topEnd: Radius.circular(AarastDesignTokens.radiusLg),
          bottomEnd: Radius.circular(AarastDesignTokens.radiusLg),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null || url.isEmpty)
            _VendorImagePlaceholder(name: name)
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  _VendorImagePlaceholder(name: name),
            ),
          if (isFeatured)
            const PositionedDirectional(
              top: 8,
              start: 8,
              child: _FeaturedBadge(),
            ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AarastDesignTokens.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AarastDesignTokens.ink.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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

class _VendorImagePlaceholder extends StatelessWidget {
  const _VendorImagePlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : 'م';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AarastDesignTokens.goldSoft,
            AarastDesignTokens.goldMonogram,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AarastDesignTokens.goldDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AarastDesignTokens.goldDeep, AarastDesignTokens.gold],
        ),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.ink.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'مميز',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.star, size: 13, color: AarastDesignTokens.gold),
        const SizedBox(width: 3),
        Text(
          '${average.toStringAsFixed(1)} ($count)',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AarastDesignTokens.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.mapPin,
          size: 13,
          color: AarastDesignTokens.muted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AarastDesignTokens.muted),
          ),
        ),
      ],
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.target, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
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
      color:
          (isFavorite ? AarastDesignTokens.burgundy : AarastDesignTokens.muted)
              .withValues(alpha: enabled ? 1 : 0.42),
      size: 22,
    );

    // نبضة صغيرة لحظة الحفظ.
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
      label: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المورد',
      child: InkWell(
        key: buttonKey,
        onTap: enabled ? onTap : () {},
        borderRadius: BorderRadius.circular(99),
        splashColor: enabled ? null : Colors.transparent,
        highlightColor: enabled ? null : Colors.transparent,
        hoverColor: enabled ? null : Colors.transparent,
        child: SizedBox(width: 36, height: 36, child: Center(child: heart)),
      ),
    );
  }
}
