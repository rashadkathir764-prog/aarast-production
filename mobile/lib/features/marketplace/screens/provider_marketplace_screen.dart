import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class ProviderMarketplaceScreen extends StatefulWidget {
  const ProviderMarketplaceScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState extends State<ProviderMarketplaceScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProviderMarketplaceProvider>();
      _searchController.text = provider.search;
      provider.loadMarketplace();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Consumer<ProviderMarketplaceProvider>(
                builder: (context, provider, _) {
                  return RefreshIndicator(
                    color: AppTheme.dMaroon,
                    onRefresh: provider.loadMarketplace,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        widget.embedded ? 18 : 20,
                        16,
                        widget.embedded ? 124 : 28,
                      ),
                      children: [
                        _MarketplaceHeader(
                          embedded: widget.embedded,
                          onDashboard: () =>
                              context.push(AppRouter.providerDashboard),
                        ),
                        const SizedBox(height: 18),
                        _MarketplaceHero(
                          onTap: () => _searchFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 18),
                        _MarketplaceSearch(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          provider: provider,
                        ),
                        const SizedBox(height: 12),
                        _FilterChips(provider: provider),
                        const SizedBox(height: 18),
                        if (provider.errorMessage != null)
                          _ErrorCard(
                            message: provider.errorMessage!,
                            onRetry: provider.loadMarketplace,
                          )
                        else if (provider.isLoading &&
                            provider.providers.isEmpty)
                          const _MarketplaceSkeleton()
                        else if (provider.providers.isEmpty)
                          AarastEmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'لا توجد نتائج مطابقة',
                            message:
                                'جرّبي تغيير المدينة أو الفئة، أو امسحي الفلاتر لاستعراض الموردين المتاحين.',
                            action: OutlinedButton.icon(
                              onPressed: provider.clearFilters,
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('مسح الفلاتر'),
                            ),
                          )
                        else ...[
                          _ResultsHeader(count: provider.providers.length),
                          const SizedBox(height: 12),
                          for (final item in provider.providers) ...[
                            _ProviderCard(
                              provider: item,
                              isFavorite: provider.favoriteProviderIds.contains(
                                item.id,
                              ),
                              onFavorite: () =>
                                  provider.toggleFavorite(item.id),
                              onTap: () => context.push(
                                AppRouter.providerDetails(item.id),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceHeader extends StatelessWidget {
  const _MarketplaceHeader({required this.embedded, required this.onDashboard});

  final bool embedded;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!embedded) ...[
          _CircleButton(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              if (context.canPop()) context.pop();
            },
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموردين',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.dMaroonDeep,
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختاري قاعات، تصوير، ضيافة وخدمات موثوقة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onDashboard,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
          label: Text(embedded ? 'كمورد' : 'الدخول كمورد'),
        ),
      ],
    );
  }
}

class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.premiumCardDecoration(
        color: AppTheme.dCard,
        radius: AppTheme.radiusXl,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AarastStatusPill(
                  label: 'ميزة الموردين',
                  icon: Icons.verified_outlined,
                  color: AppTheme.dGoldDeep,
                  backgroundColor: AppTheme.dCreamBg,
                ),
                const SizedBox(height: 14),
                Text(
                  'استكشفي أفضل الموردين المناسبين لذوقك وميزانيتك',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'بحث وفلاتر وتفاصيل خدمات وطلب عرض سعر مباشرة من التطبيق.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('ابدئي البحث'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 98,
            height: 122,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSearch extends StatelessWidget {
  const _MarketplaceSearch({
    required this.controller,
    required this.focusNode,
    required this.provider,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: provider.setSearch,
          decoration: InputDecoration(
            hintText: 'ابحثي عن مورد أو خدمة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      provider.setSearch('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.provider});

  final ProviderMarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectedCity = provider.cityId;
    final selectedCategory = provider.categoryId;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MenuFilterChip(
          label: _cityLabel(selectedCity),
          icon: Icons.place_outlined,
          items: provider.cities
              .map((city) => _FilterOption(city.id, city.nameAr))
              .toList(),
          onSelected: provider.setCity,
        ),
        _MenuFilterChip(
          label: _categoryLabel(selectedCategory),
          icon: Icons.category_outlined,
          items: provider.categories
              .map((category) => _FilterOption(category.id, category.nameAr))
              .toList(),
          onSelected: provider.setCategory,
        ),
        ActionChip(
          avatar: const Icon(Icons.close_rounded, size: 18),
          label: const Text('مسح'),
          onPressed: provider.clearFilters,
        ),
      ],
    );
  }

  String _cityLabel(String? id) {
    if (id == null) return 'المدينة';
    return provider.cities
        .firstWhere(
          (city) => city.id == id,
          orElse: () => const MarketplaceCity(id: '', nameAr: 'المدينة'),
        )
        .nameAr;
  }

  String _categoryLabel(String? id) {
    if (id == null) return 'الفئة';
    return provider.categories
        .firstWhere(
          (category) => category.id == id,
          orElse: () => const ProviderCategory(id: '', nameAr: 'الفئة'),
        )
        .nameAr;
  }
}

class _FilterOption {
  const _FilterOption(this.id, this.label);

  final String id;
  final String label;
}

class _MenuFilterChip extends StatelessWidget {
  const _MenuFilterChip({
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final List<_FilterOption> items;
  final Future<void> Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('الكل')),
        for (final item in items)
          PopupMenuItem<String?>(value: item.id, child: Text(item.label)),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18, color: AppTheme.dMaroon),
        label: Text(label),
        backgroundColor: AppTheme.dCard2,
        side: const BorderSide(color: AppTheme.dLine),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'الأقرب لخطتك',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AarastStatusPill(label: '$count مورد', color: AppTheme.dMaroon),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final MarketplaceProvider provider;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    return AarastCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProviderImage(url: provider.coverUrl ?? provider.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.dInk,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ],
                ),
                if (service?.category?.nameAr != null)
                  Text(
                    service!.category!.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dMaroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 8),
                _MetaLine(
                  icon: Icons.star_rounded,
                  text:
                      '${provider.ratingAverage.toStringAsFixed(1)} (${provider.ratingCount})',
                  color: AppTheme.dGoldDeep,
                ),
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.place_outlined,
                  text: provider.city?.nameAr ?? provider.address ?? 'غير محدد',
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('عرض التفاصيل'),
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

class _ProviderImage extends StatelessWidget {
  const _ProviderImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: 108,
        height: 108,
        color: AppTheme.dCreamBg,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: AppTheme.dGoldDeep,
                size: 34,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 34,
                ),
              ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.color = AppTheme.dInkSoft,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
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

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 134,
            decoration: BoxDecoration(
              color: AppTheme.dCard2.withAlpha(180),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.dLine),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg,
      border: Border.all(color: AppTheme.danger.withAlpha(60)),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
