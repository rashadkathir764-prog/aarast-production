import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class FavoriteProvidersScreen extends StatefulWidget {
  const FavoriteProvidersScreen({super.key});

  @override
  State<FavoriteProvidersScreen> createState() =>
      _FavoriteProvidersScreenState();
}

class _FavoriteProvidersScreenState extends State<FavoriteProvidersScreen> {
  bool _isCheckingAccount = true;
  bool _showLoginGate = false;
  final Set<String> _selectedProviderIds = <String>{};

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
    final selected = _selectedProviders(favorites);

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
        color: AppTheme.brand,
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
              _ProviderComparePicker(
                providers: favorites,
                selectedIds: selected.map((item) => item.id).toSet(),
                onToggle: _toggleComparedProvider,
              ),
              const SizedBox(height: 12),
              _ProviderComparisonSurface(
                providers: selected,
                isSubmitting: marketplace.isSubmitting,
                onOpen: (provider) =>
                    context.push(AppRouter.providerDetails(provider.id)),
                onRemove: (provider) => _removeFavorite(marketplace, provider),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<MarketplaceProvider> _selectedProviders(
    List<MarketplaceProvider> favorites,
  ) {
    final available = favorites.map((item) => item.id).toSet();
    _selectedProviderIds.removeWhere((id) => !available.contains(id));
    if (_selectedProviderIds.isEmpty) {
      _selectedProviderIds.addAll(
        favorites.take(favorites.length > 1 ? 2 : 1).map((item) => item.id),
      );
    }
    return favorites
        .where((provider) => _selectedProviderIds.contains(provider.id))
        .take(3)
        .toList(growable: false);
  }

  void _toggleComparedProvider(MarketplaceProvider provider) {
    final selected = _selectedProviderIds.contains(provider.id);
    if (selected && _selectedProviderIds.length <= 2) {
      AarastToast.showInfo(context, 'اختر موردين على الأقل للمقارنة.');
      return;
    }
    if (!selected && _selectedProviderIds.length >= 3) {
      AarastToast.showInfo(context, 'يمكن مقارنة ثلاثة موردين كحد أقصى.');
      return;
    }
    setState(() {
      selected
          ? _selectedProviderIds.remove(provider.id)
          : _selectedProviderIds.add(provider.id);
    });
  }

  Future<void> _removeFavorite(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) async {
    await marketplace.toggleFavorite(provider.id);
    if (!mounted) return;
    if (marketplace.favoriteProviderIds.contains(provider.id)) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر إزالة المورد من المفضلة.',
      );
      return;
    }
    setState(() => _selectedProviderIds.remove(provider.id));
    AarastToast.showSuccess(
      context,
      'تمت إزالة المورد من المفضلة',
      action: SnackBarAction(
        label: 'تراجع',
        onPressed: () => unawaited(_restoreFavorite(marketplace, provider)),
      ),
    );
  }

  Future<void> _restoreFavorite(
    ProviderMarketplaceProvider marketplace,
    MarketplaceProvider provider,
  ) async {
    if (marketplace.favoriteProviderIds.contains(provider.id)) return;
    await marketplace.toggleFavorite(provider.id);
    if (!mounted) return;
    if (!marketplace.favoriteProviderIds.contains(provider.id)) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر التراجع الآن.',
      );
      return;
    }
    AarastToast.showInfo(context, 'أُعيد المورد إلى المفضلة.');
  }
}

