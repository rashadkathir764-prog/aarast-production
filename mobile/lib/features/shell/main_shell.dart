import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../home/screens/home_screen.dart';
import '../home/data/dashboard_summary_sources.dart';
import '../finance/screens/budget_expense_screen.dart';
import '../marketplace/screens/provider_marketplace_screen.dart';
import '../more/screens/more_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/dashboard_summary_provider.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/royal_home_chrome.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Bottom-nav indices for the live user shell:
  // 0: الرئيسية, 1: المال, 2: المهام, 3: الموردون, 4: المزيد.
  int _index = 0;
  final Set<int> _visitedTabs = {0};
  String? _activePlanId;

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

    return [
      RoyalHomeAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'إضافة مصروف',
        onTap: () =>
            open(AppRouter.createExpense(planId), refreshDashboard: true),
      ),
      RoyalHomeAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'إضافة مهمة',
        onTap: () => open(AppRouter.createTask(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.group_add_outlined,
        label: 'إضافة ضيف',
        onTap: () => open(AppRouter.guestList(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.attach_money_rounded,
        label: 'إضافة دين',
        onTap: () => open(AppRouter.createDebt(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.request_quote_outlined,
        label: 'طلب عرض سعر',
        onTap: () => open(AppRouter.providerMarketplace),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shellTheme = Theme.of(context);

    return Theme(
      data: shellTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
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

              // Index 3: Vendors marketplace
              _buildLazyTab(3, const ProviderMarketplaceScreen(embedded: true)),

              // Index 4: More
              _buildLazyTab(4, const MoreScreen()),
            ],
          ),
          bottomNavigationBar: RoyalDashboardBottomNav(
            activeIndex: _index,
            onHome: () => _onItemTapped(0),
            onMoney: () => _onItemTapped(1),
            onTasks: () => _onItemTapped(2),
            onProviders: () => _onItemTapped(3),
            onMore: () => _onItemTapped(4),
            onAdd: _showQuickAdd,
          ),
        ),
      ),
    );
  }

  Widget _buildLazyTab(int index, Widget child) {
    return _visitedTabs.contains(index) ? child : const SizedBox.shrink();
  }

  Widget _buildNoPlanFallback(String title) {
    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: AppTheme.dMuted),
            const SizedBox(height: 16),
            Text(
              'اختر خطة من الرئيسية أولًا لفتح $title.',
              style: const TextStyle(
                color: AppTheme.dInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
