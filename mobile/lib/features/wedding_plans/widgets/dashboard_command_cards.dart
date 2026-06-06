import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../debts/models/debt_summary.dart';
import '../../debts/models/installment.dart';
import '../../finance/models/expense_summary.dart';
import '../../tasks/models/wedding_task.dart';
import '../models/wedding_plan.dart';

class WeddingHeroSummaryCard extends StatelessWidget {
  const WeddingHeroSummaryCard({required this.plan, super.key});

  final WeddingPlan plan;

  @override
  Widget build(BuildContext context) {
    final daysRemaining = plan.daysRemaining ?? 0;
    final isPast = daysRemaining < 0;

    return Card(
      elevation: 4,
      shadowColor: AppTheme.warmGold.withAlpha(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppTheme.deepBurgundy, Color(0xFF5A1A28)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (plan.city != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.warmGold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              plan.city!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    plan.status == 'ARCHIVED' ? 'مؤرشفة' : 'قيد التخطيط',
                    style: const TextStyle(color: AppTheme.warmGold, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HeroStat(
                  label: 'الأيام المتبقية',
                  value: isPast ? 'انتهى' : '$daysRemaining',
                  icon: Icons.calendar_today,
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                _HeroStat(
                  label: 'الميزانية',
                  value: plan.hasBudget ? plan.estimatedBudget! : '-',
                  icon: Icons.account_balance_wallet,
                  subtitle: plan.currency,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.icon, this.subtitle});

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.warmGold, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Text(subtitle!, style: const TextStyle(color: AppTheme.warmGold, fontSize: 10)),
            ],
          ],
        ),
      ],
    );
  }
}

class FinancialCommandCard extends StatelessWidget {
  const FinancialCommandCard({
    required this.plan,
    required this.expenseSummary,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final WeddingPlan plan;
  final ExpenseSummary? expenseSummary;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spent = expenseSummary != null ? double.tryParse(expenseSummary!.totalPaid) ?? 0 : 0;
    final total = double.tryParse(plan.estimatedBudget ?? '0') ?? 0;
    final double progress = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.warmGold.withAlpha(45),
                    child: const Icon(Icons.account_balance_wallet, color: AppTheme.deepBurgundy),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'الملخص المالي',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: AppTheme.mediumGray),
                ],
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي المصروفات', style: TextStyle(color: AppTheme.charcoal)),
                          Text(
                            '${expenseSummary?.totalPaid ?? '0.00'} $currency',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deepBurgundy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.grey.shade200,
                        color: value > 0.9 ? Colors.red : AppTheme.warmGold,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${(value * 100).toStringAsFixed(1)}% مستهلك', style: const TextStyle(fontSize: 12)),
                          Text(
                            'الميزانية: ${plan.estimatedBudget ?? '0.00'} $currency',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mediumGray),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DebtInstallmentCommandCard extends StatelessWidget {
  const DebtInstallmentCommandCard({
    required this.debtSummary,
    required this.dueInstallments,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final DebtSummary? debtSummary;
  final List<Installment>? dueInstallments;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dueCount = dueInstallments?.length ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.withAlpha(40),
                    child: const Icon(Icons.payments, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'الديون والأقساط',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  if (dueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '$dueCount مستحق',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left, color: AppTheme.mediumGray),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBox(
                    label: 'الديون المتبقية',
                    value: debtSummary?.remainingDebt ?? '0.00',
                    currency: currency,
                    color: Colors.red.shade700,
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade300),
                  _StatBox(
                    label: 'تم سداده',
                    value: debtSummary?.totalPaid ?? '0.00',
                    currency: currency,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.currency, required this.color});
  final String label;
  final String value;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mediumGray)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 4),
            Text(currency, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ],
    );
  }
}

class TaskTimelineCommandCard extends StatelessWidget {
  const TaskTimelineCommandCard({
    required this.tasks,
    required this.onTap,
    super.key,
  });

  final List<WeddingTask>? tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pendingCount = tasks?.where((t) => t.status != 'DONE').length ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withAlpha(40),
                child: const Icon(Icons.checklist, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المهام والجدول', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      pendingCount > 0 ? 'لديك $pendingCount مهام غير منجزة' : 'جميع المهام منجزة',
                      style: TextStyle(color: pendingCount > 0 ? AppTheme.charcoal : Colors.green),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppTheme.mediumGray),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    required this.onAddExpense,
    required this.onAddDebt,
    required this.onAddTask,
    required this.onAddMember,
    super.key,
  });

  final VoidCallback? onAddExpense;
  final VoidCallback? onAddDebt;
  final VoidCallback? onAddTask;
  final VoidCallback? onAddMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('إجراءات سريعة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        Row(
          children: [
            if (onAddExpense != null)
              Expanded(child: _QuickActionButton(icon: Icons.receipt_long, label: 'مصروف', onTap: onAddExpense!)),
            if (onAddDebt != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _QuickActionButton(icon: Icons.money_off, label: 'دين', onTap: onAddDebt!)),
            ],
            if (onAddTask != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _QuickActionButton(icon: Icons.add_task, label: 'مهمة', onTap: onAddTask!)),
            ],
            if (onAddMember != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _QuickActionButton(icon: Icons.person_add, label: 'عضو', onTap: onAddMember!)),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});
  
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.deepBurgundy),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class LockedDashboardCard extends StatelessWidget {
  const LockedDashboardCard({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: Icon(icon, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('غير متاح حسب صلاحياتك', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.lock_outline, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class DashboardLoadingSkeleton extends StatelessWidget {
  const DashboardLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonBox(height: 180, borderRadius: 16),
        const SizedBox(height: 16),
        _SkeletonBox(height: 120, borderRadius: 16),
        const SizedBox(height: 16),
        _SkeletonBox(height: 100, borderRadius: 16),
        const SizedBox(height: 16),
        _SkeletonBox(height: 80, borderRadius: 16),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height, required this.borderRadius});
  final double height;
  final double borderRadius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class SharingMiniCard extends StatelessWidget {
  const SharingMiniCard({required this.membersCount, required this.onTap, super.key});
  
  final int membersCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.withAlpha(40),
                child: const Icon(Icons.group, color: Colors.purple),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المشاركة والصلاحيات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '$membersCount عضو(ين) مشارك(ين)',
                      style: const TextStyle(color: AppTheme.charcoal),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppTheme.mediumGray),
            ],
          ),
        ),
      ),
    );
  }
}
