import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/diagnostics/app_logger.dart';
import '../../core/offline/offline_status_widgets.dart';
import '../../core/routing/root_tab_back_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/aarast_ui.dart';
import '../account_contexts/account_contexts_api.dart'
    show AccountContext, AccountContextController, AccountContextRole;
import '../finance/finance_api.dart' show FinanceProvider, MoneyOverviewScreen;
import '../guests/guests_api.dart' show GuestListScreen;
import '../marketplace/marketplace_api.dart' show ProviderMarketplaceScreen;
import '../tasks/tasks_api.dart' show TaskTimelineScreen;
import '../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, WeddingPlanDashboardScreen;
import 'screens/participant_plan_shell.dart';
import 'widgets/plan_quick_add.dart';
import 'widgets/plan_quick_add_sheet.dart';
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
        message: 'مساحة المزود لها واجهة مستقلة ولا تُفتح من واجهة الخطط.',
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
  // 0: الرئيسية, 1: المال, 2: المهام, 3: الضيوف, 4: المزودين.
  int _index = 0;
  final Set<int> _visitedTabs = {0};

  /// Raised by the «+» to open the guests' add sheet on their tab.
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

  /// The «+» on the current tab (D33). The guest sheet and the providers
  /// open on their own tabs inside this shell.
  PlanQuickAddFlow _quickAdd() {
    final planId = widget.weddingPlanId;
    final dashboard = context.read<DashboardSummaryProvider>();
    final summary = dashboard.summary;
    return PlanQuickAddFlow(
      planId: planId,
      tabIndex: _index,
      canManageMoney: _canManageMoney(planId),
      canManageBudget: _canManageBudget(planId),
      offerAgreementActions: true,
      signals: summary?.planId == planId
          ? PlanQuickAddSignals.fromDashboard(summary!)
          : null,
      onAddGuest: () => setState(() {
        _index = 3;
        _visitedTabs.add(3);
        _guestAddRequest += 1;
      }),
      onFindProviders: () => _onItemTapped(4),
      onChanged: () => dashboard.loadDashboard(planId),
    );
  }

  /// Money rights from the loaded money, else from the home summary.
  bool _canManageMoney(String planId) {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId == planId) return finance!.canManageMoney;
    final summary = context.read<DashboardSummaryProvider>().summary;
    return summary?.planId == planId && summary!.permissions.canManageMoney;
  }

  /// The budget's rights are known once the money is loaded.
  bool _canManageBudget(String planId) {
    final finance = context.read<FinanceProvider?>();
    return finance?.loadedPlanId == planId && finance!.canManageBudget;
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
    // D85: adding never waits for the server; a guest added without it is
    // kept on the phone and sent later.
    final showQuickAdd = shouldShowPlanQuickAdd(
      tabIndex: _index,
      canManageMoney:
          _index != 1 ||
          (finance?.loadedPlanId == selectedPlanId && finance!.canManageMoney),
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
          // The same offline line as the plan-route shell (c04, w29).
          topStatus: const OfflineStatusBanner(),
          onQuickAdd: showQuickAdd ? () => _quickAdd().open(context) : null,
          onQuickAddLongPress: showQuickAdd
              ? () => _quickAdd().repeatLast(context)
              : null,
          backgroundColor: AppTheme.canvas,
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
                  preserveOwnerShellOnQuoteFocus: true,
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
        selectedTab: 'home',
        screen: 'ParticipantPlanShell',
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
      selectedTab: 'home',
      screen: 'ParticipantPlanShell',
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

    return ParticipantPlanShell(
      key: ValueKey('participant-shell-${accountContext.contextKey}'),
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
