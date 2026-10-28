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
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: PlanCenterScreen(weddingPlanId: id, sharedMember: sharedMember),
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
  // b12 «مناسبات عرسك» (D65): every member reads it; the screen itself
  // offers changes only to whoever may edit the plan.
  GoRoute(
    path: '/wedding-plans/:id/events',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: PlanEventsScreen(weddingPlanId: id),
      );
    },
  ),
  // y06 and y07, opened once per phone by the owner's home (D65).
  GoRoute(
    path: '/wedding-plans/:id/moments/:moment',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final moment = state.pathParameters['moment'] == WeddingMoment.day.name
          ? WeddingMoment.day
          : WeddingMoment.week;
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.viewPlan,
        child: WeddingMomentScreen(weddingPlanId: id, moment: moment),
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
    path: '/wedding-plans/:id/guests/invite',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageGuests,
        child: GuestInviteScreen(
          weddingPlanId: id,
          reminder: state.uri.queryParameters['mode'] == 'remind',
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/providers/requests',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageProviders,
        child: ProviderRequestsScreen(
          weddingPlanId: id,
          itemKey: state.uri.queryParameters['item'],
          quoteId: state.uri.queryParameters['quote'],
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/providers/booked/:quoteId',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageProviders,
        child: BookingMomentScreen(
          weddingPlanId: id,
          quoteId: state.pathParameters['quoteId'] ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/providers/reviews',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageProviders,
        child: ProviderReviewsScreen(
          weddingPlanId: id,
          providerId: state.uri.queryParameters['provider'],
        ),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/providers/bookings',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageProviders,
        child: PlanBookingsScreen(weddingPlanId: id),
      );
    },
  ),
  GoRoute(
    path: '/wedding-plans/:id/guests/import',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: WeddingPlanRouteAccess.manageGuests,
        child: GuestImportScreen(
          weddingPlanId: id,
          source: state.uri.queryParameters['from'] == 'contacts'
              ? GuestImportSource.contacts
              : GuestImportSource.paste,
        ),
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
        // g06 is a sheet over the participants list.
        child: SharingScreen(weddingPlanId: id, startAdding: true),
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
  // q10 lists the plans a participant helps in, inside «حسابي».
  GoRoute(
    path: AppRouter.sharedWeddingPlans,
    redirect: (context, state) => AppRouter.more,
  ),
  // q19: a plan helped in that its owner put in the memories.
  GoRoute(
    path: '/shared/wedding-plans/:id',
    builder: (context, state) => ParticipantPlanStateScreen(
      weddingPlanId: state.pathParameters['id'] ?? '',
    ),
  ),
];
