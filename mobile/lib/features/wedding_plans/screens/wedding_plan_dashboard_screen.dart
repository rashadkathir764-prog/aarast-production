import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  /// Fixed design width of the reference dashboard handoff. The whole canvas is
  /// laid out at this width and uniformly scaled to the viewport via [FittedBox],
  /// so every size matches the maquette on any screen. Height is intrinsic (no
  /// fixed height) so the content can never RenderFlex-overflow.
  static const double _dashboardDesignWidth = 680;

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

    // Apply the design's Tajawal type scale over the dashboard subtree, and
    // guarantee RTL regardless of the host locale.
    final theme = Theme.of(context);
    final dashboardTheme = theme.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
    );

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

  DashboardBottomNav _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id ?? widget.weddingPlanId;
    return DashboardBottomNav(
      onMore: () => _comingSoon('قسم "المزيد" قيد الإعداد'),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => context.go(AppRouter.weddingPlans),
      onHome: () => context.go(AppRouter.home),
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
      return const DashboardSkeleton(key: ValueKey('skeleton'));
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

    final isOwner = auth.user?.id == plan.ownerUserId;
    final activeMember = isOwner ? null : _resolveMember(provider, auth);

    final canOpenFinance =
        isOwner ||
        activeMember?.canViewBudget == true ||
        activeMember?.canViewExpenses == true ||
        activeMember?.canManageFinancialRecords == true;
    final canOpenDebts =
        isOwner ||
        activeMember?.canViewDebts == true ||
        activeMember?.canManageFinancialRecords == true;
    final canOpenSharing = isOwner;

    final participantsColumn = canOpenSharing
        ? ParticipantsCard(
            participants: _buildParticipants(provider),
            count: provider.sharedMembers?.length ?? 0,
            onAddMember: () => context.push(AppRouter.sharing(plan.id)),
          )
        : const LockedSectionCard(
            title: 'المشاركون في الخطة',
            icon: Icons.groups_rounded,
          );

    return _scaledDashboardCanvas(
      key: const ValueKey('content'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardTopBar(
            userName: auth.user?.name ?? 'ضيف',
            onProfile: () => _openAccountSheet(auth),
            onNotifications: () => _comingSoon('مركز التنبيهات قيد الإعداد'),
          ),
          DashboardHeroCard(
            title: plan.title,
            statusLabel: plan.status == 'ARCHIVED' ? 'مؤرشفة' : 'قيد التخطيط',
            tasksDone: _tasksDone(provider),
            tasksTotal: _tasksTotal(provider),
            city: plan.city,
            weddingDate: plan.weddingDate,
          ),
          const SizedBox(height: 18),
          if (!isOwner && activeMember != null) ...[
            _sharedNotice(activeMember),
            const SizedBox(height: 16),
          ],
          // Row 1 — budget summary (right) + compact stats (left).
          _padded(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: canOpenFinance
                      ? _buildBudgetCard(provider, plan, canOpenDebts)
                      : const LockedSectionCard(
                          title: 'ملخص الميزانية',
                          icon: Icons.savings_outlined,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 9,
                  child: _buildMiniStats(provider, plan, canOpenDebts),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _padded(
            _buildQuickActions(
              plan,
              canOpenFinance,
              canOpenDebts,
              canOpenSharing,
            ),
          ),
          const SizedBox(height: 18),
          // Row 2 — participants + shared plans (right) · important alerts (left).
          _padded(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      participantsColumn,
                      const SizedBox(height: 16),
                      SharedPlansCard(
                        onOpen: () =>
                            context.push(AppRouter.sharedWeddingPlans),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AlertsCard(
                    alerts: _buildAlerts(
                      provider,
                      plan,
                      canOpenFinance,
                      canOpenDebts,
                    ),
                    onViewAll: () => context.push(AppRouter.tasks(plan.id)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _scaledDashboardCanvas({required Key key, required Widget child}) {
    // Lay the whole dashboard out at the fixed design width and let height be
    // intrinsic, then uniformly down-scale to the viewport. BoxFit.contain on a
    // width-bounded / height-unbounded box scales by viewportWidth / designWidth,
    // so the maquette renders identically (just smaller) on every size and the
    // inner Column can never overflow.
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _dashboardDesignWidth,
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: _dashboardDesignWidth,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );

  SharedMember? _resolveMember(
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    if (widget.sharedMember != null) return widget.sharedMember;
    return provider.sharedMembers?.firstWhere(
      (m) => m.user?.phone != null && m.user?.phone == auth.user?.phone,
      orElse: () => SharedMember(
        id: '',
        weddingPlanId: '',
        userId: auth.user?.id ?? '',
        role: 'VIEWER',
        canViewBudget: false,
        canViewExpenses: false,
        canViewDebts: false,
        canManageTasks: false,
        canManageFinancialRecords: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ---- Derived data -------------------------------------------------------

  List<WeddingTask> _allTasks(DashboardSummaryProvider p) =>
      p.tasks ?? const [];
  int _tasksTotal(DashboardSummaryProvider p) => _allTasks(p).length;
  int _tasksDone(DashboardSummaryProvider p) =>
      _allTasks(p).where((t) => t.isDone).length;

  WeddingTask? _nearestTask(DashboardSummaryProvider p) {
    final pending =
        _allTasks(p).where((t) => !t.isDone && t.dueDate != null).toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return pending.isEmpty ? null : pending.first;
  }

  Installment? _nearestInstallment(DashboardSummaryProvider p) {
    final due = List<Installment>.from(p.dueInstallments ?? const [])
      ..sort((a, b) {
        final ad = a.dueDate;
        final bd = b.dueDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return due.isEmpty ? null : due.first;
  }

  Widget _buildMiniStats(
    DashboardSummaryProvider provider,
    WeddingPlan plan,
    bool canOpenDebts,
  ) {
    final pendingCount = _allTasks(provider).where((t) => !t.isDone).length;
    final nearestTask = _nearestTask(provider);
    final dueInstallments = provider.dueInstallments ?? const [];
    final nearestInstallment = _nearestInstallment(provider);
    final debt = provider.debtSummary;

    final taskMini = MiniStatCard(
      icon: Icons.assignment_turned_in_outlined,
      iconColor: AppTheme.dGreen,
      iconBg: AppTheme.dGreenBg,
      title: 'المهام القادمة',
      bigValue: '$pendingCount',
      unit: 'مهمة',
      subLabel: nearestTask != null ? 'أقرب مهمة' : null,
      subValue: nearestTask?.title,
      subValueColor: AppTheme.dInk,
      subSecondary: nearestTask?.dueDate != null
          ? dashFormatArDate(nearestTask!.dueDate!)
          : null,
    );

    final installmentMini = MiniStatCard(
      icon: Icons.calendar_month_outlined,
      iconColor: AppTheme.dMaroon,
      iconBg: AppTheme.dPinkBg,
      title: 'الأقساط القريبة',
      bigValue: '${dueInstallments.length}',
      unit: 'قسط',
      locked: !canOpenDebts,
      subLabel: nearestInstallment != null ? 'المبلغ' : null,
      subValue: nearestInstallment != null
          ? '${dashFormatMoney(dashParseAmount(nearestInstallment.amount))} ${plan.currency}'
          : null,
      subValueColor: AppTheme.dOrange,
      subSecondary: nearestInstallment?.dueDate != null
          ? dashFormatArDate(nearestInstallment!.dueDate!)
          : null,
    );

    final debtMini = MiniStatCard(
      icon: Icons.credit_card_rounded,
      iconColor: AppTheme.dMaroon,
      iconBg: AppTheme.dPinkBg,
      title: 'الديون',
      bigValue: debt != null
          ? dashFormatMoney(dashParseAmount(debt.totalDebt))
          : '0',
      unit: plan.currency,
      locked: !canOpenDebts,
      subLabel: 'المتبقي',
      subValue: debt != null
          ? '${dashFormatMoney(dashParseAmount(debt.remainingDebt))} ${plan.currency}'
          : null,
      subValueColor: AppTheme.dMaroon,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: taskMini),
          const SizedBox(width: 12),
          Expanded(child: installmentMini),
          const SizedBox(width: 12),
          Expanded(child: debtMini),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    DashboardSummaryProvider provider,
    WeddingPlan plan,
    bool canOpenDebts,
  ) {
    final total = dashParseAmount(plan.estimatedBudget);
    final spent = dashParseAmount(provider.expenseSummary?.totalPaid);
    final obligations = canOpenDebts
        ? dashParseAmount(provider.debtSummary?.remainingDebt)
        : 0.0;
    final debtsTotal = canOpenDebts
        ? dashParseAmount(provider.debtSummary?.totalDebt)
        : 0.0;
    final upcomingInstallments = canOpenDebts
        ? (provider.dueInstallments ?? const <Installment>[]).fold<double>(
            0,
            (sum, inst) => sum + dashParseAmount(inst.amount),
          )
        : 0.0;
    return BudgetSummaryCard(
      total: total,
      spent: spent,
      obligations: obligations,
      debtsTotal: debtsTotal,
      upcomingInstallments: upcomingInstallments,
      currency: plan.currency,
    );
  }

  Widget _buildQuickActions(
    WeddingPlan plan,
    bool canOpenFinance,
    bool canOpenDebts,
    bool canOpenSharing,
  ) {
    return QuickActionsCard(
      actions: [
        QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'إضافة مصروف',
          color: AppTheme.dMaroon,
          bg: AppTheme.dPinkBg,
          onTap: canOpenFinance
              ? () => context.push(AppRouter.finance(plan.id))
              : null,
        ),
        QuickAction(
          icon: Icons.credit_card_rounded,
          label: 'إضافة دين',
          color: AppTheme.dMaroon,
          bg: AppTheme.dPinkBg,
          onTap: canOpenDebts
              ? () => context.push(AppRouter.debts(plan.id))
              : null,
        ),
        QuickAction(
          icon: Icons.check_circle_outline_rounded,
          label: 'إضافة مهمة',
          color: AppTheme.dGreen,
          bg: AppTheme.dGreenBg,
          onTap: () => context.push(AppRouter.tasks(plan.id)),
        ),
        QuickAction(
          icon: Icons.person_add_alt_1_rounded,
          label: 'إضافة عضو',
          color: AppTheme.dBlue,
          bg: AppTheme.dBlueBg,
          onTap: canOpenSharing
              ? () => context.push(AppRouter.sharing(plan.id))
              : null,
        ),
        QuickAction(
          icon: Icons.post_add_rounded,
          label: 'خطة جديدة',
          color: AppTheme.dGoldDeep,
          bg: AppTheme.dCreamBg,
          onTap: () => context.push(AppRouter.createWeddingPlan),
        ),
      ],
    );
  }

  List<DashboardAlert> _buildAlerts(
    DashboardSummaryProvider provider,
    WeddingPlan plan,
    bool canOpenFinance,
    bool canOpenDebts,
  ) {
    final alerts = <DashboardAlert>[];

    // 1) Upcoming installment due soon
    final installment = _nearestInstallment(provider);
    if (canOpenDebts && installment != null && installment.dueDate != null) {
      final days = installment.dueDate!
          .difference(DateTime.now())
          .inDays
          .clamp(0, 9999);
      final amount = dashFormatMoney(dashParseAmount(installment.amount));
      alerts.add(
        DashboardAlert(
          title: 'قسط قريب الاستحقاق',
          body: 'لديك قسط بقيمة $amount ${plan.currency} يستحق خلال $days أيام',
          icon: Icons.calendar_today_outlined,
          tone: AlertTone.pink,
        ),
      );
    }

    // 2) High spending against budget
    final total = dashParseAmount(plan.estimatedBudget);
    final spent = dashParseAmount(provider.expenseSummary?.totalPaid);
    if (canOpenFinance && total > 0) {
      final pct = (spent / total * 100).round();
      if (pct >= 80) {
        alerts.add(
          DashboardAlert(
            title: 'مصروفات مرتفعة',
            body: 'لقد وصلت المصروفات إلى $pct% من إجمالي الميزانية',
            icon: Icons.trending_up_rounded,
            tone: AlertTone.cream,
          ),
        );
      }
    }

    // 3) Task due soon (within a week)
    final task = _nearestTask(provider);
    if (task != null && task.dueDate != null) {
      final days = task.dueDate!.difference(DateTime.now()).inDays;
      if (days <= 7) {
        alerts.add(
          DashboardAlert(
            title: 'مهمة قريبة',
            body: '${task.title} بتاريخ ${dashFormatArDate(task.dueDate!)}',
            icon: Icons.checklist_rounded,
            tone: AlertTone.green,
          ),
        );
      }
    }

    return alerts;
  }

  List<ParticipantInfo> _buildParticipants(DashboardSummaryProvider provider) {
    final members = provider.sharedMembers ?? const <SharedMember>[];
    return members.take(4).map((m) {
      return ParticipantInfo(
        name: m.displayName,
        phone: m.user?.phone,
        roleLabel: sharedMemberRoleLabel(m.role),
        isManager: m.role == 'MANAGER',
      );
    }).toList();
  }

  // ---- Quick-add sheet ----------------------------------------------------

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

  Widget _sharedNotice(SharedMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.dCreamBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dGold.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تظهر لك هذه الخطة بصلاحيات محددة من صاحب الخطة.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.dGoldDeep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              member.canManageTasks
                  ? 'يمكنك متابعة المهام والجدول، وإدارة المهام حسب صلاحيتك.'
                  : 'يمكنك متابعة ما أتيح لك فقط. اطلب صلاحية إضافية عند الحاجة.',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: AppTheme.dInkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
