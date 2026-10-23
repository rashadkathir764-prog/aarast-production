part of 'app_router.dart';

// Plan pages opened above the shell.
List<RouteBase> _weddingPlanRoutes() => [
  GoRoute(
    path: '/wedding-plans/:id/plan-center',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final sharedMember = state.extra is SharedMember
          ? state.extra! as SharedMember
          : (state.extra is Map &&
                (state.extra as Map)['sharedMember'] is SharedMember)
          ? (state.extra as Map)['sharedMember'] as SharedMember
          : null;
      final initialSummary =
          state.extra is Map &&
              (state.extra as Map)['summary'] is DashboardSummary
          ? (state.extra as Map)['summary'] as DashboardSummary
          : null;
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: PlanCenterScreen(
          weddingPlanId: id,
          sharedMember: sharedMember,
          initialSummary: initialSummary,
        ),
      );
    },
  ),
  // The planning assistant (V1 checklist 4.12); the screen itself tells a
  // reader who is not the owner or partner that it is not theirs.
  GoRoute(
    path: '/wedding-plans/:id/assistant',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: PlanAssistantScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/wedding-day',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final initialSummary = state.extra is DashboardSummary
          ? state.extra! as DashboardSummary
          : null;
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: WeddingDayModeScreen(
          weddingPlanId: id,
          initialSummary: initialSummary,
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/tasks/create',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageTasks,
        child: CreateTaskScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/guests/view/:guestId',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageGuests,
        child: GuestDetailsScreen(
          weddingPlanId: id,
          guestId: state.pathParameters['guestId'] ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/tasks/:taskId',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: TaskDetailsScreen(
          weddingPlanId: id,
          taskId: state.pathParameters['taskId'] ?? '',
          initialTask: state.extra is WeddingTask
              ? state.extra! as WeddingTask
              : null,
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/tasks/:taskId/edit',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final taskId = state.pathParameters['taskId'] ?? '';
      final task = state.extra is WeddingTask
          ? state.extra! as WeddingTask
          : null;
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageTasks,
        child: CreateTaskScreen(
          weddingPlanId: id,
          taskId: taskId,
          initialTask: task,
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/timeline',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageTasks,
        child: TaskTimelineScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/sharing',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.inviteMembers,
        child: SharingScreen(weddingPlanId: id),
      );
    },
  ),

  GoRoute(
    path: '/wedding-plans/:id/notifications',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: NotificationsScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/contributions',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: ContributionHistoryScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/sharing/add',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.inviteMembers,
        child: AddSharedMemberScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/sharing/:memberId/edit',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final memberId = state.pathParameters['memberId'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.inviteMembers,
        child: EditSharedMemberScreen(sharedMemberId: memberId),
      );
    },
  ),
  GoRoute(
    path: AppRouter.sharedWeddingPlans,
    builder: (context, state) => const SharedWeddingPlansScreen(),
  ),
];
