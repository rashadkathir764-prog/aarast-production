part of 'app_router.dart';

// The wedding-plan shell and the pages inside it.
List<RouteBase> _planShellRoutes() => [
  ShellRoute(
    builder: (context, state, child) {
      final id = state.pathParameters['id'] ?? '';
      // A tab's root needs the plan only (D52): a participant without the
      // section's right gets its lock from participantPlanTab (q07, q08).
      return WeddingPlanContextGate(
        weddingPlanId: id,
        requiredAccess: weddingPlanRouteAccessForPath(state.uri.path),
        child: WeddingPlanShell(weddingPlanId: id, child: child),
      );
    },
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/dashboard',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final sharedMember = state.extra is SharedMember
              ? state.extra! as SharedMember
              : null;
          final participant = participantPlanTab(context, id, 0);
          if (participant != null) return participant;
          return WeddingPlanDashboardScreen(
            weddingPlanId: id,
            sharedMember: sharedMember,
            embedded: true,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final sharedMember = state.extra is SharedMember
              ? state.extra! as SharedMember
              : null;
          return participantPlanTab(context, id, 1) ??
              MoneyOverviewScreen(
                weddingPlanId: id,
                sharedMember: sharedMember,
                embedded: true,
              );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/budget',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MoneyBudgetScreen(weddingPlanId: id);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/categories/create',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BudgetCategoryFormScreen(
            weddingPlanId: id,
            initialName: state.extra is String ? state.extra! as String : null,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/categories/:categoryId',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final categoryId = state.pathParameters['categoryId'] ?? '';
          return BudgetCategoryDetailsScreen(
            weddingPlanId: id,
            categoryId: categoryId,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/categories/:categoryId/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final categoryId = state.pathParameters['categoryId'] ?? '';
          final category = state.extra is BudgetCategory
              ? state.extra! as BudgetCategory
              : context.read<FinanceProvider>().categoryById(categoryId);
          if (category == null) {
            return BudgetCategoryDetailsScreen(
              weddingPlanId: id,
              categoryId: categoryId,
            );
          }
          return BudgetCategoryFormScreen(
            weddingPlanId: id,
            category: category,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/create',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CostFormScreen(
            weddingPlanId: id,
            intent: state.extra is CostDraftIntent
                ? state.extra! as CostDraftIntent
                : null,
            initialCategoryId: state.uri.queryParameters['categoryId'],
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final costId = state.pathParameters['costId'] ?? '';
          final cost = state.extra is WeddingCost
              ? state.extra! as WeddingCost
              : context.read<FinanceProvider>().costById(costId);
          // An agreement that is not loaded shows its own page, which loads
          // it or says it is gone.
          if (cost == null) {
            return CostDetailsScreen(weddingPlanId: id, costId: costId);
          }
          return CostFormScreen(weddingPlanId: id, cost: cost);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/payments/create',
        builder: (context, state) {
          return RecordCostPaymentScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/payments/:paymentId',
        builder: (context, state) {
          return CostPaymentDetailsScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.uri.queryParameters['costId'],
            paymentId: state.pathParameters['paymentId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/receipts',
        builder: (context, state) {
          return MoneyReceiptsScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/funding',
        builder: (context, state) {
          return FundingSourcesScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            openSourceId: state.uri.queryParameters['source'],
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/mahr',
        builder: (context, state) {
          return MahrScreen(weddingPlanId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/mahr/moment',
        builder: (context, state) {
          return MahrMomentScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/payers',
        builder: (context, state) {
          return PayerPaymentsScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path:
            '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/pay',
        builder: (context, state) {
          return PayPaymentScheduleScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
            scheduleId: state.pathParameters['scheduleId'] ?? '',
          );
        },
      ),
      // A payment date has no page of its own: the server's reminders and
      // next steps link here, and its agreement (c07) lists every date.
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
        redirect: (context, state) => AppRouter.moneyCostDetails(
          state.pathParameters['id'] ?? '',
          state.pathParameters['costId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId',
        builder: (context, state) {
          return CostDetailsScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/tasks',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return participantPlanTab(context, id, 2) ??
              TaskTimelineScreen(weddingPlanId: id);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/add',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GuestListScreen(weddingPlanId: id, openAddOnStart: true);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return participantPlanTab(context, id, 3) ??
              GuestListScreen(weddingPlanId: id);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/attendance',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GuestAttendanceScreen(weddingPlanId: id);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final budgetIntent = state.extra is ProviderBudgetMatchIntent
              ? state.extra! as ProviderBudgetMatchIntent
              : null;
          // R-07: a participant without the providers right reads their own
          // page whatever the link carries; the owner's screen is for those
          // who may manage providers.
          final participant = participantPlanTab(context, id, 4);
          if (participant != null) return participant;
          return ProviderMarketplaceScreen(
            embedded: true,
            weddingPlanId: id,
            initialBudgetIntent: budgetIntent,
            initialQuoteId: state.uri.queryParameters['quoteId'],
          );
        },
      ),
    ],
  ),
];
