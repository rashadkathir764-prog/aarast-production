import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/root_tab_back_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/aarast_ui.dart';
import '../home/screens/home_screen.dart';
import '../home/data/dashboard_summary_sources.dart';
import '../finance/screens/budget_expense_screen.dart';
import '../guests/screens/guest_list_screen.dart';
import '../marketplace/screens/provider_marketplace_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/dashboard_summary_provider.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/quick_add_actions.dart';
import '../wedding_plans/widgets/royal_home_chrome.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Bottom-nav indices for the live user shell:
  // 0: الرئيسية, 1: المال, 2: المهام, 3: الضيوف, 4: الموردون.
  int _index = 0;
  final Set<int> _visitedTabs = {0};
  String? _activePlanId;
  int _guestAddRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<WeddingPlansProvider>();
      final activePlan = await BackendDashboardSummarySource(
        provider,
      ).loadActivePlan();
      if (!mounted || _activePlanId != null) return;
      if (activePlan == null && provider.errorMessage == null) {
        context.go(AppRouter.onboarding);
        return;
      }
      if (activePlan == null) return;
      setState(() {
        _activePlanId = activePlan.id;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
      _visitedTabs.add(index);
    });
  }

  void _showQuickAdd() {
    if (_activePlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أو أنشئ خطة زفاف أولًا.')),
      );
      return;
    }
    if (_index == 3) {
      setState(() {
        _visitedTabs.add(3);
        _guestAddRequest += 1;
      });
      return;
    }
    showRoyalHomeActionSheet(context, actions: _quickActions(_activePlanId!));
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
      contextOrder: _quickAddContextForIndex(_index),
      refreshDashboardOnExpense: true,
      openRoute: open,
    );
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

    return RootTabBackScope(
      activeIndex: _index,
      onReturnToRoot: () => _onItemTapped(0),
      child: Theme(
        data: shellTheme,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.ivory,
            extendBody: true,
            body: IndexedStack(
              index: _index,
              children: [
                // Index 0: Home overview. Plan lists are explicit routes.
                _buildLazyTab(
                  0,
                  _activePlanId != null
                      ? WeddingPlanDashboardScreen(
                          key: ValueKey('home-$_activePlanId'),
                          weddingPlanId: _activePlanId!,
                          embedded: true,
                        )
                      : const HomeScreen(embedded: true),
                ),

                // Index 1: Money
                _buildLazyTab(
                  1,
                  _activePlanId != null
                      ? BudgetExpenseScreen(
                          key: ValueKey('money-$_activePlanId'),
                          weddingPlanId: _activePlanId!,
                          embedded: true,
                        )
                      : _buildNoPlanFallback('المال'),
                ),

                // Index 2: Tasks
                _buildLazyTab(
                  2,
                  _activePlanId != null
                      ? TaskTimelineScreen(
                          key: ValueKey('tasks-$_activePlanId'),
                          weddingPlanId: _activePlanId!,
                        )
                      : _buildNoPlanFallback('المهام'),
                ),

                // Index 3: Guests
                _buildLazyTab(
                  3,
                  _activePlanId != null
                      ? GuestListScreen(
                          key: ValueKey('guests-$_activePlanId'),
                          weddingPlanId: _activePlanId!,
                          showLocalFab: false,
                          openAddRequest: _guestAddRequest,
                        )
                      : _buildNoPlanFallback('الضيوف'),
                ),

                // Index 4: Vendors marketplace
                _buildLazyTab(
                  4,
                  const ProviderMarketplaceScreen(embedded: true),
                ),
              ],
            ),
            floatingActionButton:
                _activePlanId == null || !_showsQuickFab(_index)
                ? null
                : RoyalSmartFloatingActionButton(
                    icon: _fabIconForIndex(_index),
                    onPressed: _showQuickAdd,
                  ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: _index,
              onHome: () => _onItemTapped(0),
              onMoney: () => _onItemTapped(1),
              onTasks: () => _onItemTapped(2),
              onGuests: () => _onItemTapped(3),
              onProviders: () => _onItemTapped(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLazyTab(int index, Widget child) {
    return _visitedTabs.contains(index) ? child : const SizedBox.shrink();
  }

  bool _showsQuickFab(int index) {
    return index != 1 && index != 4;
  }

  IconData _fabIconForIndex(int index) {
    // أيقونات Lucide لتوحيد القشرة مع بقية الشاشات الفخمة.
    return switch (index) {
      1 => LucideIcons.wallet,
      2 => LucideIcons.listPlus,
      3 => LucideIcons.userPlus,
      4 => LucideIcons.store,
      _ => LucideIcons.plus,
    };
  }

  Widget _buildNoPlanFallback(String title) {
    return AarastScaffold(
      child: Center(
        child: AarastEmptyState(
          icon: Icons.info_outline_rounded,
          title: title,
          message: 'اختر خطة من الرئيسية أولًا لفتح $title.',
        ),
      ),
    );
  }
}
