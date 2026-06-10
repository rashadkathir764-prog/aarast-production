import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_controller.dart';
import '../more/screens/more_screen.dart';
import '../tasks/screens/task_timeline_screen.dart';
import '../wedding_plans/models/wedding_plan.dart';
import '../wedding_plans/providers/wedding_plans_provider.dart';
import '../providers/screens/providers_placeholder_screen.dart';
import '../wedding_plans/screens/my_wedding_plans_screen.dart';
import '../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../wedding_plans/widgets/new_dashboard_widgets.dart';

/// App home: a persistent bottom-navigation shell whose tabs (الرئيسية / المهام
/// / الخطط / المزيد) live in an [IndexedStack] so each keeps its state while the
/// nav bar and center add button stay fixed. Detail pages push over the shell.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Tab indices: 0 home, 1 tasks, 2 plans, 3 more.
  int _index = 0;

  /// Plan currently driving the Home + Tasks tabs (defaults to the primary).
  String? _activePlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  WeddingPlan? _primaryPlan(WeddingPlansProvider plans, AuthController auth) {
    if (plans.plans.isEmpty) return null;
    final userId = auth.user?.id;
    for (final plan in plans.plans) {
      if (plan.ownerUserId == userId) return plan;
    }
    return plans.plans.first;
  }

  void _selectPlan(String planId) {
    setState(() {
      _activePlanId = planId;
      _index = 0; // jump to the dashboard for the chosen plan
    });
  }

  void _logout() async {
    await context.read<AuthController>().logout();
    if (mounted) context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final plansProvider = context.watch<WeddingPlansProvider>();
    final auth = context.watch<AuthController>();
    final primary = _primaryPlan(plansProvider, auth);
    final activeId = _activePlanId ?? primary?.id;

    final theme = Theme.of(context);
    final shellTheme = theme.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
    );

    if (activeId == null) {
      return Theme(
        data: shellTheme,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.dBg,
            body: IndexedStack(
              index: _index,
              children: [
                SafeArea(
                  child: RefreshIndicator(
                    color: AppTheme.dMaroon,
                    onRefresh: () => plansProvider.loadMyWeddingPlans(),
                    child: _fallback(plansProvider, auth),
                  ),
                ),
                _requiresPlanTab(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'لا توجد مهام بعد',
                  message: 'أنشئ خطة زفاف أولا حتى تضيف المهام وتتابع الجدول.',
                ),
                MyWeddingPlansScreen(onSelectPlan: _selectPlan),
                const MoreScreen(),
              ],
            ),
            bottomNavigationBar: NewDashboardBottomNav(
              activeIndex: _navSlot,
              onHome: () => _setIndex(0),
              onTasks: () => _setIndex(1),
              onVendors: () => _setIndex(2),
              onMore: () => _setIndex(3),
              onAdd: () => context.push(AppRouter.createWeddingPlan),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: shellTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Scaffold(
              backgroundColor: AppTheme.dBg,
              body: IndexedStack(
                index: _index,
                children: [
                  WeddingPlanDashboardScreen(
                    key: ValueKey('home-$activeId'),
                    weddingPlanId: activeId,
                    embedded: true,
                  ),
                  TaskTimelineScreen(
                    key: ValueKey('tasks-$activeId'),
                    weddingPlanId: activeId,
                  ),
                  const ProvidersPlaceholderScreen(),
                  const MoreScreen(),
                ],
              ),
              bottomNavigationBar: NewDashboardBottomNav(
                activeIndex: _navSlot,
                onHome: () => _setIndex(0),
                onTasks: () => _setIndex(1),
                onVendors: () => _setIndex(2),
                onMore: () => _setIndex(3),
                onAdd: () => _showQuickAdd(activeId),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Map the tab index to the design's nav slot order
  /// (المزيد=0, المهام=1, +, الخطط=3, الرئيسية=4).
  int get _navSlot => switch (_index) {
    0 => 4,
    1 => 1,
    2 => 3,
    3 => 0,
    _ => 4,
  };

  void _setIndex(int i) {
    if (_index != i) setState(() => _index = i);
  }

  Widget _fallback(WeddingPlansProvider plans, AuthController auth) {
    if (plans.isLoading && plans.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.dMaroon));
    }

    if (plans.errorMessage != null && plans.plans.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 140),
          Text(
            plans.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => plans.loadMyWeddingPlans(),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    // No plan yet — welcoming empty state.
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NewDashboardTopHeader(
          userName: auth.user?.name ?? 'ضيف',
          onProfile: () => showAccountSheet(
            context,
            name: auth.user?.name ?? 'مستخدم اعرست',
            phone: auth.user?.phone,
            onLogout: _logout,
          ),
          hasNotificationDot: false,
          onNotifications: () {},
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            decoration: BoxDecoration(
              color: AppTheme.dCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withValues(alpha: 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.dPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.dMaroon,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'لا توجد خطة زفاف بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ابدأ بخطة واحدة تجمع التاريخ والمدينة والميزانية التقديرية، '
                  'ثم تابع كل تجهيزات زفافك من هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppTheme.dInkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.push(AppRouter.createWeddingPlan),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إنشاء خطة زفاف'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _requiresPlanTab({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            decoration: BoxDecoration(
              color: AppTheme.dCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withValues(alpha: 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.dPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.dMaroon, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppTheme.dInkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.push(AppRouter.createWeddingPlan),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إنشاء خطة زفاف'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAdd(String planId) {
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
                    AppRouter.finance(planId),
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة دين',
                    AppRouter.debts(planId),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    AppTheme.dGreen,
                    AppTheme.dGreenBg,
                    'إضافة مهمة',
                    AppRouter.tasks(planId),
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
}
