import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';

/// حقيقة صغيرة تُعرض تحت اسم المورد (موقع، سعر، تطابق ميزانية).
class VendorFact {
  const VendorFact({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
}

/// بطاقة المورد الملكية — مونوغرام ذهبي أنيق، شارة "مميز" ذهبية،
/// تقييم يظهر فقط عند وجوده، وقلب بنبضة عند الحفظ.
class PremiumVendorCard extends StatelessWidget {
  const PremiumVendorCard({
    required this.businessName,
    required this.isFeatured,
    required this.ratingAverage,
    required this.ratingCount,
    required this.facts,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetails,
    required this.onRequestQuote,
    this.categoryLabel,
    this.serviceTitle,
    this.logoUrl,
    this.quoteButtonKey,
    super.key,
  });

  final String businessName;
  final bool isFeatured;
  final double ratingAverage;
  final int ratingCount;
  final List<VendorFact> facts;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onDetails;
  final VoidCallback onRequestQuote;
  final String? categoryLabel;
  final String? serviceTitle;
  final String? logoUrl;
  final Key? quoteButtonKey;

  @override
  Widget build(BuildContext context) {
    final hasRating = ratingCount > 0;

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VendorMonogram(
                    name: businessName,
                    logoUrl: logoUrl,
                    isFeatured: isFeatured,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                businessName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AarastDesignTokens.ink,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            _FavoriteHeart(
                              isFavorite: isFavorite,
                              onTap: onFavorite,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (categoryLabel != null &&
                                categoryLabel!.trim().isNotEmpty)
                              Flexible(
                                child: Text(
                                  categoryLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AarastDesignTokens.burgundy,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (isFeatured) ...[
                              if (categoryLabel != null &&
                                  categoryLabel!.trim().isNotEmpty)
                                const SizedBox(width: 8),
                              const _FeaturedBadge(),
                            ],
                            if (hasRating) ...[
                              const SizedBox(width: 8),
                              _RatingChip(
                                average: ratingAverage,
                                count: ratingCount,
                              ),
                            ],
                          ],
                        ),
                        if (serviceTitle != null &&
                            serviceTitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            serviceTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AarastDesignTokens.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final fact in facts) _FactPill(fact: fact),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AarastDesignTokens.burgundy,
                        side: const BorderSide(
                            color: AarastDesignTokens.border),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AarastDesignTokens.radiusMd),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      icon: const Icon(LucideIcons.info, size: 16),
                      label: const Text('التفاصيل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: quoteButtonKey,
                      onPressed: onRequestQuote,
                      style: FilledButton.styleFrom(
                        backgroundColor: AarastDesignTokens.burgundy,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AarastDesignTokens.radiusMd),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      icon: const Icon(LucideIcons.fileText, size: 16),
                      label: const Text('طلب عرض'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorMonogram extends StatelessWidget {
  const _VendorMonogram({
    required this.name,
    required this.isFeatured,
    this.logoUrl,
  });

  final String name;
  final bool isFeatured;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final initial = name.trim().isNotEmpty ? name.trim()[0] : 'م';

    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AarastDesignTokens.goldSoft,
            AarastDesignTokens.goldMonogram,
          ],
        ),
        border: Border.all(
          color: AarastDesignTokens.gold.withValues(alpha: 0.35),
        ),
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AarastDesignTokens.goldDeep,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AarastDesignTokens.goldDeep,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
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
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sparkles, size: 11, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'مميز',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
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
        const Icon(LucideIcons.star,
            size: 13, color: AarastDesignTokens.gold),
        const SizedBox(width: 3),
        Text(
          '${average.toStringAsFixed(1)} ($count)',
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: AarastDesignTokens.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({required this.fact});

  final VendorFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fact.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fact.icon, size: 12, color: fact.color),
          const SizedBox(width: 4),
          Text(
            fact.text,
            style: TextStyle(
              color: fact.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);

    Widget heart = Icon(
      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: isFavorite
          ? AarastDesignTokens.burgundy
          : AarastDesignTokens.muted,
      size: 22,
    );

    // نبضة صغيرة لحظة الحفظ.
    if (isFavorite && !reduceMotion) {
      heart = heart
          .animate()
          .scale(
            begin: const Offset(0.6, 0.6),
            end: const Offset(1, 1),
            duration: 320.ms,
            curve: Curves.elasticOut,
          );
    }

    return Semantics(
      button: true,
      label: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المورد',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(width: 40, height: 40, child: Center(child: heart)),
      ),
    );
  }
}
