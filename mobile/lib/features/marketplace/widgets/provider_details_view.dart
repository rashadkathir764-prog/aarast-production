import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_loading_state.dart';
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
        DecoratedBox(
          decoration: const BoxDecoration(color: AppTheme.canvas),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (galleryImages.isNotEmpty) ...[
                const SizedBox(height: 18),
                _GallerySection(images: galleryImages),
              ],
              const SizedBox(height: 18),
              _ProviderMeta(
                category: category,
                ratingAverage: provider.ratingAverage,
                ratingCount: provider.ratingCount,
                isFeatured: provider.isFeatured,
              ),
              if (_providerPriceRange(services) case final price?) ...[
                const SizedBox(height: 14),
                _PriceBand(priceLabel: price),
              ],
              const SizedBox(height: 22),
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
    return _ProviderTextHero(
      providerName: providerName,
      category: category,
      location: location,
      imageUrl: imageUrl,
      logoUrl: logoUrl,
      photoCount: photoCount,
      isFavorite: isFavorite,
      onBack: onBack,
      onShare: onShare,
      onFavorite: onFavorite,
    );
  }
}

class _ProviderTextHero extends StatelessWidget {
  const _ProviderTextHero({
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
    final cleanImage = imageUrl?.trim();
    final cleanLogo = logoUrl?.trim();
    final displayUrl = cleanImage?.isNotEmpty == true
        ? cleanImage
        : cleanLogo?.isNotEmpty == true
        ? cleanLogo
        : null;
    final details = <String>[
      ?location,
      if (photoCount > 0) 'معرض الصور $photoCount' else 'لا توجد صور منشورة',
    ];
    return Container(
      key: const Key('provider-details-hero'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HeroLightButton(
                icon: LucideIcons.chevronRight,
                onTap: onBack,
                tooltip: 'رجوع',
              ),
              const Spacer(),
              _HeroLightButton(
                icon: LucideIcons.share2,
                onTap: onShare,
                tooltip: 'مشاركة',
              ),
              const SizedBox(width: 8),
              _HeroLightButton(
                icon: LucideIcons.heart,
                iconColor: isFavorite ? AppTheme.brand : null,
                backgroundColor: isFavorite
                    ? AppTheme.brandMuted
                    : AppTheme.surfaceMuted,
                onTap: onFavorite,
                tooltip: isFavorite ? 'إزالة من المحفوظات' : 'حفظ المورد',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                key: displayUrl == null
                    ? const Key('provider-media-fallback')
                    : null,
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
                  border: Border.all(color: AppTheme.border),
                ),
                child: displayUrl == null
                    ? const Icon(
                        LucideIcons.store,
                        color: AppTheme.brand,
                        size: 26,
                      )
                    : Image.network(
                        displayUrl,
                        fit: cleanImage?.isNotEmpty == true
                            ? BoxFit.cover
                            : BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              LucideIcons.store,
                              color: AppTheme.brand,
                              size: 26,
                            ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null) ...[
                      Text(
                        category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppTheme.brand,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      providerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontFamily: AppTheme.displayFontFamily,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      details.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroLightButton extends StatelessWidget {
  const _HeroLightButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor,
    this.backgroundColor = AppTheme.surfaceMuted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.textPrimary,
              size: 19,
            ),
          ),
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
              foreground: AppTheme.brand,
              background: AppTheme.brandMuted,
            ),
          if (category != null)
            _MetaBadge(
              label: category!,
              foreground: AppTheme.brand,
              background: AppTheme.brandMuted,
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
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  priceLabel,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.brand,
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
              color: AppTheme.brandMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.brandMuted),
            ),
            child: const Icon(
              LucideIcons.walletCards,
              color: AppTheme.brand,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '${images.length} صور',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
          Container(
            key: const Key('provider-media-stage'),
            height: 156,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
              border: Border.all(color: AppTheme.border),
            ),
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
                  const SizedBox(width: 4),
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
                          const SizedBox(height: 4),
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

class _GalleryThumb extends StatefulWidget {
  const _GalleryThumb({
    required this.url,
    required this.onTap,
    this.overlayCount = 0,
  });

  final String url;
  final VoidCallback onTap;
  final int overlayCount;

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceRaised,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _GalleryLoadingState(),
              errorBuilder: (context, error, stackTrace) {
                if (!_failed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                }
                return _GalleryImageFallback(
                  remainingCount: widget.overlayCount,
                );
              },
            ),
            if (!_failed && widget.overlayCount > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.textPrimary.withValues(alpha: 0.58),
                ),
                child: Center(
                  child: Text(
                    '+${widget.overlayCount}',
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

class _GalleryLoadingState extends StatelessWidget {
  const _GalleryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppTheme.surfaceMuted),
      child: Center(child: AarastInlineSpinner(dimension: 18)),
    );
  }
}

class _GalleryImageFallback extends StatelessWidget {
  const _GalleryImageFallback({required this.remainingCount});

  final int remainingCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 100 || constraints.maxWidth < 110;
        if (compact) {
          return DecoratedBox(
            decoration: const BoxDecoration(color: AppTheme.surfaceMuted),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusControl,
                      ),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(
                      LucideIcons.imageOff,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (remainingCount > 0)
                  Align(
                    alignment: AlignmentDirectional.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '$remainingCount أخرى',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.brand,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        return DecoratedBox(
          decoration: const BoxDecoration(color: AppTheme.surfaceMuted),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(
                    LucideIcons.imageOff,
                    size: 21,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تعذّر تحميل الصورة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (remainingCount > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '+$remainingCount صور أخرى',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
