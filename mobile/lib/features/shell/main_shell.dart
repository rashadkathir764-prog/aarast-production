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
  // DashboardBottomNav indices mirror the approved user navigation:
  // 0: Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©, 1: Ø§Ù„Ù…Ø§Ù„, 2: Ø§Ù„Ù…Ù‡Ø§Ù…, 3: Ø§Ù„Ù…ÙˆØ±Ø¯ÙˆÙ†, 4: Ø§Ù„Ù…Ø²ÙŠØ¯.
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
        const SnackBar(
          content: Text(
            'Ø§Ù„Ø±Ø¬Ø§Ø¡ Ø§Ø®ØªÙŠØ§Ø± Ø£Ùˆ Ø¥Ù†Ø´Ø§Ø¡ Ø®Ø·Ø© Ø²ÙØ§Ù Ø£ÙˆÙ„Ø§Ù‹',
          ),
        ),
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
        label: 'Ø¥Ø¶Ø§ÙØ© Ù…ØµØ±ÙˆÙ',
        onTap: () =>
            open(AppRouter.createExpense(planId), refreshDashboard: true),
      ),
      RoyalHomeAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'Ø¥Ø¶Ø§ÙØ© Ù…Ù‡Ù…Ø©',
        onTap: () => open(AppRouter.createTask(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.group_add_outlined,
        label: 'Ø¥Ø¶Ø§ÙØ© Ø¶ÙŠÙ',
        onTap: () => open(AppRouter.guestList(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.attach_money_rounded,
        label: 'Ø¥Ø¶Ø§ÙØ© Ø¯ÙŠÙ†',
        onTap: () => open(AppRouter.createDebt(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.request_quote_outlined,
        label: 'Ø·Ù„Ø¨ Ø¹Ø±Ø¶ Ø³Ø¹Ø±',
        onTap: () => open(AppRouter.providerMarketplace),
      ),
      RoyalHomeAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Ø§Ù„Ù…Ø³Ø§Ø¹Ø¯ Ø§Ù„Ø°ÙƒÙŠ',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('النصائح الذكية لاحقًا')),
          );
        },
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
                    : _buildNoPlanFallback('Ø§Ù„Ù…Ø§Ù„'),
              ),

              // Index 2: Tasks
              _buildLazyTab(
                2,
                _activePlanId != null
                    ? TaskTimelineScreen(
                        key: ValueKey('tasks-$_activePlanId'),
                        weddingPlanId: _activePlanId!,
                      )
                    : _buildNoPlanFallback('Ø§Ù„Ù…Ù‡Ø§Ù…'),
              ),

              // Index 3: Vendors marketplace — public browsing for guests.
              // Quote submit remains backend-protected without an account.
              _buildLazyTab(3, const ProviderMarketplaceScreen(embedded: true)),

              // Index 4: More/settings/secondary surfaces
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
              'Ø§Ù„Ø±Ø¬Ø§Ø¡ Ø§Ø®ØªÙŠØ§Ø± Ø®Ø·Ø© Ù…Ù† Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ© Ø£ÙˆÙ„Ø§Ù‹',
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
