import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_details_view.dart'
    show providerMoneyLabel, providerPriceRange;

/// «قارن الملفين» from f09: two saved providers side by side, laid out as
/// f04 compares offers, with neither marked better («أنسب لك» is dropped).
/// [providerIds] are the two chosen on the favourites tab; without them the
/// first two saved providers are compared.
class FavoriteProvidersScreen extends StatefulWidget {
  const FavoriteProvidersScreen({this.providerIds = const [], super.key});

  final List<String> providerIds;

  @override
  State<FavoriteProvidersScreen> createState() =>
      _FavoriteProvidersScreenState();
}

class _FavoriteProvidersScreenState extends State<FavoriteProvidersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// The two chosen, or the first two saved of the same kind of service.
  List<String> _ids(ProviderMarketplaceProvider marketplace) {
    final chosen = widget.providerIds.where((id) => id.isNotEmpty).toList();
    if (chosen.length >= 2) return chosen.take(2).toList();
    return firstSameKindPair([
      for (final item in marketplace.favoriteProviders) ?item.provider,
    ]);
  }

  Future<void> _load() async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    if (widget.providerIds.length < 2) {
      await marketplace.loadFavoriteProviders();
      if (!mounted) return;
    }
    await Future.wait([
      for (final id in _ids(marketplace))
        marketplace.loadProviderDetails(id, weddingPlanId: null),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final ids = _ids(marketplace);
    final providers = [for (final id in ids) ?marketplace.providerDetails(id)];
    final loading = ids.any(marketplace.isProviderQuoteContextLoading);
    final failed = ids.any(
      (id) =>
          marketplace.providerDetails(id) == null &&
          marketplace.detailsErrorFor(id) != null,
    );

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: context.say('قارن بينهم', 'قارني بينهم'),
            subtitle: _subtitle(providers),
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.providerMarketplace),
          ),
          // A band beside a photographer compares nothing.
          if (providers.length == 2 &&
              providers[0].differsInKindFrom(providers[1]))
            JourneyListState(
              key: const ValueKey('compare-not-same-kind'),
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyTitle: 'المقارنة تكون بين اثنين من نفس الخدمة',
              emptyMessage: context.say(
                'اختر من المفضلة اثنين من نفس الخدمة، مثل قاعتين أو مصورين.',
                'اختاري من المفضلة اثنين من نفس الخدمة، مثل صالتين أو مصورتين.',
              ),
              emptyAction: context.say('ارجع للمفضلة', 'ارجعي للمفضلة'),
              onEmptyAction: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRouter.providerMarketplace),
            )
          else if (providers.length == 2)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, provider) in providers.indexed) ...[
                    if (index > 0) const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: _CompareColumn(
                        key: ValueKey('compare-provider-${provider.id}'),
                        provider: provider,
                        services: marketplace.servicesFor(provider.id),
                        packages: marketplace.packagesFor(provider.id),
                        onOpen: () => context.push(
                          AppRouter.providerDetails(provider.id),
                        ),
                        onQuote: provider.isClaimed
                            ? () => context.push(
                                AppRouter.providerQuote(provider.id),
                              )
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (failed)
            JourneyListState(
              phase: JourneyListPhase.error,
              section: JourneySection.providers,
              onRetry: _load,
            )
          else if (loading || ids.length == 2)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.providers,
            )
          else if (marketplace.favoriteProviders.length >= 2)
            // Saved, but no two of the same service.
            JourneyListState(
              key: const ValueKey('compare-no-same-kind'),
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyTitle: 'المقارنة تكون بين اثنين من نفس الخدمة',
              emptyMessage: context.say(
                'احفظ مزود ثاني من نفس خدمة واحد من مفضلتك، وقارن بينهم.',
                'احفظي مزود ثاني من نفس خدمة واحد من مفضلتك، وقارني بينهم.',
              ),
              emptyAction: context.say('افتح استكشف', 'افتحي استكشف'),
              onEmptyAction: () => context.go(AppRouter.providerMarketplace),
            )
          else
            JourneyListState(
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyTitle: context.say(
                'احفظ مزودين تقارن بينهم',
                'احفظي مزودين تقارنين بينهم',
              ),
              emptyMessage: context.say(
                'اضغط القلب على مزودين في «استكشف»، ويجون هنا.',
                'اضغطي القلب على مزودين في «استكشف»، ويجون هنا.',
              ),
              // Critique ط5: the way to «استكشف» it names.
              emptyAction: context.say('افتح استكشف', 'افتحي استكشف'),
              onEmptyAction: () => context.go(AppRouter.providerMarketplace),
            ),
        ],
      ),
    );
  }

  /// «التصوير» when both do the same kind of service.
  String? _subtitle(List<MarketplaceProvider> providers) {
    final kinds = {
      for (final provider in providers) provider.primaryCategory?.nameAr,
    };
    return kinds.length == 1 ? kinds.single : null;
  }
}

/// One provider's column: name, prices, packages, rating, place, and the
/// way to ask it for a quote.
class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    required this.provider,
    required this.services,
    required this.packages,
    required this.onOpen,
    required this.onQuote,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final VoidCallback onOpen;
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    final price = providerPriceRange(services);
    final city = provider.city?.nameAr.trim();
    final active = packages.where((item) => item.isActive).toList();
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AarastPressable(
            onTap: onOpen,
            semanticLabel: provider.businessName,
            // RA-MO-27: the name is the only way into the provider from
            // the compare column; a 48 target, its words unchanged.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: Text(
                  provider.businessName,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            price ?? 'حسب الطلب',
            style: JourneyType.of(
              JourneyType.lead,
              weight: JourneyType.bold,
              color: context.accent.primary,
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          for (final item in active)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: AarastV3Space.half),
                    child: Icon(
                      LucideIcons.check,
                      size: AarastV3Icon.sm,
                      color: AarastV3Color.mint,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    child: Text(
                      [
                        item.title,
                        ?providerMoneyLabel(item.price, item.currency),
                      ].join(' · '),
                      style: JourneyType.of(JourneyType.small),
                    ),
                  ),
                ],
              ),
            ),
          if (provider.ratingCount > 0) ...[
            const SizedBox(height: AarastV3Space.x1),
            Row(
              children: [
                const Icon(
                  LucideIcons.star,
                  size: AarastV3Icon.sm,
                  color: AarastV3Color.brandAccentStrong,
                ),
                const SizedBox(width: AarastV3Space.x1),
                Flexible(
                  child: Text(
                    '${provider.ratingAverage.toStringAsFixed(1)} '
                    '(${provider.ratingCount})',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (city != null && city.isNotEmpty)
            Text(
              city,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          const Spacer(),
          const SizedBox(height: AarastV3Space.x3),
          if (onQuote != null)
            JourneyButton(
              key: ValueKey('compare-quote-${provider.id}'),
              label: context.say('اطلب عرض سعر', 'اطلبي عرض سعر'),
              background: context.accent.primarySoft,
              foreground: context.accent.primary,
              expand: true,
              onPressed: onQuote,
            )
          else
            Text(
              'ما يستقبل طلبات لين يستلم صاحبه ملفه',
              style: JourneyType.of(
                JourneyType.caption,
                color: AarastV3Color.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
