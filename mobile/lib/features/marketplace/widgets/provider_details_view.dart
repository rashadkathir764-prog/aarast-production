import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../models/marketplace_models.dart';
import 'provider_details_sections.dart';
import 'provider_photo_gallery.dart';

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
    final serviceImages = _galleryUrls(services);
    final heroImage = _heroImageUrl(provider, serviceImages);
    final galleryImages = _allPhotoUrls(heroImage, serviceImages);
    final photoCount = galleryImages.length;
    final primaryCategory = provider.primaryCategory?.nameAr.trim();
    final category = primaryCategory?.isNotEmpty == true
        ? primaryCategory
        : _providerCategory(services);

    return ListView(
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        _ProviderHero(
          providerName: provider.businessName,
          category: category,
          location: _providerLocationDetail(provider),
          imageUrl: heroImage,
          logoUrl: provider.logoUrl,
          photoCount: photoCount,
          isFavorite: isFavorite,
          onBack: onBack,
          onShare: onShare,
          onFavorite: onFavorite,
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.ivory,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius2xl),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProviderMeta(
                    category: category,
                    ratingAverage: provider.ratingAverage,
                    ratingCount: provider.ratingCount,
                    isFeatured: provider.isFeatured,
                  ),
                  if (_providerPriceRange(services) case final price?) ...[
                    const SizedBox(height: 18),
                    _PriceBand(priceLabel: price),
                  ],
                  if (galleryImages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _GallerySection(images: galleryImages),
                  ],
                  const SizedBox(height: 24),
                  ProviderDetailsSections(
                    provider: provider,
                    services: services,
                    packages: packages,
                    reviews: reviews,
                    onRequestQuote: onRequestQuote,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.providerName,
    required this.category,
    required this.location,
    required this.imageUrl,
    required this.logoUrl,
    required this.photoCount,
    required this.isFavorite,
    required this.onBack,
    required this.onShare,
    required this.onFavorite,
  });

  final String providerName;
  final String? category;
  final String? location;
  final String? imageUrl;
  final String? logoUrl;
  final int photoCount;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final hasPublishedMedia =
        imageUrl?.trim().isNotEmpty == true ||
        logoUrl?.trim().isNotEmpty == true;
    return SizedBox(
      key: const Key('provider-details-hero'),
      height: hasPublishedMedia ? 342 : 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroImage(
            url: imageUrl,
            logoUrl: logoUrl,
            providerName: providerName,
          ),
          const _HeroReadabilityGradient(),
          PositionedDirectional(
            top: 14,
            start: 14,
            end: 14,
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
                  icon: isFavorite ? LucideIcons.heart : LucideIcons.heart,
                  iconColor: isFavorite ? AppTheme.burgundy : null,
                  onTap: onFavorite,
                  tooltip: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المورد',
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 20,
            end: 20,
            bottom: 45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null) _HeroEyebrow(label: category!),
                if (category != null) const SizedBox(height: 9),
                Text(
                  providerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontFamily: AppTheme.displayFontFamily,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                    shadows: [
                      Shadow(
                        color: AppTheme.ink.withValues(alpha: 0.54),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                _HeroDetailsLine(location: location, photoCount: photoCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroReadabilityGradient extends StatelessWidget {
  const _HeroReadabilityGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.38, 1],
          colors: [
            AppTheme.ink.withValues(alpha: 0.36),
            Colors.transparent,
            AppTheme.ink.withValues(alpha: 0.84),
          ],
        ),
      ),
    );
  }
}

