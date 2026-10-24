part of 'app_router.dart';

// Account-level screens: notifications, invites, more, settings, support, plans.
List<RouteBase> _accountRoutes() => [
  GoRoute(
    path: AppRouter.notifications,
    builder: (context, state) => const NotificationsScreen(),
  ),
  // x04 «تساعد في عرس أحد؟»: the way in for a participant without the link
  // open yet; the link itself opens the invite (q01 to q03).
  GoRoute(
    path: AppRouter.inviteAccess,
    builder: (context, state) => const FromFamilyScreen(),
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
    path: AppRouter.lockSettings,
    builder: (context, state) => const LockSettingsScreen(),
  ),
  GoRoute(
    path: AppRouter.support,
    builder: (context, state) => const SupportScreen(),
  ),
  GoRoute(
    path: AppRouter.weddingPlans,
    builder: (context, state) => const MyWeddingPlansScreen(),
  ),
  // w11 «خطة جديدة»: another plan is made with the designed steps (a02b
  // to a08), not a separate form.
  GoRoute(
    path: AppRouter.createWeddingPlan,
    builder: (context, state) => const SmartWelcomeScreen(newPlan: true),
  ),
];
