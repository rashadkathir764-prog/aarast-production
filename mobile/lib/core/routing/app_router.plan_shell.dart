part of 'app_router.dart';

// The wedding-plan shell and the pages inside it.
List<RouteBase> _planShellRoutes() => [
  ShellRoute(
    builder: (context, state, child) {
      final id = state.pathParameters['id'] ?? '';
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
          final selected = context
              .read<AccountContextController?>()
              ?.selectedContext;
          final contributorView =
              selected?.role == AccountContextRole.contributor &&
              selected?.weddingPlanId == id;
          return MoneyOverviewScreen(
            weddingPlanId: id,
            sharedMember: sharedMember,
            embedded: !contributorView,
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
        path: '/wedding-plans/:id/money/costs',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CostsScreen(
            weddingPlanId: id,
            initialCategoryId: state.uri.queryParameters['categoryId'],
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
          if (cost == null) {
            return CostsScreen(weddingPlanId: id);
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
        path: '/wedding-plans/:id/money/schedules',
        builder: (context, state) {
          return PaymentSchedulesScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.uri.queryParameters['costId'],
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/create',
        builder: (context, state) {
          return PaymentScheduleFormScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
          );
        },
      ),
      GoRoute(
        path:
            '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/edit',
        builder: (context, state) {
          return PaymentScheduleFormScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
            scheduleId: state.pathParameters['scheduleId'] ?? '',
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
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
        builder: (context, state) {
          return PaymentScheduleDetailsScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
            costId: state.pathParameters['costId'] ?? '',
            scheduleId: state.pathParameters['scheduleId'] ?? '',
          );
        },
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
          return TaskTimelineScreen(
            weddingPlanId: id,
            showEmptyCreateAction: false,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/add',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GuestListScreen(
            weddingPlanId: id,
            showLocalFab: false,
            openAddOnStart: true,
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GuestListScreen(weddingPlanId: id, showLocalFab: false);
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final budgetIntent = state.extra is ProviderBudgetMatchIntent
              ? state.extra! as ProviderBudgetMatchIntent
              : null;
          return ProviderMarketplaceScreen(
            embedded:
                context
                    .read<AccountContextController?>()
                    ?.selectedContext
                    ?.role !=
                AccountContextRole.contributor,
            weddingPlanId: id,
            initialBudgetIntent: budgetIntent,
            initialQuoteId: state.uri.queryParameters['quoteId'],
          );
        },
      ),
    ],
  ),
];
