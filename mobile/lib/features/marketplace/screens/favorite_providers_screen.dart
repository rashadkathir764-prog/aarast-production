import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/premium/premium_vendor_card.dart';

class FavoriteProvidersScreen extends StatefulWidget {
  const FavoriteProvidersScreen({super.key});

  @override
  State<FavoriteProvidersScreen> createState() =>
      _FavoriteProvidersScreenState();
}

class _FavoriteProvidersScreenState extends State<FavoriteProvidersScreen> {
  bool _isCheckingAccount = true;
  bool _showLoginGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final hasAccount = await AuthActionGuard.hasAccount(context);
    if (!mounted) return;
    setState(() {
      _isCheckingAccount = false;
      _showLoginGate = !hasAccount;
    });
    if (!hasAccount) return;
    await context.read<ProviderMarketplaceProvider>().loadFavoriteProviders();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final favorites = marketplace.favoriteProviders
        .map((item) => item.provider)
        .whereType<MarketplaceProvider>()
        .toList(growable: false);

    return AarastPageScaffold(
      title: 'الموردون المحفوظون',
      subtitle: 'كل مورد حفظته للمقارنة أو طلب عرض لاحقاً.',
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.providerMarketplace);
            }
          },
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: 'رجوع',
        ),
      ],
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (_isCheckingAccount)
              AarastSkeleton.list(
                rows: 4,
                rowHeight: 120,
                withHeader: false,
                inline: true,
              )
            else if (_showLoginGate)
              AarastEmptyState(
                icon: LucideIcons.heart,
                title: 'سجل الدخول لفتح المفضلة',
                message:
                    'حفظ الموردين مرتبط بحسابك حتى تجدهم مرة أخرى من أي جهاز.',
                action: FilledButton.icon(
                  onPressed: () => context.go(AppRouter.login),
                  icon: const Icon(LucideIcons.logIn),
                  label: const Text('تسجيل الدخول'),
                ),
              )
            else if (marketplace.errorMessage != null)
              AarastErrorState(
                title: 'تعذر تحميل المفضلة',
                message: marketplace.errorMessage!,
                onRetry: _load,
              )
            else if (marketplace.isLoading && favorites.isEmpty)
              AarastSkeleton.list(
                rows: 4,
                rowHeight: 120,
                withHeader: false,
                inline: true,
              )
            else if (favorites.isEmpty)
              AarastEmptyState(
                icon: LucideIcons.heart,
                title: 'لا توجد مفضلة بعد',
                message:
                    'اضغط على القلب بجانب أي مورد ليظهر هنا للمقارنة والمتابعة.',
                action: OutlinedButton.icon(
                  onPressed: () => context.go(AppRouter.providerMarketplace),
                  icon: const Icon(LucideIcons.store),
                  label: const Text('تصفح الموردين'),
                ),
              )
            else ...[
              _FavoriteProvidersHero(count: favorites.length),
              const SizedBox(height: 10),
              const _FavoriteCompareNote(),
              const SizedBox(height: 12),
              for (final provider in favorites) ...[
                _FavoriteVendorCard(
                  provider: provider,
                  isSubmitting: marketplace.isSubmitting,
                  onOpen: () =>
                      context.push(AppRouter.providerDetails(provider.id)),
                  onRemove: () async {
                    await marketplace.toggleFavorite(provider.id);
                    if (!context.mounted) return;
                    AarastToast.showSuccess(
                      context,
                      'تمت إزالة المورد من المفضلة',
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FavoriteCompareNote extends StatelessWidget {
  const _FavoriteCompareNote();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(LucideIcons.arrowLeftRight, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'استخدم المفضلة للمقارنة السريعة، ثم اطلب عرضاً من المورد المناسب. لا ينشئ الحفظ أو إرسال الطلب حجزاً؛ وعند قبول العرض تُنشأ التكلفة تلقائياً.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteProvidersHero extends StatelessWidget {
  const _FavoriteProvidersHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.ivory,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.burgundySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.heart, color: AppTheme.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count مورد محفوظ للمقارنة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRouter.providerMarketplace),
            icon: const Icon(LucideIcons.plus),
            label: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

/// نفس بطاقة المورد الأنيقة المستخدمة في تبويب الموردين — لتبقى كل الشاشات
/// متناسقة. القلب هنا يعني الإزالة من المفضلة، والزر يفتح التفاصيل.
class _FavoriteVendorCard extends StatelessWidget {
  const _FavoriteVendorCard({
    required this.provider,
    required this.isSubmitting,
    required this.onOpen,
    required this.onRemove,
  });

  final MarketplaceProvider provider;
  final bool isSubmitting;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final category = service?.category?.nameAr.trim();
    final city = provider.city?.nameAr.trim();

    return PremiumVendorCard(
      businessName: provider.businessName,
      isFeatured: provider.isFeatured,
      ratingAverage: provider.ratingAverage,
      ratingCount: provider.ratingCount,
      categoryLabel: category,
      locationLabel: city,
      priceLabel: _favoritePriceRangeLabel(provider.services),
      imageUrl: _favoriteImageUrl(provider),
      isFavorite: true,
      onFavorite: isSubmitting ? null : () => onRemove(),
      onDetails: onOpen,
      favoriteButtonKey: Key('favorite-provider-remove-${provider.id}'),
    );
  }
}

String? _favoriteImageUrl(MarketplaceProvider provider) {
  final cover = provider.coverUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  final logo = provider.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
  for (final service in provider.services) {
    for (final image in service.images) {
      final url = image.imageUrl.trim();
      if (url.isNotEmpty) return url;
    }
  }
  return null;
}

String? _favoritePriceRangeLabel(List<MarketplaceService> services) {
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
