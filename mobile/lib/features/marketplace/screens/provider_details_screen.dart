import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/models/account_context.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_details_view.dart';
import '../widgets/quote_status_chip.dart';

part 'provider_details_screen.widgets.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({
    required this.providerId,
    this.weddingPlanId,
    this.returnQuoteToMarketplace = false,
    super.key,
  });

  final String providerId;
  final String? weddingPlanId;
  final bool returnQuoteToMarketplace;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  bool _quoteContextReady = false;
  bool _isReturningQuoteToMarketplace = false;
  final Set<String> _routeLaunchesInFlight = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadDetails();
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
        await _loadDetails();
        if (mounted) setState(() => _quoteContextReady = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = _matchingSelectedPlanId(selected);
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
                  weddingPlanId: selectedPlanId,
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
                              onTap: () => _openQuoteConversation(latest.id),
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
                    weddingPlanId: selectedPlanId,
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
            onRequestQuote: (service) => _pushOnce(
              AppRouter.providerQuote(provider.id),
              extra: service.id,
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadDetails() async {
    final hasAccount = await _hasAccount();
    if (!mounted) return;
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final selectedPlanId = hasAccount
        ? _matchingSelectedPlanId(selected)
        : null;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    marketplace.configureAccountScope(
      includeAccountData: hasAccount,
      weddingPlanId: selectedPlanId,
    );
    await marketplace.loadProviderDetails(
      widget.providerId,
      weddingPlanId: selectedPlanId,
    );
  }

  Future<bool> _hasAccount() async {
    try {
      return await AuthActionGuard.hasAccount(context);
    } on ProviderNotFoundException {
      // Public provider previews and isolated route tests do not mount the
      // account storage. They may browse public details, but never receive
      // account-scoped quotes.
      return false;
    }
  }

  String? _matchingSelectedPlanId(AccountContext? selected) {
    if (selected?.isPlan != true) return null;
    final selectedPlanId = selected?.weddingPlanId?.toString().trim();
    if (selectedPlanId == null || selectedPlanId.isEmpty) return null;
    final requestedPlanId = widget.weddingPlanId?.trim();
    if (requestedPlanId != null &&
        requestedPlanId.isNotEmpty &&
        requestedPlanId != selectedPlanId) {
      return null;
    }
    return selectedPlanId;
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

  Future<T?> _pushOnce<T>(String location, {Object? extra}) async {
    if (!mounted || !_routeLaunchesInFlight.add(location)) return null;
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      _routeLaunchesInFlight.remove(location);
    }
  }

  void _openPrimaryQuoteAction(BuildContext context, QuoteRequest? quote) {
    if (quote == null ||
        quote.status == 'CANCELLED' ||
        quote.status == 'REJECTED' ||
        quote.hasExpiredOffer) {
      _pushOnce(AppRouter.providerQuote(widget.providerId));
      return;
    }
    if (quote.status == 'SENT' || quote.status == 'VIEWED') {
      _openQuoteConversation(quote.id);
      return;
    }
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final selectedPlanId = selected?.isPlan == true
        ? selected?.weddingPlanId
        : null;
    final quotePlanId = quote.weddingPlanId?.trim();
    if (selectedPlanId == null ||
        (quotePlanId != null &&
            quotePlanId.isNotEmpty &&
            quotePlanId != selectedPlanId)) {
      AarastToast.showError(
        context,
        'هذا العرض لا يطابق مسار الخطة المحدد حاليًا.',
      );
      return;
    }
    if (_returnQuoteToMarketplace(
      ProviderMarketplaceRouteResult.focusQuote(quote.id),
    )) {
      return;
    }
    _pushOnce(AppRouter.planProviders(selectedPlanId, quoteId: quote.id));
  }

  Future<void> _openQuoteConversation(String quoteId) async {
    final result = await _pushOnce<ProviderMarketplaceRouteResult>(
      AppRouter.quoteConversation(quoteId),
      extra: widget.returnQuoteToMarketplace
          ? ProviderMarketplaceLaunchOrigin.ownerMainShellProviders
          : null,
    );
    if (!mounted || result == null) return;
    _returnQuoteToMarketplace(result);
  }

  bool _returnQuoteToMarketplace(ProviderMarketplaceRouteResult result) {
    if (!widget.returnQuoteToMarketplace) return false;
    if (_isReturningQuoteToMarketplace) return true;
    if (!context.canPop()) return false;
    _isReturningQuoteToMarketplace = true;
    context.pop(result);
    return true;
  }
}
