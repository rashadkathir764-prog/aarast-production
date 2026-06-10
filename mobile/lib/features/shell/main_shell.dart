import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../more/screens/more_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../wedding_plans/screens/my_wedding_plans_screen.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/new_dashboard_widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  String? _activePlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  void _onItemTapped(int index) {
    if (_index == 0 && index == 0 && _activePlanId != null) {
      // User tapped Home while already on Home with an active plan -> Go back to plans list
      setState(() {
        _activePlanId = null;
      });
      return;
    }
    setState(() {
      _index = index;
    });
  }

  void _selectPlan(String planId) {
    setState(() {
      _activePlanId = planId;
      _index = 0; // Go to Dashboard
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
        Widget tile(IconData icon, Color color, Color bg, String label, String route) {
          return ListTile(
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(route);
            },
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.dInk),
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
                    decoration: BoxDecoration(color: AppTheme.dLine, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('إضافة سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.dInk)),
                    ),
                  ),
                  tile(Icons.account_balance_wallet_outlined, AppTheme.dMaroon, AppTheme.dPinkBg, 'إضافة مصروف', AppRouter.finance(_activePlanId!)),
                  tile(Icons.credit_card_rounded, AppTheme.dMaroon, AppTheme.dPinkBg, 'إضافة دين', AppRouter.debts(_activePlanId!)),
                  tile(Icons.check_circle_outline_rounded, AppTheme.dGreen, AppTheme.dGreenBg, 'إضافة مهمة', AppRouter.tasks(_activePlanId!)),
                  tile(Icons.post_add_rounded, AppTheme.dGoldDeep, AppTheme.dCreamBg, 'خطة جديدة', AppRouter.createWeddingPlan),
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
    final theme = Theme.of(context);
    final shellTheme = theme.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
    );

    return Theme(
      data: shellTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: DashboardUiColors.background,
          body: IndexedStack(
            index: _index,
            children: [
              // Index 0: Home (Plans Hub OR Dashboard)
              _activePlanId != null
                  ? WeddingPlanDashboardScreen(
                      key: ValueKey('home-$_activePlanId'),
                      weddingPlanId: _activePlanId!,
                      embedded: true,
                    )
                  : MyWeddingPlansScreen(onSelectPlan: _selectPlan),

              // Index 1: Tasks
              _activePlanId != null
                  ? TaskTimelineScreen(
                      key: ValueKey('tasks-$_activePlanId'),
                      weddingPlanId: _activePlanId!,
                    )
                  : _buildNoPlanFallback('المهام'),

              // Index 2: Vendors (Coming Soon)
              _buildNoPlanFallback('الموردين', isComingSoon: true),

              // Index 3: More
              const MoreScreen(),
            ],
          ),
          bottomNavigationBar: NewDashboardBottomNav(
            activeIndex: _index,
            onHome: () => _onItemTapped(0),
            onTasks: () => _onItemTapped(1),
            onVendors: () => _onItemTapped(2),
            onMore: () => _onItemTapped(3),
            onAdd: _showQuickAdd,
          ),
        ),
      ),
    );
  }

  Widget _buildNoPlanFallback(String title, {bool isComingSoon = false}) {
    return Scaffold(
      backgroundColor: DashboardUiColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isComingSoon ? Icons.construction : Icons.info_outline,
                size: 64, color: DashboardUiColors.textGray.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              isComingSoon
                  ? 'قسم "$title" قيد الإعداد'
                  : 'الرجاء اختيار خطة من الرئيسية أولاً',
              style: const TextStyle(
                  color: DashboardUiColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
