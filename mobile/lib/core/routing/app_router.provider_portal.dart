part of 'app_router.dart';

// The provider persona: application and portal management.
List<RouteBase> _providerPortalRoutes() => [
  GoRoute(
    path: AppRouter.providerApply,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      child: const ProviderApplyScreen(),
    ),
  ),
  GoRoute(
    path: AppRouter.providerDashboard,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      child: ProviderPortalScreen(
        initialTab: state.uri.queryParameters['tab'],
      ),
    ),
  ),
  GoRoute(
    path: '/provider/requests/:id',
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerOperationsRequired: true,
      child: ProviderRequestScreen(quoteId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/provider/requests/:id/offer',
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerOperationsRequired: true,
      child: ProviderOfferScreen(quoteId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: AppRouter.providerProfileEdit,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerProfileManageRequired: true,
      child: const EditProviderProfileScreen(),
    ),
  ),
  GoRoute(
    path: AppRouter.providerNotifications,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      child: const ProviderNotificationsScreen(),
    ),
  ),
  GoRoute(
    path: AppRouter.providerServices,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerOperationsRequired: true,
      child: const ProviderServicesScreen(),
    ),
  ),
  GoRoute(
    path: AppRouter.providerServiceNew,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerOperationsRequired: true,
      child: const AddProviderServiceScreen(),
    ),
  ),
  GoRoute(
    path: AppRouter.providerPackageNew,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      providerAccountRequired: true,
      providerOperationsRequired: true,
      child: const AddProviderPackageScreen(),
    ),
  ),
];
