import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

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
        context.read<ProviderMarketplaceProvider>().loadProviderDetails(
          widget.providerId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.dCard2,
              border: Border(top: BorderSide(color: AppTheme.dLine)),
            ),
            child: FilledButton.icon(
              onPressed: () =>
                  context.push(AppRouter.providerQuote(widget.providerId)),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('طلب عرض سعر'),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Consumer<ProviderMarketplaceProvider>(
            builder: (context, state, _) {
              final provider = state.providerDetails(widget.providerId);
              final services = state.servicesFor(widget.providerId);
              final packages = state.packagesFor(widget.providerId);
              final reviews = state.reviewsFor(widget.providerId);

              if (state.isLoading && provider == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.errorMessage != null && provider == null) {
                return _DetailsFrame(
                  child: AarastEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'تعذر فتح المورد',
                    message: state.errorMessage!,
                    action: OutlinedButton.icon(
                      onPressed: () =>
                          state.loadProviderDetails(widget.providerId),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                );
              }

              if (provider == null) {
                return const _DetailsFrame(
                  child: AarastEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'المورد غير متاح',
                    message: 'لم نتمكن من العثور على تفاصيل هذا المورد.',
                  ),
                );
              }

              final isFavorite = state.favoriteProviderIds.contains(
                provider.id,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _DetailsTopBar(
                    isFavorite: isFavorite,
                    onBack: () {
                      if (context.canPop()) context.pop();
                    },
                    onFavorite: () => state.toggleFavorite(provider.id),
                  ),
                  const SizedBox(height: 12),
                  _ProviderHero(provider: provider),
                  const SizedBox(height: 18),
                  _AboutCard(provider: provider),
                  const SizedBox(height: 18),
                  _ServicesSection(providerId: provider.id, services: services),
                  const SizedBox(height: 18),
                  _PackagesSection(packages: packages),
                  const SizedBox(height: 18),
                  _ReviewsSection(reviews: reviews),
                ],
              );
            },
          ),
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
            onPressed: () {
              if (context.canPop()) context.pop();
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 80),
        child,
      ],
    );
  }
}

class _DetailsTopBar extends StatelessWidget {
  const _DetailsTopBar({
    required this.isFavorite,
    required this.onBack,
    required this.onFavorite,
  });

  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(icon: Icons.chevron_right_rounded, onTap: onBack),
        const Spacer(),
        _RoundButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onTap: onFavorite,
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.ios_share_rounded,
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('مشاركة المورد ستتوفر بعد ربط روابط المشاركة.'),
                ),
              );
          },
        ),
      ],
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({required this.provider});

  final MarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroImage(url: provider.coverUrl ?? provider.logoUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.businessName,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AarastStatusPill(
                        label:
                            '${provider.ratingAverage.toStringAsFixed(1)} (${provider.ratingCount})',
                        icon: Icons.star_rounded,
                        color: AppTheme.dGoldDeep,
                        backgroundColor: AppTheme.dCreamBg,
                      ),
                      if (provider.city?.nameAr != null)
                        AarastStatusPill(
                          label: provider.city!.nameAr,
                          icon: Icons.place_outlined,
                          color: AppTheme.dMaroon,
                          backgroundColor: AppTheme.dPinkBg,
                        ),
                      if (provider.isFeatured)
                        const AarastStatusPill(
                          label: 'مميز',
                          icon: Icons.verified_rounded,
                          color: AppTheme.dGreen,
                          backgroundColor: AppTheme.dGreenBg,
                        ),
                    ],
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return Container(
      height: 210,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.dCreamBg, AppTheme.dPinkBg],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: imageUrl == null || imageUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.storefront_rounded,
                color: AppTheme.dGoldDeep,
                size: 64,
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 64,
                ),
              ),
            ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.provider});

  final MarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AarastSectionHeader(
            title: 'نبذة عن المورد',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            provider.description?.trim().isNotEmpty == true
                ? provider.description!.trim()
                : 'لا توجد نبذة مفصلة بعد، لكن يمكنك طلب عرض سعر لمعرفة التفاصيل المناسبة لخطتك.',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (provider.phone?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label: provider.phone!.trim(),
                  icon: Icons.phone_outlined,
                  color: AppTheme.dBlue,
                  backgroundColor: AppTheme.dBlueBg,
                ),
              if (provider.address?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label: provider.address!.trim(),
                  icon: Icons.location_city_outlined,
                  color: AppTheme.dGoldDeep,
                  backgroundColor: AppTheme.dCreamBg,
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
            icon: Icons.design_services_outlined,
          ),
          const SizedBox(height: 12),
          if (services.isEmpty)
            const AarastEmptyState(
              icon: Icons.design_services_outlined,
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
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.dCreamBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.dGoldDeep,
            ),
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
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceText(service.basePrice, service.currency),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dMaroon,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(
              AppRouter.providerQuote(providerId),
              extra: service.id,
            ),
            icon: const Icon(Icons.chevron_left_rounded),
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
            title: 'الباقات',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          if (packages.isEmpty)
            const Text(
              'لا توجد باقات منشورة حاليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.dMuted),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: AppTheme.dMaroon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.description?.trim().isNotEmpty == true)
                  Text(
                    item.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.dInkSoft),
                  ),
              ],
            ),
          ),
          Text(
            _priceText(item.price, item.currency),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w900,
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
          const AarastSectionHeader(
            title: 'التقييمات',
            icon: Icons.star_border_rounded,
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Text(
              'لا توجد تقييمات بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.dMuted),
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
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppTheme.dGoldDeep,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '${review.rating}/5',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.userName ?? 'مستخدم اعّرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.dInkSoft),
                ),
              ),
            ],
          ),
          if (review.comment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.dInkSoft, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dLine),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Icon(icon, color: AppTheme.dMaroon),
      ),
    );
  }
}

String _priceText(String? value, String? currency) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return 'حسب الطلب';
  return '$clean ${currency ?? 'ر.س'}';
}
