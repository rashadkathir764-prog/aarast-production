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
    path: AppRouter.providerApplyStatus,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      registerAsProvider: true,
      child: const ProviderApplyStatusScreen(),
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
