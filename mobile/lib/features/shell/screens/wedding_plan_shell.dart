import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../account_contexts/models/account_context.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
import '../../wedding_plans/models/wedding_plan_stage.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../home/data/dashboard_summary_sources.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../finance/providers/finance_provider.dart';
import '../../finance/screens/money_overview_screen.dart';
import '../../finance/widgets/money_cost_action_picker.dart';
import '../widgets/plan_shell_chrome.dart';
import '../widgets/aarast_plan_chrome.dart';

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
    if (currentIndex == 2) {
      rememberCanonicalQuickAddAction(planId, 'task');
      _openQuickAddRoute(context, planId, AppRouter.createTask(planId));
      return;
    }
    if (currentIndex == 3) {
      rememberCanonicalQuickAddAction(planId, 'guest');
      context.go(AppRouter.guestListAdd(planId));
      return;
    }

    showAarastQuickActionSheet(
      context,
      actions: _quickActions(
        context,
        planId,
        currentIndex,
        closeSheetBeforeOpen: true,
      ),
    );
  }

  void _runLastQuickAdd(BuildContext context, String planId, int currentIndex) {
    switch (lastCanonicalQuickAddActionId(planId)) {
      case 'task':
        _openQuickAddRoute(context, planId, AppRouter.createTask(planId));
        return;
      case 'guest':
        context.go(AppRouter.guestListAdd(planId));
        return;
      case null:
        _showQuickAdd(context, planId, currentIndex);
        return;
      default:
        final actions = _quickActions(
          context,
          planId,
          currentIndex,
          closeSheetBeforeOpen: false,
        );
        final action = lastCanonicalQuickAddAction(planId, actions);
        if (action == null) {
          _showQuickAdd(context, planId, currentIndex);
        } else {
          action.onTap();
        }
        return;
    }
  }

  List<AarastQuickAction> _quickActions(
    BuildContext context,
    String planId,
    int currentIndex, {
    required bool closeSheetBeforeOpen,
  }) {
    final dashboard = context.read<DashboardSummaryProvider?>()?.summary;

    final contextOrder = switch (currentIndex) {
      1 => QuickAddContext.money,
      4 => QuickAddContext.providers,
      _ => QuickAddContext.dashboard,
    };

    return buildCanonicalQuickAddActions(
      context,
      planId: planId,
      canManageMoney: _canManageMoney(context, planId),
      contextOrder: contextOrder,
      signals: dashboard?.planId == planId
          ? QuickAddSignals.fromDashboard(dashboard!)
          : null,
      onRecordPayment: () => _openMoneyCostAction(
        context,
        planId,
        MoneyCostActionIntent.payment,
        closeQuickSheet: closeSheetBeforeOpen,
      ),
      onAddPaymentSchedule: () => _openMoneyCostAction(
        context,
        planId,
        MoneyCostActionIntent.schedule,
        closeQuickSheet: closeSheetBeforeOpen,
      ),
      openRoute: (route, {refreshDashboard = false}) async {
        if (closeSheetBeforeOpen) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        await _openQuickAddRoute(
          context,
          planId,
          route,
          refreshDashboard: refreshDashboard,
        );
      },
      onRequestQuote: currentIndex == 4
          ? () {
              if (closeSheetBeforeOpen) {
                Navigator.of(context, rootNavigator: true).pop();
              }
              context.go(AppRouter.planProviders(planId));
            }
          : null,
      refreshDashboardOnMoney: true,
    );
  }

  Future<void> _openMoneyCostAction(
    BuildContext context,
    String planId,
    MoneyCostActionIntent intent, {
    required bool closeQuickSheet,
  }) async {
    if (closeQuickSheet) {
      await Navigator.of(context, rootNavigator: true).maybePop();
      await Future<void>.delayed(Duration.zero);
    }
    if (!context.mounted) return;

    final finance = context.read<FinanceProvider>();
    final selection = await showMoneyCostActionPicker(
      context,
      intent: intent,
      costs: finance.costs,
      currency: finance.summary.currency,
    );
    if (!context.mounted || selection == null) return;

    final route = selection.createCost
        ? AppRouter.moneyCostCreate(planId)
        : intent == MoneyCostActionIntent.payment
        ? AppRouter.moneyPaymentCreate(planId, selection.cost!.id)
        : AppRouter.moneyScheduleCreate(planId, selection.cost!.id);
    final changed = await context.push<bool>(route, extra: selection.cost);
    if (changed == true && context.mounted) {
      await finance.loadMoney(planId);
      if (context.mounted && !AuthActionGuard.isLocalGuestPlanId(planId)) {
        await context.read<DashboardSummaryProvider>().loadDashboard(planId);
      }
    }
  }

  Future<void> _openQuickAddRoute(
    BuildContext context,
    String planId,
    String route, {
    bool refreshDashboard = false,
  }) async {
    final changed = await context.push<bool>(route);
    if (refreshDashboard &&
        changed == true &&
        context.mounted &&
        !AuthActionGuard.isLocalGuestPlanId(planId)) {
      context.read<DashboardSummaryProvider>().loadDashboard(planId);
    }
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
    // Creation and editing are focused decisions. Keeping the plan navigation
    // and quick-add control underneath those routes creates competing actions
    // (and, for guest sheets, visibly overlaps the modal). Let form screens own
    // the whole viewport while preserving the surrounding data gate.
    if (!shouldDisplayPlanShellChrome(location)) return child;

    final finance = context.watch<FinanceProvider?>();
    final dashboardSummary = _watchDashboardSummaryOrNull(context);
    final stageLabel = dashboardSummary?.planId == weddingPlanId
        ? resolveWeddingPlanStage(dashboardSummary?.weddingDate).compactLabel
        : null;
    final canManageCurrentMoney =
        finance?.loadedPlanId == weddingPlanId &&
        (finance?.canManageMoney ?? false);

    final isMoneyRoot = location.endsWith('/money');
    final moneyStarterVisible =
        currentIndex == 1 &&
        isMoneyRoot &&
        finance != null &&
        shouldShowMoneyStarter(finance);
    final showQuickFab =
        !moneyStarterVisible &&
        shouldShowPlanQuickAdd(
          tabIndex: currentIndex,
          isRootDestination: currentIndex != 1 || isMoneyRoot,
          canManageMoney: currentIndex != 1 || canManageCurrentMoney,
        );

    final shell = PlanShellChrome(
      activeIndex: currentIndex,
      onTabSelected: (index) => _onNavigate(context, index),
      showQuickFab: showQuickFab,
      contextLabel: selected?.weddingPlanId == weddingPlanId
          ? selected!.displayName
          : dashboardSummary?.planId == weddingPlanId
          ? dashboardSummary!.title
          : 'خطة الزفاف',
      stageLabel: stageLabel,
      topStatus: const OfflineStatusBanner(),
      onQuickAdd: () => _showQuickAdd(context, weddingPlanId, currentIndex),
      onQuickAddLongPress: () =>
          _runLastQuickAdd(context, weddingPlanId, currentIndex),
      // This route-owned shell is entered from quote and conversation flows.
      // Its surface must stay opaque while GoRouter replaces child routes;
      // otherwise the Android render surface is exposed behind the persistent
      // bottom navigation during the transition.
      backgroundColor: AppTheme.canvas,
      body: child,
    );
    if (AuthActionGuard.isLocalGuestPlanId(weddingPlanId) &&
        dashboardSummary?.planId != weddingPlanId) {
      return _LocalPlanSummaryBridge(
        weddingPlanId: weddingPlanId,
        child: shell,
      );
    }
    return shell;
  }
}