class _HeroEyebrow extends StatelessWidget {
  const _HeroEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 1.5, color: AppTheme.goldSoft),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.goldSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroDetailsLine extends StatelessWidget {
  const _HeroDetailsLine({required this.location, required this.photoCount});

  final String? location;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      ?location,
      if (photoCount > 0) 'معرض الصور $photoCount' else 'لا توجد صور منشورة',
    ];
    return Text(
      details.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.84),
        fontWeight: FontWeight.w700,
        height: 1.35,
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
    final button = Material(
      color: AppTheme.ink.withValues(alpha: 0.44),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.url,
    required this.logoUrl,
    required this.providerName,
  });

  final String? url;
  final String? logoUrl;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final fallback = _ProviderMediaFallback(
      logoUrl: logoUrl,
      providerName: providerName,
    );
    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      semanticLabel: 'صورة $providerName',
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return fallback;
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _ProviderMediaFallback extends StatelessWidget {
  const _ProviderMediaFallback({
    required this.logoUrl,
    required this.providerName,
  });

  final String? logoUrl;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final cleanLogo = logoUrl?.trim();
    return Semantics(
      container: true,
      label: 'لا توجد صورة منشورة للمورد $providerName',
      child: DecoratedBox(
        key: const Key('provider-media-fallback'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppTheme.burgundyDark, AppTheme.ink],
          ),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 92,
              start: -24,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 118,
              start: 0,
              end: 0,
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: cleanLogo == null || cleanLogo.isEmpty
                        ? const Icon(
                            LucideIcons.store,
                            color: AppTheme.goldSoft,
                            size: 36,
                          )
                        : Image.network(
                            cleanLogo,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  LucideIcons.store,
                                  color: AppTheme.goldSoft,
                                  size: 36,
                                ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'لا توجد صورة منشورة',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderMeta extends StatelessWidget {
  const _ProviderMeta({
    required this.category,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isFeatured,
  });

  final String? category;
  final double ratingAverage;
  final int ratingCount;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (isFeatured)
            const _MetaBadge(
              label: 'مرجع تخطيطي',
              icon: LucideIcons.badgeCheck,
              foreground: AppTheme.success,
              background: AppTheme.successSoft,
            ),
          if (ratingCount > 0)
            _MetaBadge(
              label:
                  '${ratingAverage.toStringAsFixed(1)} · $ratingCount تقييمًا',
              icon: LucideIcons.star,
              foreground: AppTheme.goldDeep,
              background: AppTheme.goldLight,
            ),
          if (category != null)
            _MetaBadge(
              label: category!,
              foreground: AppTheme.burgundy,
              background: AppTheme.burgundySoft,
            ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBand extends StatelessWidget {
  const _PriceBand({required this.priceLabel});

  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نطاق سعري تقديري · يتأكد عند طلب العرض',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  priceLabel,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.goldLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.goldSoft),
            ),
            child: const Icon(
              LucideIcons.walletCards,
              color: AppTheme.goldDeep,
              size: 21,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'معرض الصور',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (images.length > 1)
                TextButton(
                  onPressed: () => showProviderPhotoGallery(
                    context,
                    images: images,
                    initialIndex: 0,
                  ),
                  child: const Text('عرض الكل'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _GalleryThumb(
                    url: images.first,
                    onTap: () => showProviderPhotoGallery(
                      context,
                      images: images,
                      initialIndex: 0,
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _GalleryThumb(
                            url: images[1],
                            onTap: () => showProviderPhotoGallery(
                              context,
                              images: images,
                              initialIndex: 1,
                            ),
                          ),
                        ),
                        if (images.length > 2) ...[
                          const SizedBox(height: 9),
                          Expanded(
                            child: _GalleryThumb(
                              url: images[2],
                              overlayCount: images.length - 3,
                              onTap: () => showProviderPhotoGallery(
                                context,
                                images: images,
                                initialIndex: 2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.url,
    required this.onTap,
    this.overlayCount = 0,
  });

  final String url;
  final VoidCallback onTap;
  final int overlayCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.pearl),
                child: Center(
                  child: Icon(LucideIcons.image, color: AppTheme.gold),
                ),
              ),
            ),
            if (overlayCount > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.58),
                ),
                child: Center(
                  child: Text(
                    '+$overlayCount',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
  return gallery.isNotEmpty ? gallery.first : null;
}

List<String> _allPhotoUrls(String? hero, List<String> serviceImages) {
  return <String>{
    if (hero != null && hero.isNotEmpty) hero,
    ...serviceImages,
  }.toList();
}

String? _providerCategory(List<MarketplaceService> services) {
  for (final service in services) {
    final category = service.category?.nameAr.trim();
    if (category != null && category.isNotEmpty) return category;
  }
  return null;
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
  return '${_formatMoney(min)} – ${_formatMoney(max)} $unit';
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
