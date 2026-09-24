part of 'app_router.dart';

// Account-level screens: notifications, invites, more, settings, support, plans.
List<RouteBase> _accountRoutes() => [
  GoRoute(
    path: AppRouter.notifications,
    builder: (context, state) => const NotificationsScreen(),
  ),
  GoRoute(
    path: AppRouter.inviteAccess,
    builder: (context, state) => const InviteDecisionScreen(),
  ),
  GoRoute(
    path: '/invites/:token',
    builder: (context, state) =>
        InviteDecisionScreen(token: state.pathParameters['token'] ?? ''),
  ),
  GoRoute(
    path: AppRouter.more,
    builder: (context, state) => const MoreScreen(),
  ),
  GoRoute(
    path: AppRouter.settings,
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: AppRouter.support,
    builder: (context, state) => const SupportScreen(),
  ),
  GoRoute(
    path: AppRouter.weddingPlans,
    builder: (context, state) => const MyWeddingPlansScreen(),
  ),
  GoRoute(
    path: AppRouter.createWeddingPlan,
    builder: (context, state) => const CreateWeddingPlanScreen(),
  ),
];