bool shouldDisplayPlanShellChrome(String location) {
  // Only the Money root is a tab destination. Every nested Money route owns
  // its viewport and already provides a back action. Keeping the persistent
  // tab shell around budget/forms/details causes competing navigation,
  // content beneath the tabs, and keyboard overflows on short Android views.
  if (location.contains('/money/')) return false;

  return !(location.endsWith('/guests/add') ||
      location.endsWith('/categories/create') ||
      location.endsWith('/costs/create') ||
      location.endsWith('/payments/create') ||
      location.endsWith('/schedules/create') ||
      location.endsWith('/pay') ||
      location.endsWith('/edit'));
}

class _LocalPlanSummaryBridge extends StatefulWidget {
  const _LocalPlanSummaryBridge({
    required this.weddingPlanId,
    required this.child,
  });

  final String weddingPlanId;
  final Widget child;

  @override
  State<_LocalPlanSummaryBridge> createState() =>
      _LocalPlanSummaryBridgeState();
}

class _LocalPlanSummaryBridgeState extends State<_LocalPlanSummaryBridge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant _LocalPlanSummaryBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final source = LocalGuestDashboardSummarySource(
      context.read<GuestOnboardingStorage>(),
      database: _localDatabaseOrNull(),
    );
    final local = await source.loadSummary();
    if (!mounted || local == null) return;
    final summary = local.toDashboardSummary();
    if (summary.planId != widget.weddingPlanId) return;
    context.read<DashboardSummaryProvider>().publishLocalSummary(summary);
  }

  LocalDatabase? _localDatabaseOrNull() {
    try {
      return context.read<LocalDatabase>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

DashboardSummary? _watchDashboardSummaryOrNull(BuildContext context) {
  try {
    return context.watch<DashboardSummaryProvider>().summary;
  } on ProviderNotFoundException {
    return null;
  }
}
