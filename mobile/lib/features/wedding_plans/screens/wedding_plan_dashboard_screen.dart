import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/dashboard_command_cards.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

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

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadDashboard(widget.weddingPlanId),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildContent(context, provider, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    if (provider.isLoading && provider.plan == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [DashboardLoadingSkeleton()],
      );
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadDashboard(widget.weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Text('لم يتم العثور على خطة الزفاف.', textAlign: TextAlign.center),
        ],
      );
    }

    // Determine actual shared member (passed in or fetched)
    final fetchedMember = provider.sharedMembers?.firstWhere(
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
    final isOwner = auth.user?.id == plan.ownerUserId;
    final activeMember = isOwner ? null : (widget.sharedMember ?? fetchedMember);

    final canOpenFinance = isOwner ||
        activeMember?.canViewBudget == true ||
        activeMember?.canViewExpenses == true ||
        activeMember?.canManageFinancialRecords == true;

    final canOpenDebts = isOwner ||
        activeMember?.canViewDebts == true ||
        activeMember?.canManageFinancialRecords == true;

    final canOpenSharing = isOwner;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeddingHeroSummaryCard(plan: plan),
        const SizedBox(height: 16),
        if (!isOwner && activeMember != null) ...[
          _SharedAccessNotice(sharedMember: activeMember),
          const SizedBox(height: 16),
        ],
        QuickActionsGrid(
          onAddExpense: canOpenFinance ? () => context.go(AppRouter.finance(plan.id)) : null,
          onAddDebt: canOpenDebts ? () => context.go(AppRouter.debts(plan.id)) : null,
          onAddTask: () => context.go(AppRouter.tasks(plan.id)),
          onAddMember: canOpenSharing ? () => context.go(AppRouter.sharing(plan.id)) : null,
        ),
        const SizedBox(height: 16),
        if (canOpenFinance)
          FinancialCommandCard(
            plan: plan,
            expenseSummary: provider.expenseSummary,
            currency: plan.currency,
            onTap: () => context.go(AppRouter.finance(plan.id)),
          )
        else
          const LockedDashboardCard(title: 'الميزانية والمصاريف', icon: Icons.account_balance_wallet),
        const SizedBox(height: 12),
        if (canOpenDebts)
          DebtInstallmentCommandCard(
            debtSummary: provider.debtSummary,
            dueInstallments: provider.dueInstallments,
            currency: plan.currency,
            onTap: () => context.go(AppRouter.debts(plan.id)),
          )
        else
          const LockedDashboardCard(title: 'الديون والأقساط', icon: Icons.payments),
        const SizedBox(height: 12),
        TaskTimelineCommandCard(
          tasks: provider.tasks,
          onTap: () => context.go(AppRouter.tasks(plan.id)),
        ),
        const SizedBox(height: 12),
        if (canOpenSharing)
          SharingMiniCard(
            membersCount: provider.sharedMembers?.length ?? 0,
            onTap: () => context.go(AppRouter.sharing(plan.id)),
          )
        else
          const LockedDashboardCard(title: 'المشاركة والصلاحيات', icon: Icons.group),
      ],
    );
  }
}

class _SharedAccessNotice extends StatelessWidget {
  const _SharedAccessNotice({required this.sharedMember});

  final SharedMember sharedMember;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.warmGold.withAlpha(35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تظهر لك هذه الخطة بصلاحيات محددة من صاحب الخطة.',
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              sharedMember.canManageTasks
                  ? 'يمكنك متابعة المهام والجدول، وإدارة المهام حسب صلاحيتك.'
                  : 'يمكنك متابعة ما أتيح لك فقط. اطلب صلاحية إضافية من صاحب الخطة عند الحاجة.',
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
