import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../../home/home_api.dart' show LocalGuestDashboardSummarySource;
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummary, DashboardSummaryProvider;
import '../widgets/plan_quick_add.dart';
import '../widgets/plan_quick_add_sheet.dart';
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

  /// The «+» on the current tab (D33). The guest sheet opens on its own
  /// route over the guests; a quote starts from the providers tab.
  PlanQuickAddFlow _quickAdd(BuildContext context, int currentIndex) {
    final dashboard = context.read<DashboardSummaryProvider?>();
    final summary = dashboard?.summary;
    final localPlan = AuthActionGuard.isLocalGuestPlanId(weddingPlanId);
    return PlanQuickAddFlow(
      planId: weddingPlanId,
      tabIndex: currentIndex,
      canManageMoney: _canManageMoney(context),
      canManageBudget: _canManageBudget(context),
      offerAgreementActions: true,
      signals: summary?.planId == weddingPlanId
          ? PlanQuickAddSignals.fromDashboard(summary!)
          : null,
      onAddGuest: () => context.go(AppRouter.guestListAdd(weddingPlanId)),
      onFindProviders: () => context.go(AppRouter.planProviders(weddingPlanId)),
      // A plan kept on the phone has no home summary to fetch; its own
      // bridge republishes it.
      onChanged: () async {
        if (!localPlan) await dashboard?.loadDashboard(weddingPlanId);
      },
    );
  }

  /// Money rights from the loaded money, else from the home summary.
  bool _canManageMoney(BuildContext context) {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId == weddingPlanId) return finance!.canManageMoney;
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    return summary?.planId == weddingPlanId &&
        summary!.permissions.canManageMoney;
  }

  /// The budget's rights are known once the money is loaded.
  bool _canManageBudget(BuildContext context) {
    final finance = context.read<FinanceProvider?>();
    return finance?.loadedPlanId == weddingPlanId && finance!.canManageBudget;
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
    // A participant gets the same five tabs, each page or its lock chosen by
    // the route (participantPlanTab), and no «+» (the design draws none).
    if (contributorView) {
      if (!shouldDisplayPlanShellChrome(location)) return child;
      return PlanShellChrome(
        key: ValueKey('participant-route-shell-$weddingPlanId'),
        activeIndex: currentIndex,
        onTabSelected: (index) => _onNavigate(context, index),
        topStatus: const OfflineStatusBanner(),
        backgroundColor: AppTheme.canvas,
        body: child,
      );
    }
    // Creation and editing are focused decisions. Keeping the plan navigation
    // underneath those routes creates competing actions (and, for guest
    // sheets, visibly overlaps the modal). Let form screens own the whole
    // viewport while preserving the surrounding data gate.
    if (!shouldDisplayPlanShellChrome(location)) return child;

    final dashboardSummary = _watchDashboardSummaryOrNull(context);
    // A plan kept on the phone sends nothing, so a missing connection
    // changes nothing in it and is not announced.
    final localPlan = AuthActionGuard.isLocalGuestPlanId(weddingPlanId);
    final finance = context.watch<FinanceProvider?>();
    final offline =
        !localPlan &&
        context.watch<OfflineSyncService?>()?.state == SyncState.offline;
    final showQuickAdd = shouldShowPlanQuickAdd(
      tabIndex: currentIndex,
      isRootDestination: currentIndex != 1 || location.endsWith('/money'),
      canManageMoney:
          currentIndex != 1 ||
          (finance?.loadedPlanId == weddingPlanId && finance!.canManageMoney),
      guestsWaitForConnection: offline,
    );

    final shell = PlanShellChrome(
      activeIndex: currentIndex,
      onTabSelected: (index) => _onNavigate(context, index),
      topStatus: localPlan ? null : const OfflineStatusBanner(),
      onQuickAdd: showQuickAdd
          ? () => _quickAdd(context, currentIndex).open(context)
          : null,
      onQuickAddLongPress: showQuickAdd
          ? () => _quickAdd(context, currentIndex).repeatLast(context)
          : null,
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