class _ProviderComparePicker extends StatelessWidget {
  const _ProviderComparePicker({
    required this.providers,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<MarketplaceProvider> providers;
  final Set<String> selectedIds;
  final ValueChanged<MarketplaceProvider> onToggle;

  @override
  Widget build(BuildContext context) {
    if (providers.length < 3) return const SizedBox.shrink();
    return AarastSection(
      title: 'اختر للمقارنة',
      description: 'اعرض موردين أو ثلاثة في نفس السطح.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final provider in providers)
            AarastFilterPill(
              key: Key('compare-provider-${provider.id}'),
              label: provider.businessName,
              icon: selectedIds.contains(provider.id)
                  ? LucideIcons.check
                  : LucideIcons.plus,
              selected: selectedIds.contains(provider.id),
              onTap: () => onToggle(provider),
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
      color: AppTheme.canvas,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(LucideIcons.heart, color: AppTheme.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count مورد محفوظ للمقارنة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
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

class _ProviderComparisonSurface extends StatelessWidget {
  const _ProviderComparisonSurface({
    required this.providers,
    required this.isSubmitting,
    required this.onOpen,
    required this.onRemove,
  });

  final List<MarketplaceProvider> providers;
  final bool isSubmitting;
  final ValueChanged<MarketplaceProvider> onOpen;
  final ValueChanged<MarketplaceProvider> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AarastV3Space.x4),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.arrowLeftRight,
                  color: AarastV3Color.primary,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مقارنة واضحة',
                        style: AarastV3Type.section(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        providers.length > 1
                            ? 'السعر والتقييم والخدمات أمامك في مكان واحد.'
                            : 'احفظ موردًا آخر لتظهر المقارنة جنبًا إلى جنب.',
                        style: AarastV3Type.body(
                          context,
                        ).copyWith(color: AarastV3Color.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AarastV3Color.line),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < providers.length; index++) ...[
                  _ComparisonColumn(
                    provider: providers[index],
                    isSubmitting: isSubmitting,
                    onOpen: () => onOpen(providers[index]),
                    onRemove: () => onRemove(providers[index]),
                  ),
                  if (index != providers.length - 1)
                    const SizedBox(width: AarastV3Space.x3),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'الحفظ وطلب العرض لا ينشئان حجزًا أو دفعة؛ وعند قبول العرض تُنشأ التكلفة تلقائياً.',
              style: AarastV3Type.label(
                context,
              ).copyWith(color: AarastV3Color.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({
    required this.provider,
    required this.isSubmitting,
    required this.onOpen,
    required this.onRemove,
  });

  final MarketplaceProvider provider;
  final bool isSubmitting;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AarastV3Color.primarySoft,
              borderRadius: BorderRadius.circular(AarastV3Radius.control),
            ),
            child: Text(
              provider.businessName.isEmpty
                  ? 'مورد محفوظ'
                  : provider.businessName.substring(0, 1),
              style: AarastV3Type.display(
                context,
              ).copyWith(color: AarastV3Color.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            provider.businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AarastV3Type.section(context),
          ),
          const SizedBox(height: 10),
          _ComparisonFact(
            label: 'الخدمة',
            value: _favoriteCategoryLabel(provider),
          ),
          _ComparisonFact(
            label: 'المدينة',
            value: provider.city?.nameAr.trim().isNotEmpty == true
                ? provider.city!.nameAr.trim()
                : 'غير محددة',
          ),
          _ComparisonFact(
            label: 'السعر',
            value: _favoritePriceRangeLabel(provider.services) ?? 'اطلب عرضًا',
          ),
          _ComparisonFact(
            label: 'التقييم',
            value: provider.ratingCount == 0
                ? 'لا تقييمات'
                : '${provider.ratingAverage.toStringAsFixed(1)} · ${provider.ratingCount}',
          ),
          _ComparisonFact(
            label: 'الخدمات',
            value: '${provider.services.where((item) => item.isActive).length}',
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onOpen, child: const Text('عرض التفاصيل')),
          IconButton(
            key: Key('favorite-provider-remove-${provider.id}'),
            tooltip: 'إزالة ${provider.businessName} من المحفوظات',
            onPressed: isSubmitting ? null : onRemove,
            icon: const Icon(LucideIcons.heartOff, size: 18),
            color: AarastV3Color.danger,
          ),
        ],
      ),
    );
  }
}

class _ComparisonFact extends StatelessWidget {
  const _ComparisonFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AarastV3Type.label(
              context,
            ).copyWith(color: AarastV3Color.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AarastV3Type.body(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String _favoriteCategoryLabel(MarketplaceProvider provider) {
  final primary = provider.primaryCategory?.nameAr.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  for (final service in provider.services) {
    final category = service.category?.nameAr.trim();
    if (category != null && category.isNotEmpty) return category;
  }
  return 'غير محددة';
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
