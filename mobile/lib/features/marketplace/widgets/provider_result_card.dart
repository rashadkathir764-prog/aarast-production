import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';

/// بطاقة مورد مضغوطة تعرض الحقائق المتاحة فقط، مع صورة ثابتة وإجراء تفاصيل
/// خفيف حتى تبقى قائمة الموردين واضحة وآمنة على الشاشات الضيقة.
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

  /// An admin checked the provider's documents.
  final bool isVerified;
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: isFeatured
                  ? AppTheme.focus.withValues(alpha: 0.45)
                  : AppTheme.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VendorImage(
                  imageUrl: imageUrl,
                  name: businessName,
                  isFeatured: isFeatured,
                  isFavorite: isFavorite,
                  onFavorite: onFavorite,
                  favoriteButtonKey: favoriteButtonKey,
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              businessName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    height: 1.18,
                                  ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: AppTheme.space4),
                            const Tooltip(
                              message: 'مورد موثّق',
                              child: Icon(
                                LucideIcons.shieldCheck,
                                key: Key('provider-card-verified'),
                                size: 17,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasCategory) ...[
                        const SizedBox(height: AppTheme.space2),
                        Text(
                          categoryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppTheme.brand,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                      if (hasRating || hasLocation) ...[
                        const SizedBox(height: AppTheme.space6),
                        Row(
                          children: [
                            if (hasRating)
                              _RatingChip(
                                average: ratingAverage,
                                count: ratingCount,
                              ),
                            if (hasRating && hasLocation)
                              const SizedBox(width: AppTheme.space8),
                            if (hasLocation)
                              Expanded(
                                child: _LocationLabel(label: locationLabel!),
                              ),
                          ],
                        ),
                      ],
                      if (hasPrice) ...[
                        const SizedBox(height: AppTheme.space6),
                        Text(
                          priceLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.brand,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                      if (hasBudget) ...[
                        const SizedBox(height: AppTheme.space6),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _BudgetChip(
                            label: budgetStatusLabel!,
                            color: budgetStatusColor ?? AppTheme.focus,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space6),
                      Semantics(
                        button: true,
                        label: 'عرض تفاصيل $businessName',
                        child: InkWell(
                          key: detailsButtonKey,
                          onTap: onDetails,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: AppTheme.space4,
                              bottom: AppTheme.space4,
                              end: AppTheme.space4,
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'عرض التفاصيل',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppTheme.brand,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space4),
                                const Icon(
                                  LucideIcons.chevronLeft,
                                  size: AppTheme.iconSm,
                                  color: AppTheme.brand,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: url == null || url.isEmpty
                ? _VendorImagePlaceholder(name: name)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        _VendorImagePlaceholder(name: name),
                  ),
          ),
          if (isFeatured)
            const PositionedDirectional(
              start: 6,
              bottom: 6,
              child: _FeaturedBadge(),
            ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.9),
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

class _VendorImagePlaceholder extends StatelessWidget {
  const _VendorImagePlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : 'م';
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppTheme.brandMuted),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.brand,
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
        color: AppTheme.brand,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
        const Icon(LucideIcons.star, size: 13, color: AppTheme.focus),
        const SizedBox(width: 3),
        Text(
          '${average.toStringAsFixed(1)} ($count)',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.textPrimary,
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
        const Icon(LucideIcons.mapPin, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
      color: (isFavorite ? AppTheme.brand : AppTheme.textSecondary).withValues(
        alpha: enabled ? 1 : 0.42,
      ),
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
