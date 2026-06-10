import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';

class MyWeddingPlansScreen extends StatefulWidget {
  const MyWeddingPlansScreen({this.onSelectPlan, super.key});

  /// When provided (e.g. hosted inside the shell's "الخطط" tab), tapping a plan
  /// selects it for the shell instead of navigating to a standalone dashboard.
  final void Function(String planId)? onSelectPlan;

  @override
  State<MyWeddingPlansScreen> createState() => _MyWeddingPlansScreenState();
}

class _MyWeddingPlansScreenState extends State<MyWeddingPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final weddingPlans = context.watch<WeddingPlansProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('خطط الزفاف')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.createWeddingPlan),
        backgroundColor: AppTheme.dMaroon,
        foregroundColor: Colors.white,
        label: const Text('إنشاء خطة زفاف'),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: weddingPlans.loadMyWeddingPlans,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _PlansContent(
              weddingPlans: weddingPlans,
              onSelectPlan: widget.onSelectPlan,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlansContent extends StatelessWidget {
  const _PlansContent({required this.weddingPlans, this.onSelectPlan});

  final WeddingPlansProvider weddingPlans;
  final void Function(String planId)? onSelectPlan;

  @override
  Widget build(BuildContext context) {
    if (weddingPlans.isLoading && weddingPlans.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (weddingPlans.errorMessage != null && weddingPlans.plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            weddingPlans.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: weddingPlans.loadMyWeddingPlans,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    if (weddingPlans.plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'لا توجد خطة زفاف بعد',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ابدأ بخطة واحدة تجمع التاريخ والمدينة والميزانية التقديرية.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.push(AppRouter.createWeddingPlan),
                    child: const Text('إنشاء خطة زفاف'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: weddingPlans.plans.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = weddingPlans.plans[index];
        return _WeddingPlanCard(plan: plan, onSelectPlan: onSelectPlan);
      },
    );
  }
}

class _WeddingPlanCard extends StatelessWidget {
  const _WeddingPlanCard({required this.plan, this.onSelectPlan});

  final WeddingPlan plan;
  final void Function(String planId)? onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectPlan != null
            ? onSelectPlan!(plan.id)
            : context.go(AppRouter.weddingPlanDashboard(plan.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: plan.status),
                ],
              ),
              const SizedBox(height: 10),
              if (plan.city != null)
                _InfoLine(label: 'المدينة', value: plan.city!),
              if (plan.weddingDate != null)
                _InfoLine(
                  label: 'تاريخ الزفاف',
                  value: _formatDate(plan.weddingDate!),
                ),
              if (plan.hasBudget)
                _InfoLine(
                  label: 'الميزانية التقديرية',
                  value: '${plan.estimatedBudget} ${plan.currency}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status == 'ARCHIVED' ? 'مؤرشفة' : 'قيد التخطيط'),
      backgroundColor: AppTheme.dGold.withAlpha(45),
      side: BorderSide.none,
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
      padding: const EdgeInsets.only(top: 4),
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
