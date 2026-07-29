import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../account_contexts/models/account_context.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../wedding_plans/widgets/royal_home_chrome.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../../core/routing/app_router.dart';
import '../../finance/providers/finance_provider.dart';
import '../widgets/plan_shell_chrome.dart';

class WeddingPlanShell extends StatelessWidget {
  const WeddingPlanShell({
    required this.child,
    required this.weddingPlanId,
    super.key,
  });

  final Widget child;
  final String weddingPlanId;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.endsWith('/money') || location.contains('/money/')) {
      return 1;
    }
    if (location.endsWith('/tasks')) return 2;
    if (location.endsWith('/guests') || location.contains('/guests/')) {
      return 3;
    }
    if (location.endsWith('/providers')) return 4;
    return 0; // default to dashboard
  }

  void _onNavigate(BuildContext context, int index) {
    final routes = ['dashboard', 'money', 'tasks', 'guests', 'providers'];
    if (index >= 0 && index < routes.length) {
      final current = _calculateSelectedIndex(context);
      if (current == index) return;
      context.go('/wedding-plans/$weddingPlanId/${routes[index]}');
    }
  }

  void _showQuickAdd(BuildContext context, String planId, int currentIndex) {
    Future<void> open(String route, {bool refreshDashboard = false}) async {
      final changed = await context.push<bool>(route);
      if (refreshDashboard &&
          changed == true &&
          context.mounted &&
          !AuthActionGuard.isLocalGuestPlanId(planId)) {
        context.read<DashboardSummaryProvider>().loadDashboard(planId);
      }
    }

    if (currentIndex == 2) {
      open(AppRouter.createTask(planId));
      return;
    }
    if (currentIndex == 3) {
      context.go(AppRouter.guestListAdd(planId));
      return;
    }

    final contextOrder = switch (currentIndex) {
      1 => QuickAddContext.money,
      4 => QuickAddContext.providers,
      _ => QuickAddContext.dashboard,
    };

    showRoyalHomeActionSheet(
      context,
      actions: buildCanonicalQuickAddActions(
        context,
        planId: planId,
        canManageMoney: _canManageMoney(context, planId),
        contextOrder: contextOrder,
        openRoute: (route, {refreshDashboard = false}) async {
          Navigator.of(context, rootNavigator: true).pop();
          await open(route, refreshDashboard: refreshDashboard);
        },
        onRequestQuote: currentIndex == 4
            ? () {
                Navigator.of(context, rootNavigator: true).pop();
                context.go(AppRouter.planProviders(planId));
              }
            : null,
        refreshDashboardOnMoney: true,
      ),
    );
  }

  bool _canManageMoney(BuildContext context, String planId) {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId == planId) {
      return finance?.canManageMoney ?? false;
    }
    final summary = context.read<DashboardSummaryProvider>().summary;
    return summary?.planId == planId &&
        (summary?.permissions.canManageMoney ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    final routeState = GoRouterState.of(context);
    final location = routeState.uri.path;
    final selected = context.watch<AccountContextController>().selectedContext;
    final contributorView =
        selected?.role == AccountContextRole.contributor &&
        selected?.weddingPlanId == weddingPlanId;

    // The selected account context is the only authority for shell shape.
    if (contributorView) return child;

    final finance = context.watch<FinanceProvider?>();
    final canManageCurrentMoney =
        finance?.loadedPlanId == weddingPlanId &&
        (finance?.canManageMoney ?? false);

    final isMoneyRoot = location.endsWith('/money');
    final showQuickFab = shouldShowPlanQuickAdd(
      tabIndex: currentIndex,
      isRootDestination: currentIndex != 1 || isMoneyRoot,
      canManageMoney: currentIndex != 1 || canManageCurrentMoney,
    );

    return PlanShellChrome(
      activeIndex: currentIndex,
      onTabSelected: (index) => _onNavigate(context, index),
      showQuickFab: showQuickFab,
      onQuickAdd: () => _showQuickAdd(context, weddingPlanId, currentIndex),
      backgroundColor: Colors.transparent,
      body: child,
    );
  }
}
