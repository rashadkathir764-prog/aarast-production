import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
          icon: const Icon(Icons.chevron_right_rounded),
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
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_showLoginGate)
              AarastEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'سجل الدخول لفتح المفضلة',
                message:
                    'حفظ الموردين مرتبط بحسابك حتى تجدهم مرة أخرى من أي جهاز.',
                action: FilledButton.icon(
                  onPressed: () => context.go(AppRouter.login),
                  icon: const Icon(Icons.login_rounded),
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
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (favorites.isEmpty)
              AarastEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'لا توجد مفضلة بعد',
                message:
                    'اضغط على القلب بجانب أي مورد ليظهر هنا للمقارنة والمتابعة.',
                action: OutlinedButton.icon(
                  onPressed: () => context.go(AppRouter.providerMarketplace),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('تصفح الموردين'),
                ),
              )
            else ...[
              _FavoriteSummary(count: favorites.length),
              const SizedBox(height: 12),
              for (final provider in favorites) ...[
                _FavoriteProviderCard(
                  provider: provider,
                  onOpen: () =>
                      context.push(AppRouter.providerDetails(provider.id)),
                  onQuote: () =>
                      context.push(AppRouter.providerQuote(provider.id)),
                  onRemove: marketplace.isSubmitting
                      ? null
                      : () async {
                          await marketplace.toggleFavorite(provider.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('تمت إزالة المورد من المفضلة'),
                              ),
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

class _FavoriteSummary extends StatelessWidget {
  const _FavoriteSummary({required this.count});

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
            child: const Icon(Icons.favorite_rounded, color: AppTheme.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count مورد محفوظ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRouter.providerMarketplace),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteProviderCard extends StatelessWidget {
  const _FavoriteProviderCard({
    required this.provider,
    required this.onOpen,
    required this.onQuote,
    required this.onRemove,
  });

  final MarketplaceProvider provider;
  final VoidCallback onOpen;
  final VoidCallback onQuote;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final city = provider.city?.nameAr.trim();
    final description = provider.description?.trim();

    return AarastCard(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProviderLogo(provider: provider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      city == null || city.isEmpty ? 'مورد زفاف' : city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.favorite_rounded),
                color: AppTheme.burgundy,
                tooltip: 'إزالة من المفضلة',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('التفاصيل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onQuote,
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('طلب عرض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider});

  final MarketplaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final logo = provider.logoUrl?.trim();
    final initial = provider.businessName.trim().isEmpty
        ? 'م'
        : provider.businessName.trim().characters.first;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: logo == null || logo.isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            )
          : Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
    );
  }
}
