import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_details_view.dart';
import '../widgets/quote_status_chip.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({
    required this.providerId,
    this.weddingPlanId,
    super.key,
  });

  final String providerId;
  final String? weddingPlanId;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  bool _quoteContextReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ProviderMarketplaceProvider>().loadProviderDetails(
        widget.providerId,
        weddingPlanId: widget.weddingPlanId,
      );
      if (mounted) setState(() => _quoteContextReady = true);
    });
  }

  @override
  void didUpdateWidget(covariant ProviderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.weddingPlanId != widget.weddingPlanId) {
      _quoteContextReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await context.read<ProviderMarketplaceProvider>().loadProviderDetails(
          widget.providerId,
          weddingPlanId: widget.weddingPlanId,
        );
        if (mounted) setState(() => _quoteContextReady = true);
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
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.ivory,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Consumer<ProviderMarketplaceProvider>(
              builder: (context, marketplace, _) {
                final quotes = marketplace.quotesForProviderInScope(
                  widget.providerId,
                  weddingPlanId: widget.weddingPlanId,
                );
                final latest = quotes.isEmpty ? null : quotes.first;
                final loadingQuote =
                    !_quoteContextReady ||
                    marketplace.isProviderQuoteContextLoading(
                      widget.providerId,
                    );
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.softShadow(opacity: 0.12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (latest != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 2, 6, 7),
                          child: Row(
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
                        ),
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
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: AarastButton(
                              label: loadingQuote
                                  ? 'تحميل حالة الطلب...'
                                  : _primaryQuoteActionLabel(latest),
                              expand: false,
                              onPressed: loadingQuote
                                  ? null
                                  : () => _openPrimaryQuoteAction(
                                      context,
                                      latest,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
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
                  onPressed: () => state.loadProviderDetails(
                    widget.providerId,
                    weddingPlanId: widget.weddingPlanId,
                  ),
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
          return ProviderDetailsView(
            provider: provider,
            services: services,
            packages: packages,
            reviews: reviews,
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
            onRequestQuote: (service) => context.push(
              AppRouter.providerQuote(provider.id),
              extra: service.id,
            ),
          );
        },
      ),
    );
  }

  String _primaryQuoteActionLabel(QuoteRequest? quote) {
    if (quote == null) return 'طلب عرض سعر';
    if (quote.status == 'SENT' || quote.status == 'VIEWED') {
      return 'متابعة الطلب الحالي';
    }
    if (quote.status == 'RESPONDED') {
      return quote.hasExpiredOffer ? 'طلب عرض جديد' : 'مراجعة العرض';
    }
    if (quote.status == 'ACCEPTED') return 'عرض المورد في الخطة';
    return 'طلب عرض جديد';
  }

  void _openPrimaryQuoteAction(BuildContext context, QuoteRequest? quote) {
    if (quote == null ||
        quote.status == 'CANCELLED' ||
        quote.status == 'REJECTED' ||
        quote.hasExpiredOffer) {
      context.push(AppRouter.providerQuote(widget.providerId));
      return;
    }
    if (quote.status == 'SENT' || quote.status == 'VIEWED') {
      context.push(AppRouter.quoteConversation(quote.id));
      return;
    }
    final planId = quote.weddingPlanId ?? widget.weddingPlanId;
    if (planId != null && planId.isNotEmpty) {
      context.push(AppRouter.planProviders(planId, quoteId: quote.id));
      return;
    }
    context.push('${AppRouter.providerMarketplace}?quoteId=${quote.id}');
  }
}

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
  AarastToast.showSuccess(context, 'تم نسخ بيانات المورد للمشاركة');
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
            shape: const CircleBorder(),
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
