import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/diagnostics/app_logger.dart';
import '../../core/routing/root_tab_back_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/aarast_ui.dart';
import '../account_contexts/models/account_context.dart';
import '../account_contexts/providers/account_context_controller.dart';
import '../finance/screens/money_overview_screen.dart';
import '../finance/providers/finance_provider.dart';
import '../guests/screens/guest_list_screen.dart';
import '../marketplace/screens/provider_marketplace_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/dashboard_summary_provider.dart';
import '../wedding_plans/screens/plan_management_screen.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/quick_add_actions.dart';
import '../wedding_plans/widgets/royal_home_chrome.dart';
import 'widgets/plan_shell_chrome.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<AccountContextController>().selectedContext;
    if (selected == null || !selected.isAvailable) {
      return const _InvalidShellContext(
        message: 'لا توجد مساحة نشطة لبناء واجهة التطبيق.',
      );
    }

    return switch (selected.role) {
      AccountContextRole.owner => _OwnerMainShell(
        key: ValueKey('owner-shell-${selected.contextKey}'),
        contextKey: selected.contextKey,
        weddingPlanId: selected.weddingPlanId!,
      ),
      AccountContextRole.contributor => _ContributorMainShell(
        key: ValueKey('contributor-shell-${selected.contextKey}'),
        accountContext: selected,
      ),
      AccountContextRole.provider => const _InvalidShellContext(
        message: 'مساحة المورد لها واجهة مستقلة ولا تُفتح من واجهة الخطط.',
      ),
    };
  }
}

class _OwnerMainShell extends StatefulWidget {
  const _OwnerMainShell({
    required this.contextKey,
    required this.weddingPlanId,
    super.key,
  });

  final String contextKey;
  final String weddingPlanId;

  @override
  State<_OwnerMainShell> createState() => _OwnerMainShellState();
}

class _OwnerMainShellState extends State<_OwnerMainShell> {
  // Bottom-nav indices for the live user shell:
  // 0: الرئيسية, 1: المال, 2: المهام, 3: الضيوف, 4: الموردون.
  int _index = 0;
  final Set<int> _visitedTabs = {0};
  int _guestAddRequest = 0;

  void _onItemTapped(int index) {
    appLogEvent(
      'SHELL_TAB_SELECTED',
      category: AppLogCategory.groom,
      activeContextKey: widget.contextKey,
      weddingPlanId: widget.weddingPlanId,
      shellType: 'owner',
      selectedTab: _ownerTabName(index),
      screen: _ownerScreenName(index),
      reason: 'explicit_tab_tap',
      source: 'OwnerMainShell',
    );
    setState(() {
      _index = index;
      _visitedTabs.add(index);
    });
  }

  void _showQuickAdd() {
    final selectedPlanId = widget.weddingPlanId;
    if (_index == 3) {
      setState(() {
        _visitedTabs.add(3);
        _guestAddRequest += 1;
      });
      return;
    }
    showRoyalHomeActionSheet(context, actions: _quickActions(selectedPlanId));
  }

  List<RoyalHomeAction> _quickActions(String planId) {
    Future<void> open(String route, {bool refreshDashboard = false}) async {
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      final changed = await context.push<bool>(route);
      if (refreshDashboard && changed == true && mounted) {
        await context.read<DashboardSummaryProvider>().loadDashboard(planId);
      }
    }

    return buildCanonicalQuickAddActions(
      context,
      planId: planId,
      canManageMoney: _canManageMoney(planId),
      contextOrder: _quickAddContextForIndex(_index),
      refreshDashboardOnMoney: true,
      openRoute: open,
    );
  }

