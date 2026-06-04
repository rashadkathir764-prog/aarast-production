import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

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
    final plan = provider.selectedPlan;

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
  });

  final WeddingPlansProvider provider;
  final WeddingPlan? plan;
  final String weddingPlanId;

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

    return ListView(
      children: [
        _HeaderCard(plan: currentPlan),
        const SizedBox(height: 14),
        _DashboardNavigationCard(
          title: 'الميزانية والمصاريف',
          subtitle: 'تابع تصنيفات الميزانية والمصاريف المرتبطة بالخطة',
          icon: Icons.account_balance_wallet,
          onTap: () => context.go(AppRouter.finance(currentPlan.id)),
        ),
        _DashboardNavigationCard(
          title: 'الديون والأقساط',
          subtitle: 'تابع الديون، المدفوعات، والأقساط المستحقة',
          icon: Icons.payments,
          onTap: () => context.go(AppRouter.debts(currentPlan.id)),
        ),
        const _ComingSoonCard(
          title: 'المهام والجدول الزمني',
          icon: Icons.checklist,
        ),
        const _ComingSoonCard(title: 'المشاركة والصلاحيات', icon: Icons.group),
      ],
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: AppTheme.warmGold.withAlpha(45),
                  child: Icon(icon, color: AppTheme.deepBurgundy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, textAlign: TextAlign.right),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_left),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.warmGold.withAlpha(45),
                child: Icon(icon, color: AppTheme.deepBurgundy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    const Text('قريبا', textAlign: TextAlign.right),
                  ],
                ),
              ),
            ],
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
