part of 'app_router.dart';

// Customer provider discovery and quote requests.
List<RouteBase> _marketplaceRoutes() => [
  // Public provider browsing: guests may open the marketplace and
  // provider details without an account. Quote/provider management
  // routes stay behind ProviderAuthGate.
  GoRoute(
    path: AppRouter.providerMarketplace,
    builder: (context, state) => ProviderMarketplaceScreen(
      initialQuoteId: state.uri.queryParameters['quoteId'],
    ),
  ),
  GoRoute(
    path: AppRouter.favoriteProviders,
    builder: (context, state) => const FavoriteProvidersScreen(),
  ),
  GoRoute(
    path: '/providers/:id',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final weddingPlanId = state.uri.queryParameters['weddingPlanId'];
      final screen = ProviderDetailsScreen(
        providerId: id,
        weddingPlanId: weddingPlanId,
        returnQuoteToMarketplace:
            state.extra ==
            ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
      );
      return weddingPlanId == null
          ? screen
          : WeddingPlanContextGate(
              weddingPlanId: weddingPlanId,
              requiredAccess: WeddingPlanRouteAccess.manageProviders,
              child: screen,
            );
    },
  ),
  GoRoute(
    path: '/providers/:id/quote',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final quoteContext = state.extra is ProviderQuoteInitialContext
          ? state.extra! as ProviderQuoteInitialContext
          : null;
      final initialServiceId =
          quoteContext?.serviceId ??
          (state.extra is String ? state.extra! as String : null);
      return ProviderAuthGate(
        resumeLocation: state.uri.toString(),
        child: SelectedWeddingPlanContextGate(
          requiredAccess: WeddingPlanRouteAccess.manageProviders,
          child: QuoteRequestScreen(
            providerId: id,
            initialServiceId: initialServiceId,
            initialBudgetIntent: quoteContext?.budgetIntent,
          ),
        ),
      );
    },
  ),
  GoRoute(
    path: '/providers/:id/quote-request',
    redirect: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return AppRouter.providerQuote(id);
    },
  ),
];
