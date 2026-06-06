import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_dashboard_provider.dart';

// ─── Local formatting helpers (no external package needed) ───────────────────

String _formatDate(DateTime? date) {
  if (date == null) return 'غير محدد';
  const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatNumber(num value) {
  // Insert commas every 3 digits.
  final str = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 0);
  final buffer = StringBuffer();
  final digits = str.replaceAll('-', '');
  final isNegative = value < 0;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return isNegative ? '-${buffer.toString()}' : buffer.toString();
}


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

    final dateStr = _formatDate(plan.weddingDate);

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

    // Create a detailed time remaining string if needed, or just use days
    String timeRemainingStr = daysRemaining != null ? '$daysRemaining يوم متبقي' : 'غير محدد';

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
              color: Colors.white.withAlpha(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Right: Title and Location/Date
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                      plan.city ?? 'صنعاء',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today, color: AppTheme.warmGold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Middle Section: Status, Date Remaining, Circular Progress
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Right column: Status & Date
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('حالة الخطة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warmGold.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.warmGold.withAlpha(100)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_outline, color: AppTheme.warmGold, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        plan.status == 'PLANNING' ? 'قيد التخطيط' : (plan.status == 'COMPLETED' ? 'مكتمل' : plan.status),
                                        style: const TextStyle(color: AppTheme.warmGold, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاريخ الزفاف', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.timer, color: Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        timeRemainingStr,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Left column: Circular Progress
                    SizedBox(
                      width: 90,
                      height: 90,
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
                                backgroundColor: Colors.black.withAlpha(50),
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                              );
                            },
                          ),
                          Center(
                            child: Text(
                              '$progressPct%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Bottom Section: Horizontal Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$progressPct% مكتمل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('$completedTasks من $totalTasks مهام مكتملة', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$progressPct% مكتمل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('$completedTasks من $totalTasks مهام مكتملة', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.black.withAlpha(50),
                        color: AppTheme.warmGold,
                        minHeight: 6,
                      );
                    },
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

class DonutChartPainter extends CustomPainter {
  final double spentPct;
  final double remainingPct;
  final double upcomingPct;

  DonutChartPainter({
    required this.spentPct,
    required this.remainingPct,
    required this.upcomingPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Mockup has butt caps, not round

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -pi / 2;

    // Remaining (Grey)
    if (remainingPct > 0) {
      paint.color = Colors.grey.shade300;
      final sweepAngle = 2 * pi * remainingPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Upcoming (Gold)
    if (upcomingPct > 0) {
      paint.color = AppTheme.warmGold;
      final sweepAngle = 2 * pi * upcomingPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Spent (Burgundy)
    if (spentPct > 0) {
      paint.color = AppTheme.deepBurgundy;
      final sweepAngle = 2 * pi * spentPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
    final upcomingTasks = tasks.where((t) => !t.isDone).toList();

    String Function(num) numberFormat = _formatNumber;

    final totalBudget = double.tryParse(expense?.totalPlanned ?? '0') ?? 0.0;
    final totalSpent = double.tryParse(expense?.totalPaid ?? '0') ?? 0.0;
    final totalDebtVal = double.tryParse(debt?.totalDebt ?? '0') ?? 0.0;
    final remainingDebtVal = double.tryParse(debt?.remainingDebt ?? '0') ?? 0.0;
    final remainingBudget = totalBudget - totalSpent;

    final spentPct = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    final remainingPct = totalBudget > 0 ? (remainingBudget / totalBudget) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN (Visually on the Right in RTL, but we'll use order appropriately. Wait, Row children order: index 0 is RTL Right.)
          // Let's stick to the visual: Right side of screen = Budget Card. Left side = 3 cards.
          // In RTL, Row[0] is Right, Row[1] is Left.
          Expanded(
            flex: 12,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${numberFormat(totalBudget)} YER', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Row(
                          children: [
                            Text('ميزانية الخطة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            SizedBox(width: 4),
                            Icon(Icons.monetization_on, color: AppTheme.warmGold, size: 14),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildDonutLabel('المصروف', '${numberFormat(totalSpent)} YER', '${(spentPct * 100).toInt()}%', AppTheme.deepBurgundy),
                              const SizedBox(height: 12),
                              _buildDonutLabel('المتبقي', '${numberFormat(remainingBudget)} YER', '${(remainingPct * 100).toInt()}%', Colors.grey.shade400),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CustomPaint(
                            painter: DonutChartPainter(
                              spentPct: spentPct,
                              remainingPct: remainingPct,
                              upcomingPct: 0.1, // Visual match
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRightListLabel('الديون', '${numberFormat(totalDebtVal)} YER'),
                              const SizedBox(height: 8),
                              _buildRightListLabel('الأقساط القادمة', '${numberFormat(installments.isNotEmpty ? (double.tryParse(installments.first.amount) ?? 0) : 0)} YER'),
                              const SizedBox(height: 8),
                              _buildRightListLabel('الميزانية الكلية', numberFormat(totalBudget)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.warmGold)),
                        const SizedBox(width: 4),
                        const Text('الالتزامات القادمة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Text('الديون، والالتزامات، الأقساط', style: TextStyle(fontSize: 8, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 8,
            child: Column(
              children: [
                _buildSmallStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: Colors.green.shade700,
                  iconBgColor: Colors.green.shade50,
                  title: 'الديون',
                  mainValue: numberFormat(totalDebtVal),
                  mainLabel: 'YER',
                  subTitle: 'المتبقي',
                  subValue: '${numberFormat(remainingDebtVal)} YER',
                  subValueColor: Colors.red.shade700,
                ),
                const SizedBox(height: 8),
                _buildSmallStatCard(
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.orange.shade700,
                  iconBgColor: Colors.orange.shade50,
                  title: 'الأقساط القريبة',
                  mainValue: '${installments.length}',
                  mainLabel: 'قسط',
                  subTitle: 'المبلغ',
                  subValue: '${numberFormat(installments.isNotEmpty ? (double.tryParse(installments.first.amount) ?? 0) : 0)} YER',
                  subValueColor: Colors.orange.shade700,
                  extraSubText: installments.isNotEmpty ? _formatDate(installments.first.dueDate) : null,
                ),
                const SizedBox(height: 8),
                _buildSmallStatCard(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green.shade700,
                  iconBgColor: Colors.green.shade50,
                  title: 'المهام القادمة',
                  mainValue: '${upcomingTasks.length}',
                  mainLabel: 'مهمة',
                  subTitle: 'أقرب مهمة',
                  subValue: upcomingTasks.isNotEmpty ? upcomingTasks.first.title : 'لا يوجد',
                  subValueColor: Colors.black87,
                  extraSubText: upcomingTasks.isNotEmpty ? _formatDate(upcomingTasks.first.dueDate) : null,
                  extraSubTextColor: Colors.green.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLabel(String title, String value, String pct, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 9, color: Colors.black87)),
              Text('($pct)', style: const TextStyle(fontSize: 8, color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Container(margin: const EdgeInsets.only(top: 2), width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      ],
    );
  }

  Widget _buildRightListLabel(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSmallStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String mainValue,
    required String mainLabel,
    required String subTitle,
    required String subValue,
    required Color subValueColor,
    String? extraSubText,
    Color? extraSubTextColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(mainValue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(mainLabel, style: const TextStyle(fontSize: 9, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(subTitle, style: const TextStyle(fontSize: 9, color: Colors.black38)),
            Text(subValue, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subValueColor), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (extraSubText != null)
              Text(extraSubText, style: TextStyle(fontSize: 9, color: extraSubTextColor ?? Colors.black54)),
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
          const Row(
            children: [
              Icon(Icons.bolt, color: AppTheme.warmGold, size: 20),
              SizedBox(width: 8),
              Text(
                'إجراءات سريعة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionCard(context, icon: Icons.add_box_outlined, label: 'خطة جديدة', onTap: () => context.push(AppRouter.createWeddingPlan), enabled: true)),
              const SizedBox(width: 6),
              Expanded(child: _buildActionCard(context, icon: Icons.person_add_alt_1_outlined, label: 'إضافة عضو', onTap: () => context.push(AppRouter.addSharedMember(planId)), enabled: hasPlan)),
              const SizedBox(width: 6),
              Expanded(child: _buildActionCard(context, icon: Icons.task_alt_outlined, label: 'إضافة مهمة', onTap: () => context.push(AppRouter.createTask(planId)), enabled: hasPlan)),
              const SizedBox(width: 6),
              Expanded(child: _buildActionCard(context, icon: Icons.credit_card_outlined, label: 'إضافة دين', onTap: () => context.push(AppRouter.createDebt(planId)), enabled: hasPlan)),
              const SizedBox(width: 6),
              Expanded(child: _buildActionCard(context, icon: Icons.account_balance_wallet_outlined, label: 'إضافة مصروف', onTap: () => context.push(AppRouter.createExpense(planId)), enabled: hasPlan)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required bool enabled}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.deepBurgundy, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    final String Function(num) numberFormat = _formatNumber;

    // Due Installment Alert
    final installments = provider.dueInstallments ?? [];
    if (installments.isNotEmpty) {
      final closest = installments.first;
      alerts.add(_buildAlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'قسط قريب الاستحقاق',
        message: 'لديك قسط بقيمة ${numberFormat(double.tryParse(closest.amount) ?? 0)} YER يستحق قريباً.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.redAccent, size: 16),
            SizedBox(width: 8),
            Text(
              'تنبيهات مهمة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...alerts,
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('عرض كل التنبيهات', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertItem({required IconData icon, required String title, required String message, required Color color, required Color iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor, fontSize: 11)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 9, color: iconColor.withAlpha(200))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 20),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.group, color: AppTheme.deepBurgundy, size: 16),
                SizedBox(width: 8),
                Text(
                  'المشاركون في الخطة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            Text('${members.length} عضو', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
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
                  child: Text('لا يوجد مشاركون في هذه الخطة.', style: TextStyle(fontSize: 10)),
                ),
              ...members.map((m) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.ivory,
                      child: Icon(Icons.person, color: AppTheme.deepBurgundy, size: 16),
                    ),
                    title: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    subtitle: Text(m.displaySubtitle ?? 'بدون رقم', style: const TextStyle(fontSize: 8)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warmGold.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.role == 'EDITOR' ? 'محرر' : (m.role == 'VIEWER' ? 'مشاهد' : m.role),
                        style: const TextStyle(fontSize: 8, color: AppTheme.deepBurgundy),
                      ),
                    ),
                  )),
              const Divider(height: 1),
              TextButton.icon(
                onPressed: () => context.push(AppRouter.addSharedMember(planId)),
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('إضافة عضو', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.deepBurgundy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({super.key, required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final sharedCount = provider.sharedPlans.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_shared, color: AppTheme.deepBurgundy, size: 16),
                SizedBox(width: 8),
                Text(
                  'الخطط المشتركة معي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            Text('$sharedCount خطة مشتركة', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          color: AppTheme.warmGold.withAlpha(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => context.push(AppRouter.sharedWeddingPlans),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.folder_shared, color: AppTheme.deepBurgundy, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'عرض الخطط المشتركة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.deepBurgundy),
                    ),
                  ),
                  Icon(Icons.chevron_left, color: AppTheme.deepBurgundy, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
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
