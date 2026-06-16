import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../debts/models/installment.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import '../models/wedding_plan.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6EF),
        bottomNavigationBar: widget.embedded ? null : _buildBottomNav(provider),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: const Color(0xFF8A0032),
            onRefresh: () => provider.loadDashboard(widget.weddingPlanId),
            child: _buildContent(context, provider, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id ?? widget.weddingPlanId;
    return DashboardBottomNav(
      activeIndex: 4,
      onMore: () => context.go(AppRouter.home),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => context.push(AppRouter.providerMarketplace),
      onHome: () {},
    );
  }

  void _openAccountSheet(AuthController auth) {
    showAccountSheet(
      context,
      name: auth.user?.name ?? 'مستخدم اعّرست',
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
    final bottomPadding = widget.embedded ? 110.0 : 140.0;

    if (provider.isLoading && provider.plan == null) {
      return ListView(
        key: const ValueKey('skeleton'),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
        children: const [DashboardUxLoading()],
      );
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        key: const ValueKey('error'),
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding),
        children: [
          DashboardUxEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل اللوحة',
            message: provider.errorMessage!,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8A0032),
                side: const BorderSide(color: Color(0xFFEFE4DA)),
              ),
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
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding),
        children: const [
          DashboardUxEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'لا توجد خطة',
            message: 'لم يتم العثور على خطة الزفاف الحالية.',
          ),
        ],
      );
    }

    final planId = plan.id;
    final tasks = provider.tasks ?? [];
    final tasksDone = tasks.where((task) => task.isDone).length;
    final tasksTotal = tasks.length;
    final totalBudget = dashParseAmount(plan.estimatedBudget);
    final spent = dashParseAmount(provider.expenseSummary?.totalPaid);
    final dueInstallments = provider.dueInstallments ?? [];
    final sharedMembers = provider.sharedMembers ?? [];
    final progressPercent = tasksTotal == 0
        ? 0
        : ((tasksDone / tasksTotal) * 100).round().clamp(0, 100);
    final budgetPercent = totalBudget <= 0
        ? 0
        : ((spent / totalBudget) * 100).round().clamp(0, 100);

    return ListView(
      key: const ValueKey('content'),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      children: [
        DashboardUxHeader(
          userName: auth.user?.name ?? 'ضيف',
          onNotifications: () =>
              context.push(AppRouter.planNotifications(planId)),
          onProfile: () => _openAccountSheet(auth),
        ),
        const DashboardUxOfflineBanner(),
        const SizedBox(height: 10),
        DashboardUxPlanCard(
          title: plan.title,
          city: plan.city,
          weddingDate: plan.weddingDate,
          progressPercent: progressPercent,
          tasksDone: tasksDone,
          tasksTotal: tasksTotal,
          daysRemaining: plan.daysRemaining,
          onContinue: () => context.push(AppRouter.tasks(planId)),
        ),
        const SizedBox(height: 10),
        DashboardUxStatsSection(
          stats: [
            DashboardUxStat(
              icon: Icons.checklist_rounded,
              label: 'المهام',
              value: tasksTotal == 0 ? '0' : '$tasksDone/$tasksTotal',
              helper: 'مكتملة',
              onTap: () => context.push(AppRouter.tasks(planId)),
            ),
            DashboardUxStat(
              icon: Icons.account_balance_wallet_outlined,
              label: 'الميزانية',
              value: totalBudget <= 0 ? 'غير محددة' : '$budgetPercent%',
              helper: totalBudget <= 0 ? 'أضف الميزانية' : 'مستخدمة',
              onTap: () => _openFinanceOverview(provider, planId),
            ),
            DashboardUxStat(
              icon: Icons.storefront_outlined,
              label: 'الموردين',
              value: 'تصفح',
              helper: 'السوق',
              onTap: () => context.push(AppRouter.providerMarketplace),
            ),
            DashboardUxStat(
              icon: Icons.groups_2_outlined,
              label: 'الضيوف',
              value: 'محلي',
              helper: 'مؤقت',
              onTap: () => context.push(AppRouter.guestList(planId)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DashboardUxActionsSection(
          actions: [
            DashboardUxAction(
              icon: Icons.check_circle_outline_rounded,
              label: 'إضافة مهمة',
              onTap: () => context.push(AppRouter.createTask(planId)),
            ),
            DashboardUxAction(
              icon: Icons.account_balance_wallet_outlined,
              label: 'إضافة نفقة',
              onTap: () => _openExpenseForm(provider, planId),
            ),
            DashboardUxAction(
              icon: Icons.person_add_alt_1_outlined,
              label: 'إضافة ضيف',
              onTap: () => context.push(AppRouter.guestList(planId)),
            ),
            DashboardUxAction(
              icon: Icons.storefront_outlined,
              label: 'إضافة مورد',
              onTap: () => context.push(AppRouter.providerMarketplace),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DashboardUxUpcomingSection(
          items: _buildUpcomingItems(planId, tasks, dueInstallments, plan),
        ),
        const SizedBox(height: 10),
        DashboardUxSharedPlanCard(
          participantCount: sharedMembers.length,
          participantNames: sharedMembers
              .take(3)
              .map((member) => member.displayName)
              .toList(),
          onOpen: () => context.push(AppRouter.sharing(planId)),
        ),
      ],
    );
  }

  List<DashboardUxUpcomingItem> _buildUpcomingItems(
    String planId,
    List<WeddingTask> tasks,
    List<Installment> installments,
    WeddingPlan plan,
  ) {
    final entries = <_UpcomingEntry>[];

    final upcomingTasks =
        tasks.where((task) => !task.isDone && task.dueDate != null).toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    for (final task in upcomingTasks.take(2)) {
      entries.add(
        _UpcomingEntry(
          date: task.dueDate!,
          item: DashboardUxUpcomingItem(
            icon: Icons.check_circle_outline_rounded,
            title: task.title,
            meta: dashFormatArDate(task.dueDate!),
            onTap: () => context.push(AppRouter.tasks(planId)),
          ),
        ),
      );
    }

    final upcomingInstallments =
        installments
            .where((installment) => installment.dueDate != null)
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    for (final installment in upcomingInstallments.take(1)) {
      entries.add(
        _UpcomingEntry(
          date: installment.dueDate!,
          item: DashboardUxUpcomingItem(
            icon: Icons.payments_outlined,
            title: 'قسط مستحق',
            meta: dashFormatArDate(installment.dueDate!),
            onTap: () => context.push(AppRouter.debts(planId)),
          ),
        ),
      );
    }

    if (entries.isEmpty && plan.weddingDate != null) {
      entries.add(
        _UpcomingEntry(
          date: plan.weddingDate!,
          item: DashboardUxUpcomingItem(
            icon: Icons.event_available_outlined,
            title: 'موعد الزفاف',
            meta: dashFormatArDate(plan.weddingDate!),
            onTap: () => context.push(AppRouter.tasks(planId)),
          ),
        ),
      );
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries.map((entry) => entry.item).take(3).toList();
  }

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
          String route, {
          bool refreshDashboard = false,
        }) {
          return ListTile(
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final changed = await context.push<bool>(route);
              if (refreshDashboard && changed == true && mounted) {
                await provider.loadDashboard(plan.id);
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
                    AppRouter.createExpense(plan.id),
                    refreshDashboard: true,
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة دين',
                    AppRouter.createDebt(plan.id),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    AppTheme.dGreen,
                    AppTheme.dGreenBg,
                    'إضافة مهمة',
                    AppRouter.createTask(plan.id),
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

  Future<void> _openExpenseForm(
    DashboardSummaryProvider provider,
    String planId,
  ) async {
    final changed = await context.push<bool>(AppRouter.createExpense(planId));
    if (changed == true && mounted) {
      await provider.loadDashboard(planId);
    }
  }

  Future<void> _openFinanceOverview(
    DashboardSummaryProvider provider,
    String planId,
  ) async {
    final changed = await context.push<bool>(AppRouter.finance(planId));
    if (changed == true && mounted) {
      await provider.loadDashboard(planId);
    }
  }
}

class _UpcomingEntry {
  const _UpcomingEntry({required this.date, required this.item});

  final DateTime date;
  final DashboardUxUpcomingItem item;
}
