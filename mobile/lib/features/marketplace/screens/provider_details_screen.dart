import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContext, AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../data/provider_contact_links.dart';
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
  String? _countedViewProviderId;

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
    final providerFailedToLoad = context
        .select<ProviderMarketplaceProvider, bool>(
          (marketplace) =>
              marketplace.providerDetails(widget.providerId) == null &&
              marketplace.detailsErrorFor(widget.providerId) != null,
        );
    final providerUnclaimed = context
        .select<ProviderMarketplaceProvider, bool>(
          (marketplace) =>
              marketplace.providerDetails(widget.providerId)?.isClaimed ==
              false,
        );
    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      // A provider that failed to load (unknown, or not public) has nothing
      // to request a quote from, so the quote footer is not offered; an
      // unclaimed listing (V1 4.18) explains how to reach it instead.
      bottomNavigationBar: providerFailedToLoad
          ? null
          : providerUnclaimed
          ? const _UnclaimedProviderFooter()
          : _quoteFooter(selectedPlanId),
      child: Consumer<ProviderMarketplaceProvider>(
        builder: (context, state, _) {
          final provider = state.providerDetails(widget.providerId);
          final services = state.servicesFor(widget.providerId);
          final packages = state.packagesFor(widget.providerId);
          final reviews = state.reviewsFor(widget.providerId);
          final servicesError = state.servicesErrorFor(widget.providerId);
          final packagesError = state.packagesErrorFor(widget.providerId);
          final reviewsError = state.reviewsErrorFor(widget.providerId);
          final detailsError = state.detailsErrorFor(widget.providerId);
          final detailsLoading = state.isProviderQuoteContextLoading(
            widget.providerId,
          );

          if (detailsLoading && provider == null) {
            return AarastSkeleton.page(heroHeight: 220, tiles: 3, cards: 2);
          }

          if (detailsError != null && provider == null) {
            return _DetailsFrame(
              child: AarastEmptyState(
                icon: LucideIcons.alertCircle,
                title: 'تعذر فتح المزود',
                message: detailsError,
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
                title: 'المزود غير متاح',
                message: 'لم نتمكن من العثور على تفاصيل هذا المزود.',
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
            onWhatsApp: _externalLinkAction(
              context,
              providerWhatsAppUri(provider.whatsapp),
              'تعذر فتح واتساب على هذا الجهاز.',
            ),
            onOpenMap: _externalLinkAction(
              context,
              providerMapUri(provider.latitude, provider.longitude),
              'تعذر فتح الخريطة على هذا الجهاز.',
            ),
            onFavorite: () async {
              if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
                context,
              )) {
                return;
              }
              await state.toggleFavorite(provider.id);
            },
            onRequestQuote: (service) => provider.isClaimed
                ? _pushOnce(
                    AppRouter.providerQuote(provider.id),
                    extra: service.id,
                  )
                : AarastToast.showInfo(context, unclaimedProviderMessage),
            servicesErrorMessage: servicesError,
            packagesErrorMessage: packagesError,
            reviewsErrorMessage: reviewsError,
            detailsErrorMessage: detailsError,
            isRetryingDetails: detailsLoading,
            onRetryDetails: () => state.loadProviderDetails(
              widget.providerId,
              weddingPlanId: selectedPlanId,
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
    _countView(marketplace);
  }

  /// Once per opened provider, and never the provider's own preview of
  /// their listing (V1 checklist 4.19).
  void _countView(ProviderMarketplaceProvider marketplace) {
    if (!mounted || _countedViewProviderId == widget.providerId) return;
    if (marketplace.providerDetails(widget.providerId) == null) return;
    final contexts =
        context.read<AccountContextController?>()?.contexts ?? const [];
    if (contexts.any((item) => item.providerId == widget.providerId)) return;
    _countedViewProviderId = widget.providerId;
    marketplace.recordProviderView(widget.providerId);
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
