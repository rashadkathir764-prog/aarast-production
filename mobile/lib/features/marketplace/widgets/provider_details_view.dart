import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import 'provider_details_sections.dart';

class ProviderDetailsView extends StatelessWidget {
  const ProviderDetailsView({
    required this.provider,
    required this.services,
    required this.packages,
    required this.reviews,
    required this.isFavorite,
    required this.onBack,
    required this.onShare,
    required this.onFavorite,
    required this.onRequestQuote,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final List<ProviderReview> reviews;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final galleryImages = _galleryUrls(services);
    final heroImage = _heroImageUrl(provider, galleryImages);
    final photoCount = _photoCount(heroImage, galleryImages);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _ProviderHero(
          imageUrl: heroImage,
          photoCount: photoCount,
          isFavorite: isFavorite,
          onBack: onBack,
          onShare: onShare,
          onFavorite: onFavorite,
        ),
        const SizedBox(height: 16),
        _pad(
          _HeadlineCard(
            provider: provider,
            priceLabel: _providerPriceRange(services),
          ),
        ),
        if (galleryImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _pad(_GallerySection(images: galleryImages)),
        ],
        const SizedBox(height: 16),
        ProviderDetailsSections(
          provider: provider,
          services: services,
          packages: packages,
          reviews: reviews,
          onRequestQuote: onRequestQuote,
        ),
      ],
    );
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.imageUrl,
    required this.photoCount,
    required this.isFavorite,
    required this.onBack,
    required this.onShare,
    required this.onFavorite,
  });

  final String? imageUrl;
  final int photoCount;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 292,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusXl),
            ),
            child: _HeroImage(url: imageUrl),
          ),
          // تدرّج غامق أسفل الصورة ليبرز عدّاد الصور فوق أي خلفية.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 96,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppTheme.radiusXl),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppTheme.ink.withValues(alpha: 0.34),
                      AppTheme.ink.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 12,
            child: Row(
              children: [
                _HeroOverlayButton(
                  icon: LucideIcons.chevronRight,
                  onTap: onBack,
                  tooltip: 'رجوع',
                ),
                const Spacer(),
                _HeroOverlayButton(
                  icon: LucideIcons.share2,
                  onTap: onShare,
                  tooltip: 'مشاركة',
                ),
                const SizedBox(width: 10),
                _HeroOverlayButton(
                  icon: LucideIcons.heart,
                  iconColor: isFavorite ? AppTheme.burgundy : null,
                  onTap: onFavorite,
                  tooltip: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المورد',
                ),
              ],
            ),
          ),
          if (photoCount > 1)
            PositionedDirectional(
              bottom: 14,
              end: 14,
              child: _PhotoCounter(count: photoCount),
            ),
        ],
      ),
    );
  }
}

class _HeroOverlayButton extends StatelessWidget {
  const _HeroOverlayButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.burgundy, size: 20),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _PhotoCounter extends StatelessWidget {
  const _PhotoCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.image, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            '1 / $count',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.ivory, AppTheme.burgundySoft],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: imageUrl == null || imageUrl.isEmpty
          ? const Center(
              child: Icon(LucideIcons.store, color: AppTheme.gold, size: 64),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(LucideIcons.store, color: AppTheme.gold, size: 64),
              ),
            ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.provider, required this.priceLabel});

  final MarketplaceProvider provider;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final category = provider.services.isEmpty
        ? null
        : provider.services.first.category?.nameAr.trim();
    final location = _providerLocationDetail(provider);

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.businessName,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category != null && category.isNotEmpty)
                AarastStatusPill(
                  label: category,
                  icon: LucideIcons.shapes,
                  color: AppTheme.burgundy,
                  backgroundColor: AppTheme.burgundySoft,
                ),
              if (provider.ratingCount > 0)
                AarastStatusPill(
                  label:
                      '${provider.ratingAverage.toStringAsFixed(1)} (${provider.ratingCount})',
                  icon: LucideIcons.star,
                  color: AppTheme.gold,
                  backgroundColor: AppTheme.ivory,
                ),
              if (provider.isFeatured)
                AarastStatusPill(
                  label: 'مرجع تخطيطي',
                  icon: LucideIcons.badgeCheck,
                  color: AppTheme.success,
                  backgroundColor: AppTheme.successSoft,
                ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 16, color: AppTheme.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (priceLabel != null) ...[
            const SizedBox(height: 14),
            _PriceBlock(priceLabel: priceLabel!),
          ],
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.priceLabel});

  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.wallet, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priceLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'الأسعار تقديرية وتتأكد عند طلب العرض',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.muted,
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

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final visible = images.take(4).toList();
    final extra = images.length - visible.length;

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'معرض الصور',
            icon: LucideIcons.image,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _GalleryThumb(
                    url: visible[i],
                    overlayCount: (i == visible.length - 1 && extra > 0)
                        ? extra
                        : 0,
                    onTap: () => _openPhoto(context, visible[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.url,
    required this.overlayCount,
    required this.onTap,
  });

  final String url;
  final int overlayCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Center(
                  child: Icon(LucideIcons.image, color: AppTheme.gold),
                ),
              ),
              if (overlayCount > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.55),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+$overlayCount',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          'عرض الكل',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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

void _openPhoto(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: AppTheme.ink.withValues(alpha: 0.92),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(LucideIcons.image, color: AppTheme.gold),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Material(
              color: AppTheme.surface,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'إغلاق الصورة',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(LucideIcons.x, color: AppTheme.burgundy),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

List<String> _galleryUrls(List<MarketplaceService> services) {
  final urls = <String>[];
  for (final service in services) {
    for (final image in service.images) {
      final url = image.imageUrl.trim();
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
  }
  return urls;
}

String? _heroImageUrl(MarketplaceProvider provider, List<String> gallery) {
  final cover = provider.coverUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  final logo = provider.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
  return gallery.isNotEmpty ? gallery.first : null;
}

int _photoCount(String? hero, List<String> gallery) {
  final set = <String>{if (hero != null && hero.isNotEmpty) hero, ...gallery};
  return set.length;
}

String? _providerLocationDetail(MarketplaceProvider provider) {
  final city = provider.city?.nameAr.trim();
  final address = provider.address?.trim();
  final hasCity = city != null && city.isNotEmpty;
  final hasAddress = address != null && address.isNotEmpty;
  if (hasCity && hasAddress) return '$city – $address';
  if (hasCity) return city;
  if (hasAddress) return address;
  return null;
}

String? _providerPriceRange(List<MarketplaceService> services) {
  double? min;
  double? max;
  for (final service in services) {
    final raw = service.basePrice?.replaceAll(',', '').trim();
    final price = raw == null || raw.isEmpty ? null : double.tryParse(raw);
    if (price == null) continue;
    min = min == null ? price : (price < min ? price : min);
    max = max == null ? price : (price > max ? price : max);
  }
  if (min == null || max == null) return null;
  final unit = currencyLabelAr(_firstPricedCurrency(services));
  if (min == max) return '${_formatMoney(min)} $unit';
  return '${_formatMoney(min)} - ${_formatMoney(max)} $unit';
}

String? _firstPricedCurrency(List<MarketplaceService> services) {
  for (final service in services) {
    final raw = service.basePrice?.replaceAll(',', '').trim();
    if (raw != null && raw.isNotEmpty && double.tryParse(raw) != null) {
      return service.currency;
    }
  }
  return null;
}

String _formatMoney(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
}
