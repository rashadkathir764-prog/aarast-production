import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_dashboard_provider.dart';

class HomeCommandHero extends StatelessWidget {
  const HomeCommandHero({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;

    if (plan == null) {
      return Card(
        color: AppTheme.deepBurgundy,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ابدأ بإنشاء خطة زفافك الأولى',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.warmGold,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                'أنشئ خطة لتتبع الميزانية والمهام والديون.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRouter.createWeddingPlan),
                icon: const Icon(Icons.add),
                label: const Text('إنشاء خطة زفاف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warmGold,
                  foregroundColor: AppTheme.deepBurgundy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMMM yyyy', 'ar');
    final dateStr = plan.weddingDate != null
        ? dateFormat.format(plan.weddingDate!)
        : 'غير محدد';

    int? daysRemaining;
    if (plan.weddingDate != null) {
      daysRemaining = plan.weddingDate!.difference(DateTime.now()).inDays;
      if (daysRemaining < 0) daysRemaining = 0;
    }

    final tasks = provider.tasks ?? [];
    final completedTasks = tasks.where((t) => t.isDone).length;
    final totalTasks = tasks.length;
    double progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final progressPct = (progress * 100).toInt();

    return Card(
      color: AppTheme.deepBurgundy,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Background soft decoration
          Positioned(
            left: -40,
            bottom: -40,
            child: Icon(
              Icons.favorite,
              size: 150,
              color: Colors.white.withAlpha(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppTheme.warmGold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                plan.city ?? 'غير محدد',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.calendar_today, color: AppTheme.warmGold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Progress Circle
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, _) {
                              return CircularProgressIndicator(
                                value: value,
                                color: AppTheme.warmGold,
                                backgroundColor: Colors.white24,
                                strokeWidth: 8,
                              );
                            },
                          ),
                          Center(
                            child: Text(
                              '$progressPct%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Days Remaining & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (daysRemaining != null)
                            Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.white70, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'متبقي $daysRemaining يوم',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warmGold.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.track_changes, color: AppTheme.warmGold, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  plan.status == 'PLANNING' ? 'قيد التخطيط' : (plan.status == 'COMPLETED' ? 'مكتمل' : plan.status),
                                  style: const TextStyle(color: AppTheme.warmGold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedTasks من $totalTasks مهام مكتملة',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(AppRouter.weddingPlanDashboard(plan.id)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('فتح لوحة التحكم'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMetricGrid extends StatelessWidget {
  const HomeMetricGrid({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.primaryPlan == null) return const SizedBox.shrink();

    final expense = provider.expenseSummary;
    final debt = provider.debtSummary;
    final installments = provider.dueInstallments ?? [];
    final tasks = provider.tasks ?? [];
    final upcomingTasks = tasks.where((t) => !t.isDone).length;

    final numberFormat = NumberFormat('#,###');

    final totalBudget = double.tryParse(expense?.totalPlanned ?? '0') ?? 0.0;
    final totalSpent = double.tryParse(expense?.totalPaid ?? '0') ?? 0.0;
    final remainingBudget = totalBudget - totalSpent;

    final spentPct = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    final remainingPct = totalBudget > 0 ? (remainingBudget / totalBudget) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Budget Breakdown Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: AppTheme.warmGold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'الميزانية الكلية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Text(
                        '${numberFormat.format(totalBudget)} YER',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Custom Linear Breakdown
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (spentPct * 100).toInt() > 0 ? (spentPct * 100).toInt() : 1,
                            child: Container(color: AppTheme.deepBurgundy),
                          ),
                          Expanded(
                            flex: (remainingPct * 100).toInt() > 0 ? (remainingPct * 100).toInt() : 1,
                            child: Container(color: Colors.grey.shade300),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('المصروف', numberFormat.format(totalSpent), AppTheme.deepBurgundy),
                      _buildMiniStat('المتبقي', numberFormat.format(remainingBudget), Colors.grey.shade600),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  context,
                  icon: Icons.money_off,
                  title: 'الديون',
                  value: numberFormat.format(debt?.totalDebt ?? 0),
                  subtitle: 'متبقي: ${numberFormat.format(debt?.remainingDebt ?? 0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  context,
                  icon: Icons.event_note,
                  title: 'الأقساط القريبة',
                  value: '${installments.length}',
                  subtitle: 'قسط',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  context,
                  icon: Icons.check_circle_outline,
                  title: 'المهام القادمة',
                  value: '$upcomingTasks',
                  subtitle: 'مهمة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String value, required String subtitle}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.warmGold, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black38), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasPlan = provider.primaryPlan != null;
    final planId = provider.primaryPlan?.id ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إجراءات سريعة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.add_box,
                  label: 'خطة جديدة',
                  onTap: () => context.push(AppRouter.createWeddingPlan),
                  enabled: true,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.person_add,
                  label: 'إضافة عضو',
                  onTap: () => context.push(AppRouter.addSharedMember(planId)),
                  enabled: hasPlan,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.task_alt,
                  label: 'إضافة مهمة',
                  onTap: () => context.push(AppRouter.createTask(planId)),
                  enabled: hasPlan,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.credit_card,
                  label: 'إضافة دين',
                  onTap: () => context.push(AppRouter.createDebt(planId)),
                  enabled: hasPlan,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.receipt_long,
                  label: 'إضافة مصروف',
                  onTap: () => context.push(AppRouter.createExpense(planId)),
                  enabled: hasPlan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            width: 80,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.deepBurgundy, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeAlertsCard extends StatelessWidget {
  const HomeAlertsCard({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.primaryPlan == null) return const SizedBox.shrink();

    final alerts = <Widget>[];
    final numberFormat = NumberFormat('#,###');

    // Due Installment Alert
    final installments = provider.dueInstallments ?? [];
    if (installments.isNotEmpty) {
      final closest = installments.first;
      alerts.add(_buildAlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'قسط قريب الاستحقاق',
        message: 'لديك قسط بقيمة ${numberFormat.format(closest.amount)} YER يستحق قريباً.',
        color: Colors.red.shade100,
        iconColor: Colors.red.shade700,
      ));
    }

    // High Expense Alert
    final expense = provider.expenseSummary;
    if (expense != null) {
      final totalBudget = double.tryParse(expense.totalPlanned) ?? 0.0;
      final totalSpent = double.tryParse(expense.totalPaid) ?? 0.0;
      if (totalBudget > 0) {
        final spentPct = totalSpent / totalBudget;
        if (spentPct > 0.8) {
          alerts.add(_buildAlertItem(
            icon: Icons.trending_up,
            title: 'مصروفات مرتفعة',
            message: 'لقد وصلت المصروفات إلى ${(spentPct * 100).toInt()}% من إجمالي الميزانية.',
            color: Colors.orange.shade100,
            iconColor: Colors.orange.shade800,
          ));
        }
      }
    }

    // Upcoming Task Alert
    final tasks = provider.tasks ?? [];
    final upcoming = tasks.where((t) => !t.isDone).toList();
    if (upcoming.isNotEmpty) {
      // Sort by date if possible, assuming they are ordered or just take first
      final nextTask = upcoming.first;
      alerts.add(_buildAlertItem(
        icon: Icons.assignment_late,
        title: 'مهمة قريبة',
        message: 'مهمة: ${nextTask.title}',
        color: Colors.green.shade100,
        iconColor: Colors.green.shade800,
      ));
    }

    if (alerts.isEmpty) {
      alerts.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'لا توجد تنبيهات حالية.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'تنبيهات مهمة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: alerts,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({required IconData icon, required String title, required String message, required Color color, required Color iconColor}) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 12, color: iconColor.withAlpha(200))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMembersCard extends StatelessWidget {
  const HomeMembersCard({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.primaryPlan == null) return const SizedBox.shrink();

    final members = provider.sharedMembers ?? [];
    final planId = provider.primaryPlan!.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group, color: AppTheme.deepBurgundy, size: 20),
              SizedBox(width: 8),
              Text(
                'المشاركون في الخطة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا يوجد مشاركون في هذه الخطة.'),
                  ),
                ...members.map((m) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.ivory,
                        child: Icon(Icons.person, color: AppTheme.deepBurgundy),
                      ),
                      title: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(m.displaySubtitle ?? 'بدون رقم', style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.warmGold.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m.role == 'EDITOR' ? 'محرر' : (m.role == 'VIEWER' ? 'مشاهد' : m.role),
                          style: const TextStyle(fontSize: 10, color: AppTheme.deepBurgundy),
                        ),
                      ),
                    )),
                const Divider(height: 1),
                TextButton.icon(
                  onPressed: () => context.push(AppRouter.addSharedMember(planId)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة عضو'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.deepBurgundy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final sharedCount = provider.sharedPlans.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_shared, color: AppTheme.deepBurgundy, size: 20),
              SizedBox(width: 8),
              Text(
                'الخطط المشتركة معي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => context.push(AppRouter.sharedWeddingPlans),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.warmGold.withAlpha(50),
                      child: const Icon(Icons.groups, color: AppTheme.deepBurgundy),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$sharedCount خطة مشتركة',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Text(
                            'عرض الخطط المشتركة',
                            style: TextStyle(color: AppTheme.deepBurgundy, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: AppTheme.deepBurgundy),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
