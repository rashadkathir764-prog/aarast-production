import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../home/screens/home_screen.dart';
import '../marketplace/screens/provider_marketplace_screen.dart';
import '../more/screens/more_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/aarast_dashboard_widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // DashboardBottomNav indices mirror the approved RTL shell:
  // 4: الرئيسية, 1: المهام, 3: الموردين, 0: المزيد.
  int _index = 4;
  String? _activePlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<WeddingPlansProvider>();
      await provider.loadMyWeddingPlans();
      if (!mounted || _activePlanId != null || provider.plans.isEmpty) return;
      setState(() {
        _activePlanId = provider.plans.first.id;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
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
          String route,
        ) {
          return ListTile(
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(route);
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
                        'إضافة سريعة',
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
                    AppRouter.finance(_activePlanId!),
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
                    Icons.post_add_rounded,
                    AppTheme.dGoldDeep,
                    AppTheme.dCreamBg,
                    'خطة جديدة',
                    AppRouter.createWeddingPlan,
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

    // Map DashboardBottomNav indices to the IndexedStack.

    int stackIndex = 0;
    if (_index == 4) {
      stackIndex = 0;
    } else if (_index == 3) {
      stackIndex = 1;
    } else if (_index == 1) {
      stackIndex = 2;
    } else if (_index == 0) {
      stackIndex = 3;
    }

    return Theme(
      data: shellTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF6EF),
          body: IndexedStack(
            index: stackIndex,
            children: [
              // Index 0 (Nav 4): Home overview. Plan lists are explicit routes.
              _activePlanId != null
                  ? WeddingPlanDashboardScreen(
                      key: ValueKey('home-$_activePlanId'),
                      weddingPlanId: _activePlanId!,
                      embedded: true,
                    )
                  : const HomeScreen(embedded: true),

              // Index 1 (Nav 3): Vendors marketplace
              const ProviderMarketplaceScreen(embedded: true),

              // Index 2 (Nav 1): Tasks
              _activePlanId != null
                  ? TaskTimelineScreen(
                      key: ValueKey('tasks-$_activePlanId'),
                      weddingPlanId: _activePlanId!,
                    )
                  : _buildNoPlanFallback('المهام'),

              // Index 3 (Nav 0): More
              const MoreScreen(),
            ],
          ),
          bottomNavigationBar: DashboardBottomNav(
            activeIndex: _index,
            onHome: () => _onItemTapped(4),
            onPlans: () => _onItemTapped(3),
            onAdd: _showQuickAdd,
            onTasks: () => _onItemTapped(1),
            onMore: () => _onItemTapped(0),
          ),
        ),
      ),
    );
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
