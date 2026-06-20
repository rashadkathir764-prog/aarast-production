import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../home/screens/home_screen.dart';
import '../home/data/dashboard_summary_sources.dart';
import '../finance/screens/budget_expense_screen.dart';
import '../marketplace/screens/provider_marketplace_screen.dart';
import '../marketplace/widgets/provider_auth_gate.dart';
import '../more/screens/more_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/dashboard_summary_provider.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/aarast_dashboard_widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // DashboardBottomNav indices mirror the approved user navigation:
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
        const SnackBar(content: Text('الرجاء اختيار أو إنشاء خطة زفاف أولاً')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget tile(
          IconData icon,
          Color color,
          Color bg,
          String label,
          String route, {
          bool refreshDashboard = false,
        }) {
          return ListTile(
            onTap: () async {
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              final changed = await context.push<bool>(route);
              if (refreshDashboard && changed == true && mounted) {
                await context.read<DashboardSummaryProvider>().loadDashboard(
                  _activePlanId!,
                );
              }
            },
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.dInk,
              ),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إجراءات سريعة!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dInk,
                        ),
                      ),
                    ),
                  ),
                  tile(
                    Icons.account_balance_wallet_outlined,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة مصروف',
                    AppRouter.createExpense(_activePlanId!),
                    refreshDashboard: true,
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة دين',
                    AppRouter.createDebt(_activePlanId!),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    AppTheme.dGreen,
                    AppTheme.dGreenBg,
                    'إضافة مهمة',
                    AppRouter.createTask(_activePlanId!),
                  ),
                  tile(
                    Icons.person_add_alt_1_outlined,
                    AppTheme.dBlue,
                    AppTheme.dBlueBg,
                    'إضافة ضيف',
                    AppRouter.guestList(_activePlanId!),
                  ),
                  tile(
                    Icons.request_quote_outlined,
                    AppTheme.dGoldDeep,
                    AppTheme.dCreamBg,
                    'طلب عرض سعر',
                    AppRouter.providerMarketplace,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
              _buildLazyTab(
                3,
                const ProviderAuthGate(
                  resumeLocation: AppRouter.providerMarketplace,
                  embedded: true,
                  child: ProviderMarketplaceScreen(embedded: true),
                ),
              ),

              // Index 4: More/settings/secondary surfaces
              _buildLazyTab(4, const MoreScreen()),
            ],
          ),
          bottomNavigationBar: DashboardBottomNav(
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
              'الرجاء اختيار خطة من الرئيسية أولاً',
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
