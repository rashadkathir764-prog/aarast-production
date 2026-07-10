import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({required this.providerId, super.key});

  final String providerId;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadProviderDetails(
        widget.providerId,
      );
    });
  }

  @override
  void didUpdateWidget(covariant ProviderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProviderMarketplaceProvider>().loadProviderDetails(
          widget.providerId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Consumer<ProviderMarketplaceProvider>(
            builder: (context, marketplace, _) {
              final quotes = marketplace.quotesForProvider(widget.providerId);
              final latest = quotes.isEmpty ? null : quotes.first;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (latest != null) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'آخر طلب لهذا المورد',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        QuoteStatusChip(
                          status: latest.lifecycleStatus,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (latest != null) ...[
                        _ContactIconButton(
                          key: const Key('provider-details-conversation'),
                          onTap: () => context.push(
                            AppRouter.quoteConversation(latest.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: AarastButton(
                          label: latest == null
                              ? 'اطلب عرض سعر'
                              : 'طلب عرض سعر جديد',
                          icon: LucideIcons.receipt,
                          expand: false,
                          onPressed: () => context.push(
                            AppRouter.providerQuote(widget.providerId),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, state, _) {
          final provider = state.providerDetails(widget.providerId);
          final services = state.servicesFor(widget.providerId);
          final packages = state.packagesFor(widget.providerId);
          final reviews = state.reviewsFor(widget.providerId);

          if (state.isLoading && provider == null) {
            return AarastSkeleton.page(heroHeight: 220, tiles: 3, cards: 2);
          }

          if (state.errorMessage != null && provider == null) {
            return _DetailsFrame(
              child: AarastEmptyState(
                icon: LucideIcons.alertCircle,
                title: 'تعذر فتح المورد',
                message: state.errorMessage!,
                action: OutlinedButton.icon(
                  onPressed: () => state.loadProviderDetails(widget.providerId),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            );
          }

          if (provider == null) {
            return const _DetailsFrame(
              child: AarastEmptyState(
                icon: LucideIcons.store,
                title: 'المورد غير متاح',
                message: 'لم نتمكن من العثور على تفاصيل هذا المورد.',
              ),
            );
          }

          final isFavorite = state.favoriteProviderIds.contains(provider.id);
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
                onBack: () {
                  if (context.canPop()) context.pop();
                },
                onShare: () => _shareProvider(context, provider),
                onFavorite: () async {
                  if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
                    context,
                  )) {
                    return;
                  }
                  await state.toggleFavorite(provider.id);
                },
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
              _pad(_AboutCard(provider: provider)),
              const SizedBox(height: 16),
              _pad(
                _ServicesSection(providerId: provider.id, services: services),
              ),
              const SizedBox(height: 16),
              _pad(_PackagesSection(packages: packages)),
              const SizedBox(height: 16),
              _pad(_ReviewsSection(reviews: reviews)),
            ],
          );
        },
      ),
    );
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

Future<void> _shareProvider(
  BuildContext context,
  MarketplaceProvider provider,
) async {
  final city = provider.city?.nameAr.trim();
  final snippet = city == null || city.isEmpty
      ? provider.businessName
      : '${provider.businessName} — $city';
  await Clipboard.setData(ClipboardData(text: snippet));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('تم نسخ بيانات المورد للمشاركة')),
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

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'المحادثات',
      child: SizedBox(
        width: 54,
        height: 54,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppTheme.burgundy,
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: AppTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          ),
          child: const Icon(LucideIcons.messageCircle, size: 22),
        ),
      ),
    );
  }
}

class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: 'رجوع',
            onPressed: () {
              if (context.canPop()) context.pop();
            },
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ),
        const SizedBox(height: 80),
        child,
      ],
    );
  }
}

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
                  icon: isFavorite ? Icons.favorite_rounded : LucideIcons.heart,
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
                const Text(
                  'الأسعار تقديرية وتتأكد عند طلب العرض',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'عرض الكل',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
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

class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.provider});

  final MarketplaceProvider provider;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final description = widget.provider.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final text = hasDescription
        ? description
        : 'لا توجد نبذة مفصلة بعد، لكن يمكنك طلب عرض سعر لمعرفة التفاصيل المناسبة لخطتك.';
    final canExpand = hasDescription && description.length > 150;

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AarastSectionHeader(
            title: 'نبذة عن المورد',
            icon: LucideIcons.info,
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: AppTheme.motionFast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: canExpand && !_expanded ? 3 : null,
              overflow: canExpand && !_expanded
                  ? TextOverflow.ellipsis
                  : TextOverflow.clip,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          if (canExpand)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(_expanded ? 'عرض أقل' : 'عرض المزيد'),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.provider.phone?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label:
                      PhoneNumberUtils.display(widget.provider.phone) ??
                      widget.provider.phone!.trim(),
                  icon: LucideIcons.phone,
                  color: AppTheme.ink,
                  backgroundColor: AppTheme.ivory,
                ),
              if (widget.provider.address?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label: widget.provider.address!.trim(),
                  icon: LucideIcons.building2,
                  color: AppTheme.gold,
                  backgroundColor: AppTheme.ivory,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.providerId, required this.services});

  final String providerId;
  final List<MarketplaceService> services;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الخدمات المتاحة',
            icon: LucideIcons.wand,
          ),
          const SizedBox(height: 12),
          if (services.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.wand,
              title: 'لا توجد خدمات منشورة',
              message: 'سيظهر هنا كتالوج خدمات المورد عند إضافته.',
            )
          else
            for (final service in services) ...[
              _ServiceTile(providerId: providerId, service: service),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.providerId, required this.service});

  final String providerId;
  final MarketplaceService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.ivory,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.sparkles, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceText(service.basePrice, service.currency),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'طلب عرض لهذه الخدمة',
            onPressed: () => context.push(
              AppRouter.providerQuote(providerId),
              extra: service.id,
            ),
            icon: const Icon(LucideIcons.chevronLeft),
          ),
        ],
      ),
    );
  }
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection({required this.packages});

  final List<ProviderPackage> packages;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الباقات المتاحة',
            icon: LucideIcons.package,
          ),
          const SizedBox(height: 12),
          if (packages.isEmpty)
            const Text(
              'لا توجد باقات منشورة حاليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            )
          else
            for (final item in packages) ...[
              _PackageTile(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.item});

  final ProviderPackage item;

  @override
  Widget build(BuildContext context) {
    final features = _packageFeatures(item.items);
    final hasPrice = item.price?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.burgundySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.gift,
                  color: AppTheme.burgundy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (item.serviceTitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.serviceTitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasPrice)
                Text(
                  _priceText(item.price, item.currency),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (item.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              item.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final feature in features) _FeatureChip(feature)],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.check, size: 13, color: AppTheme.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});

  final List<ProviderReview> reviews;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(title: 'التقييمات', icon: LucideIcons.star),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Text(
              'لا توجد تقييمات بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            )
          else
            for (final review in reviews.take(4)) ...[
              _ReviewTile(review: review),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.star, color: AppTheme.gold, size: 18),
              const SizedBox(width: 4),
              Text(
                '${review.rating}/5',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.userName ?? 'مستخدم أعرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            ],
          ),
          if (review.comment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.muted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
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

List<String> _packageFeatures(String? items) {
  if (items == null) return const [];
  return items
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(8)
      .toList();
}

String _priceText(String? value, String? currency) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return 'السعر غير منشور';
  final amount = num.tryParse(clean.replaceAll(',', ''));
  final formatted = amount == null ? clean : _formatMoney(amount);
  return '$formatted ${currencyLabelAr(currency)}';
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
