import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../../sharing/providers/sharing_provider.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';

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
      context.read<WeddingPlansProvider>().loadWeddingPlan(
        widget.weddingPlanId,
      );
    });
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<WeddingPlansProvider>().loadWeddingPlan(
          widget.weddingPlanId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final auth = context.watch<AuthController>();
    final sharingProvider = context.watch<SharingProvider>();
    final plan = provider.selectedPlan;
    final sharedMember =
        widget.sharedMember ??
        _sharedMemberForPlan(sharingProvider, widget.weddingPlanId);

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة خطة الزفاف')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadWeddingPlan(widget.weddingPlanId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _DashboardContent(
              provider: provider,
              plan: plan?.id == widget.weddingPlanId ? plan : null,
              weddingPlanId: widget.weddingPlanId,
              currentUserId: auth.user?.id,
              sharedMember: sharedMember,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.provider,
    required this.plan,
    required this.weddingPlanId,
    required this.currentUserId,
    required this.sharedMember,
  });

  final WeddingPlansProvider provider;
  final WeddingPlan? plan;
  final String weddingPlanId;
  final String? currentUserId;
  final SharedMember? sharedMember;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && plan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && plan == null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadWeddingPlan(weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final currentPlan = plan;
    if (currentPlan == null) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Text('لم يتم العثور على خطة الزفاف.', textAlign: TextAlign.center),
        ],
      );
    }

    final access = _DashboardAccess.fromPlan(
      plan: currentPlan,
      currentUserId: currentUserId,
      sharedMember: sharedMember,
    );

    return ListView(
      children: [
        _HeaderCard(plan: currentPlan),
        const SizedBox(height: 14),
        if (access.isSharedAccess) ...[
          _SharedAccessNotice(sharedMember: sharedMember!),
          const SizedBox(height: 12),
        ],
        _DashboardNavigationCard(
          title: 'الميزانية والمصاريف',
          subtitle: 'تابع تصنيفات الميزانية والمصاريف المرتبطة بالخطة',
          icon: Icons.account_balance_wallet,
          lockedSubtitle: 'غير متاح حسب صلاحياتك. اطلب صلاحية من صاحب الخطة.',
          onTap: access.canOpenFinance
              ? () => context.go(AppRouter.finance(currentPlan.id))
              : null,
        ),
        _DashboardNavigationCard(
          title: 'الديون والأقساط',
          subtitle: 'تابع الديون، المدفوعات، والأقساط المستحقة',
          icon: Icons.payments,
          lockedSubtitle: 'غير متاح حسب صلاحياتك. اطلب صلاحية من صاحب الخطة.',
          onTap: access.canOpenDebts
              ? () => context.go(AppRouter.debts(currentPlan.id))
              : null,
        ),
        _DashboardNavigationCard(
          title: 'المهام والجدول الزمني',
          subtitle: 'تابع المهام، تواريخ الاستحقاق، والتنبيهات القريبة',
          icon: Icons.checklist,
          lockedSubtitle: 'غير متاح حسب صلاحياتك. اطلب صلاحية من صاحب الخطة.',
          onTap: access.canOpenTasks
              ? () => context.go(AppRouter.tasks(currentPlan.id))
              : null,
        ),
        _DashboardNavigationCard(
          title: 'المشاركة والصلاحيات',
          subtitle: 'أدر أعضاء الخطة وحدد صلاحياتهم بخصوصية مالية واضحة',
          icon: Icons.group,
          lockedSubtitle:
              'إدارة المشاركة متاحة لصاحب الخطة فقط. اطلب تعديل الصلاحيات من صاحب الخطة.',
          onTap: access.canOpenSharing
              ? () => context.go(AppRouter.sharing(currentPlan.id))
              : null,
        ),
      ],
    );
  }
}

SharedMember? _sharedMemberForPlan(
  SharingProvider provider,
  String weddingPlanId,
) {
  for (final plan in provider.sharedPlans) {
    if (plan.id == weddingPlanId) {
      return plan.sharedMember;
    }
  }
  return null;
}

class _DashboardAccess {
  const _DashboardAccess({required this.isOwner, required this.sharedMember});

  factory _DashboardAccess.fromPlan({
    required WeddingPlan plan,
    required String? currentUserId,
    required SharedMember? sharedMember,
  }) {
    return _DashboardAccess(
      isOwner: currentUserId != null && currentUserId == plan.ownerUserId,
      sharedMember: sharedMember,
    );
  }

  final bool isOwner;
  final SharedMember? sharedMember;

  bool get isSharedAccess => !isOwner && sharedMember != null;

  bool get canOpenFinance {
    return isOwner ||
        sharedMember?.canViewBudget == true ||
        sharedMember?.canViewExpenses == true ||
        sharedMember?.canManageFinancialRecords == true;
  }

  bool get canOpenDebts {
    return isOwner ||
        sharedMember?.canViewDebts == true ||
        sharedMember?.canManageFinancialRecords == true;
  }

  bool get canOpenTasks => isOwner || sharedMember != null;

  bool get canOpenSharing => isOwner;
}

class _SharedAccessNotice extends StatelessWidget {
  const _SharedAccessNotice({required this.sharedMember});

  final SharedMember sharedMember;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warmGold.withAlpha(35),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.plan});

  final WeddingPlan plan;

  @override
  Widget build(BuildContext context) {
    final daysRemaining = plan.daysRemaining;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              plan.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            if (plan.city != null)
              _InfoLine(label: 'المدينة', value: plan.city!),
            if (plan.weddingDate != null)
              _InfoLine(
                label: 'تاريخ الزفاف',
                value: _formatDate(plan.weddingDate!),
              ),
            if (daysRemaining != null)
              _InfoLine(
                label: 'الأيام المتبقية',
                value: daysRemaining >= 0
                    ? '$daysRemaining يوم'
                    : 'بدأ موعد الزفاف',
              ),
            if (plan.hasBudget)
              _InfoLine(
                label: 'الميزانية التقديرية',
                value: '${plan.estimatedBudget} ${plan.currency}',
              ),
            _InfoLine(label: 'العملة', value: plan.currency),
            _InfoLine(
              label: 'الحالة',
              value: plan.status == 'ARCHIVED' ? 'مؤرشفة' : 'قيد التخطيط',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardNavigationCard extends StatelessWidget {
  const _DashboardNavigationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.lockedSubtitle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? lockedSubtitle;

  @override
  Widget build(BuildContext context) {
    final isLocked = onTap == null;
    final titleColor = isLocked ? AppTheme.mediumGray : null;
    final iconColor = isLocked ? AppTheme.mediumGray : AppTheme.deepBurgundy;
    final effectiveSubtitle = isLocked
        ? lockedSubtitle ?? 'غير متاح حسب صلاحياتك'
        : subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isLocked
                      ? const Color(0xFFE0E0E0)
                      : AppTheme.warmGold.withAlpha(45),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectiveSubtitle,
                        textAlign: TextAlign.right,
                        style: isLocked
                            ? TextStyle(color: AppTheme.mediumGray)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isLocked ? Icons.lock_outline : Icons.chevron_left,
                  color: isLocked ? AppTheme.mediumGray : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
