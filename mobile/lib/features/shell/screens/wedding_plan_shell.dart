import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../wedding_plans/widgets/royal_home_chrome.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../../core/routing/app_router.dart';

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
    if (location.endsWith('/finance') || location.contains('/finance/')) {
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
    final routes = ['dashboard', 'finance', 'tasks', 'guests', 'providers'];
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
        refreshDashboardOnExpense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    IconData getFabIcon() {
      switch (currentIndex) {
        case 1:
          return Icons.account_balance_wallet_rounded;
        case 2:
          return Icons.check_circle_outline_rounded;
        case 3:
          return Icons.group_add_rounded;
        case 4:
          return Icons.storefront_rounded;
        default:
          return Icons.add_rounded;
      }
    }

    final showQuickFab = currentIndex != 4;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      floatingActionButton: showQuickFab
          ? RoyalSmartFloatingActionButton(
              icon: getFabIcon(),
              onPressed: () =>
                  _showQuickAdd(context, weddingPlanId, currentIndex),
            )
          : null,
      bottomNavigationBar: RoyalDashboardBottomNav(
        activeIndex: currentIndex,
        onHome: () => _onNavigate(context, 0),
        onMoney: () => _onNavigate(context, 1),
        onTasks: () => _onNavigate(context, 2),
        onGuests: () => _onNavigate(context, 3),
        onProviders: () => _onNavigate(context, 4),
      ),
      body: child,
    );
  }
}
