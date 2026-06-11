import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  /// When hosted inside the [MainShell] tab stack, the shell owns the bottom
  /// navigation, so the screen hides its own and lets detail pages push over
  /// the persistent shell.
  final bool embedded;

  @override
  State<WeddingPlanDashboardScreen> createState() =>
      _WeddingPlanDashboardScreenState();
}

class _WeddingPlanDashboardScreenState
    extends State<WeddingPlanDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
      );
    });
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DashboardSummaryProvider>().loadDashboard(
          widget.weddingPlanId,
        );
      });
    }
  }

  void _comingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();

    // Use the app-level Arabic type scale and guarantee RTL regardless of the
    // host locale.
    final dashboardTheme = Theme.of(context);

    return Theme(
      data: dashboardTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.dBg,
          bottomNavigationBar: widget.embedded
              ? null
              : _buildBottomNav(provider),
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppTheme.dMaroon,
              onRefresh: () => provider.loadDashboard(widget.weddingPlanId),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(context, provider, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id ?? widget.weddingPlanId;
    return DashboardBottomNav(
      activeIndex: 4,
      onMore: () => _comingSoon('قسم "المزيد" قيد الإعداد'),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => _comingSoon('قسم "الموردين" قيد الإعداد'),
      onHome: () {},
    );
  }

  void _openAccountSheet(AuthController auth) {
    showAccountSheet(
      context,
      name: auth.user?.name ?? 'مستخدم اعرست',
      phone: auth.user?.phone,
      onLogout: () async {
        await context.read<AuthController>().logout();
        if (mounted) context.go(AppRouter.login);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    if (provider.isLoading && provider.plan == null) {
      return ListView(
        key: const ValueKey('skeleton'),
        children: const [DashboardSkeleton()],
      );
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => provider.loadDashboard(widget.weddingPlanId),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null) {
      return ListView(
        key: const ValueKey('empty'),
        children: const [
          SizedBox(height: 120),
          Text('لم يتم العثور على خطة الزفاف.', textAlign: TextAlign.center),
        ],
      );
    }

    final planId = plan.id;
    final allTasks = provider.tasks ?? [];
    final tasksDone = allTasks.where((t) => t.isDone).length;
    final tasksTotal = allTasks.length;
    final totalBudget = dashParseAmount(plan.estimatedBudget);
    final spent = dashParseAmount(provider.expenseSummary?.totalPaid);
    final paymentCount =
        (provider.expenseSummary?.countPaid ?? 0) +
        (provider.expenseSummary?.countPlanned ?? 0);

    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DashboardTopBar(
          userName: auth.user?.name ?? 'ضيف',
          onProfile: () => _openAccountSheet(auth),
          onNotifications: () => _comingSoon('التنبيهات قيد الإعداد'),
        ),
        DashboardHeroCard(
          title: plan.title,
          statusLabel: 'في الموعد',
          tasksDone: tasksDone,
          tasksTotal: tasksTotal,
          city: plan.city,
          weddingDate: plan.weddingDate,
        ),
        const SizedBox(height: 20),
        _padded(
          DashboardSnapshotRow(
            totalBudget: totalBudget,
            spent: spent,
            currency: 'ر.ي',
            tasksDone: tasksDone,
            tasksTotal: tasksTotal,
            vendorCount: 12,
            paymentCount: paymentCount,
            guestCount: 246,
            onBudgetTap: () => context.push(AppRouter.finance(planId)),
          ),
        ),
        const SizedBox(height: 18),
        _padded(
          QuickActionsCard(
            actions: [
              QuickAction(
                icon: Icons.add,
                label: 'إضافة\nمصروف',
                color: AppTheme.dMaroon,
                bg: AppTheme.dPinkBg,
                onTap: () => context.push(AppRouter.createExpense(planId)),
              ),
              QuickAction(
                icon: Icons.check_circle_outline,
                label: 'إضافة\nمهمة',
                color: AppTheme.dGreen,
                bg: AppTheme.dGreenBg,
                onTap: () => context.push(AppRouter.createTask(planId)),
              ),
              QuickAction(
                icon: Icons.credit_card,
                label: 'الديون\nوالأقساط',
                color: AppTheme.dGoldDeep,
                bg: AppTheme.dCreamBg,
                onTap: () => context.push(AppRouter.debts(planId)),
              ),
              QuickAction(
                icon: Icons.groups_outlined,
                label: 'قائمة\nالضيوف',
                color: AppTheme.dBlue,
                bg: AppTheme.dBlueBg,
                onTap: () => _comingSoon('قائمة الضيوف قيد الإعداد'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _padded(
          AlertsCard(
            alerts: const [],
            onViewAll: () => _comingSoon('التنبيهات قيد الإعداد'),
          ),
        ),
        const SizedBox(height: 24),
        _padded(
          SharedPlansCard(
            subtitle: 'لا توجد خطط مشتركة',
            onOpen: () => context.push(AppRouter.sharedWeddingPlans),
          ),
        ),
      ],
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );

  void _showQuickAdd(DashboardSummaryProvider provider) {
    final plan = provider.plan;
    if (plan == null) return;
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
                    AppRouter.finance(plan.id),
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة دين',
                    AppRouter.debts(plan.id),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    AppTheme.dGreen,
                    AppTheme.dGreenBg,
                    'إضافة مهمة',
                    AppRouter.tasks(plan.id),
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