  bool _canManageMoney(String planId) {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId == planId) {
      return finance?.canManageMoney ?? false;
    }
    final summary = context.read<DashboardSummaryProvider>().summary;
    return summary?.planId == planId &&
        (summary?.permissions.canManageMoney ?? false);
  }

  QuickAddContext _quickAddContextForIndex(int index) {
    return switch (index) {
      1 => QuickAddContext.money,
      2 => QuickAddContext.tasks,
      3 => QuickAddContext.guests,
      4 => QuickAddContext.providers,
      _ => QuickAddContext.dashboard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final shellTheme = Theme.of(context);
    final selected = context.watch<AccountContextController>().selectedContext;
    if (selected?.contextKey != widget.contextKey ||
        selected?.role != AccountContextRole.owner ||
        selected?.weddingPlanId != widget.weddingPlanId) {
      return const _InvalidShellContext(
        message: 'تغيّر سياق المالك قبل اكتمال بناء الواجهة.',
      );
    }
    final selectedPlanId = widget.weddingPlanId;
    final finance = context.watch<FinanceProvider?>();
    final canManageCurrentMoney =
        finance?.loadedPlanId == selectedPlanId &&
        (finance?.canManageMoney ?? false);
    final showQuickFab = shouldShowPlanQuickAdd(
      tabIndex: _index,
      canManageMoney: _index != 1 || canManageCurrentMoney,
    );

    return RootTabBackScope(
      activeIndex: _index,
      onReturnToRoot: () => _onItemTapped(0),
      child: Theme(
        data: shellTheme,
        child: PlanShellChrome(
          key: ValueKey('owner-shell-chrome-${widget.contextKey}'),
          activeIndex: _index,
          onTabSelected: _onItemTapped,
          showQuickFab: showQuickFab,
          onQuickAdd: _showQuickAdd,
          backgroundColor: AppTheme.ivory,
          body: IndexedStack(
            key: ValueKey('owner-indexed-stack-${widget.contextKey}'),
            index: _index,
            children: [
              // Index 0: Home overview. Plan lists are explicit routes.
              _buildLazyTab(
                0,
                WeddingPlanDashboardScreen(
                  key: ValueKey('home-$selectedPlanId'),
                  weddingPlanId: selectedPlanId,
                  embedded: true,
                ),
              ),

              // Index 1: Money
              _buildLazyTab(
                1,
                MoneyOverviewScreen(
                  key: ValueKey('money-$selectedPlanId'),
                  weddingPlanId: selectedPlanId,
                  embedded: true,
                ),
              ),

              // Index 2: Tasks
              _buildLazyTab(
                2,
                TaskTimelineScreen(
                  key: ValueKey('tasks-$selectedPlanId'),
                  weddingPlanId: selectedPlanId,
                ),
              ),

              // Index 3: Guests
              _buildLazyTab(
                3,
                GuestListScreen(
                  key: ValueKey('guests-$selectedPlanId'),
                  weddingPlanId: selectedPlanId,
                  showLocalFab: false,
                  openAddRequest: _guestAddRequest,
                ),
              ),

              // Index 4: Vendors marketplace
              _buildLazyTab(
                4,
                ProviderMarketplaceScreen(
                  key: ValueKey('providers-$selectedPlanId'),
                  embedded: true,
                  weddingPlanId: selectedPlanId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ownerTabName(int index) {
    return switch (index) {
      1 => 'money',
      2 => 'tasks',
      3 => 'guests',
      4 => 'providers',
      _ => 'home',
    };
  }

  String _ownerScreenName(int index) {
    return switch (index) {
      1 => 'MoneyOverviewScreen',
      2 => 'TaskTimelineScreen',
      3 => 'GuestListScreen',
      4 => 'ProviderMarketplaceScreen',
      _ => 'WeddingPlanDashboardScreen',
    };
  }

  Widget _buildLazyTab(int index, Widget child) {
    return _visitedTabs.contains(index) ? child : const SizedBox.shrink();
  }
}

class _ContributorMainShell extends StatefulWidget {
  const _ContributorMainShell({required this.accountContext, super.key});

  final AccountContext accountContext;

  @override
  State<_ContributorMainShell> createState() => _ContributorMainShellState();
}

class _ContributorMainShellState extends State<_ContributorMainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accountContext = widget.accountContext;
      appLogEvent(
        'DASHBOARD_BUILT',
        category: AppLogCategory.contributor,
        activeContextKey: accountContext.contextKey,
        activeContextType: 'contributor',
        weddingPlanId: accountContext.weddingPlanId,
        shellType: 'contributor',
        selectedTab: 'workspace',
        screen: 'PlanCenterScreen',
        reason: 'first_frame_completed',
        source: 'ContributorMainShell',
      );
    });
  }

  @override
  void dispose() {
    final accountContext = widget.accountContext;
    appLogEvent(
      'DASHBOARD_DISPOSED',
      category: AppLogCategory.contributor,
      activeContextKey: accountContext.contextKey,
      activeContextType: 'contributor',
      weddingPlanId: accountContext.weddingPlanId,
      shellType: 'contributor',
      selectedTab: 'workspace',
      screen: 'PlanCenterScreen',
      reason: 'widget_disposed',
      source: 'ContributorMainShell',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountContext = widget.accountContext;
    final selected = context.watch<AccountContextController>().selectedContext;
    if (selected?.contextKey != accountContext.contextKey ||
        selected?.role != AccountContextRole.contributor ||
        selected?.weddingPlanId != accountContext.weddingPlanId) {
      return const _InvalidShellContext(
        message: 'تغيّر سياق المساهم قبل اكتمال بناء الواجهة.',
      );
    }

    return PlanCenterScreen(
      key: ValueKey('contributor-workspace-${accountContext.contextKey}'),
      weddingPlanId: accountContext.weddingPlanId!,
    );
  }
}

class _InvalidShellContext extends StatelessWidget {
  const _InvalidShellContext({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastScaffold(
      child: Center(
        child: AarastEmptyState(
          key: const ValueKey('invalid-shell-context'),
          icon: LucideIcons.shieldAlert,
          title: 'تعذر فتح مساحة الحساب',
          message: message,
        ),
      ),
    );
  }
}
