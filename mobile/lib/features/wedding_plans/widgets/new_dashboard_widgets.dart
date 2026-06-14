import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../providers/dashboard_summary_provider.dart';

class DashboardUiColors {
  static const Color primaryMaroon = Color(0xFF8A1538); 
  static const Color heroMaroonDark = Color(0xFF5A0B22);
  static const Color heroGold = Color(0xFFD4AF37);
  static const Color heroGoldLight = Color(0xFFF3D288);
  static const Color textDark = Color(0xFF2C2C2C);
  static const Color textGray = Color(0xFF757575);
  static const Color textLightGray = Color(0xFFA0A0A0);
  static const Color background = Color(0xFFFAF8F6);
  static const Color cardBg = Colors.white;
  static const Color borderLight = Color(0xFFEEEEEE);
  
  static const Color bgGreen = Color(0xFFEBF7EE);
  static const Color iconGreen = Color(0xFF45A259);
  static const Color bgRed = Color(0xFFFAECEE);
  static const Color iconRed = Color(0xFFC7556A);
  static const Color bgOrange = Color(0xFFFEF3E8);
  static const Color iconOrange = Color(0xFFE88A34);
  static const Color bgPurple = Color(0xFFF1EEF6);
  static const Color iconPurple = Color(0xFF7C60A6);
}

String formatNumber(num value) {
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

String formatArDate(DateTime date) {
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

// -----------------------------------------------------------------------------
// Top Header (DashboardTopBar equivalent)
// -----------------------------------------------------------------------------
class NewDashboardTopHeader extends StatelessWidget {
  const NewDashboardTopHeader({required this.userName, required this.onProfile, super.key});
  final String userName;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final firstName = userName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Right: Branding and Greeting
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                children: [
                  Text('أعرسِت', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: DashboardUiColors.primaryMaroon, fontFamily: 'Amiri', height: 1.2)),
                  SizedBox(width: 4),
                  Icon(Icons.favorite, color: DashboardUiColors.primaryMaroon, size: 14),
                ],
              ),
              Text('مساء الخير، $firstName 💛', style: const TextStyle(fontSize: 13, color: DashboardUiColors.textDark, fontWeight: FontWeight.w600)),
            ],
          ),
          // Left: Icons
          Row(
            children: [
              // Profile Avatar
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: DashboardUiColors.borderLight, width: 1.5),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: DashboardUiColors.heroGold, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Notification Bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: DashboardUiColors.borderLight, width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: DashboardUiColors.primaryMaroon, size: 24),
                  ),
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: DashboardUiColors.primaryMaroon, shape: BoxShape.circle),
                      child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Hero Card
// -----------------------------------------------------------------------------
class NewDashboardHeroCard extends StatelessWidget {
  const NewDashboardHeroCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final allTasks = provider.tasks ?? [];
    final totalTasks = allTasks.length;
    final doneTasks = allTasks.where((t) => t.isDone).length;
    final progress = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    final percent = (progress * 100).round();

    final dateStr = plan.weddingDate != null ? formatArDate(plan.weddingDate!) : 'غير محدد';
    int daysLeft = 0;
    if (plan.weddingDate != null) {
      final diff = plan.weddingDate!.difference(DateTime.now());
      daysLeft = diff.isNegative ? 0 : diff.inDays;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [DashboardUiColors.primaryMaroon, DashboardUiColors.heroMaroonDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(color: DashboardUiColors.primaryMaroon.withAlpha(40), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Right: Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.diamond_outlined, color: DashboardUiColors.heroGoldLight, size: 22),
                        const SizedBox(width: 8),
                        Text(plan.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 30),
                      child: Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: DashboardUiColors.heroGoldLight, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أنت في الطريق الصحيح!', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                              Text('$doneTasks من $totalTasks مهمة مكتملة', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Left: Donut Chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _HeroDonutPainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$percent%', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
                        const Text('مكتمل', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom Actions & Progress
          Row(
            children: [
              // Countdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تبقى $daysLeft يوم', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_month_outlined, color: DashboardUiColors.heroGoldLight, size: 16),
                ],
              ),
              const SizedBox(width: 12),
              // Progress Line
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(color: DashboardUiColors.heroMaroonDark, borderRadius: BorderRadius.circular(3)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(color: DashboardUiColors.heroGoldLight, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Button
              InkWell(
                onTap: () => context.push(AppRouter.tasks(plan.id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: DashboardUiColors.heroMaroonDark.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('استكمال المهام', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_left, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDonutPainter extends CustomPainter {
  _HeroDonutPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final strokeWidth = 8.0;

    // Track (background)
    final trackPaint = Paint()
      ..color = DashboardUiColors.heroMaroonDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = DashboardUiColors.heroGoldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, arcPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// Row 1: Budget and Quick Glance
// -----------------------------------------------------------------------------
class NewDashboardStatsBudgetRow extends StatelessWidget {
  const NewDashboardStatsBudgetRow({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  double _parseAmt(String? val) => double.tryParse(val?.replaceAll(',', '') ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final allTasks = provider.tasks ?? [];
    final totalTasks = allTasks.length;
    final doneTasks = allTasks.where((t) => t.isDone).length;
    final dueInstallments = provider.dueInstallments?.length ?? 0;
    
    final budgetTotal = _parseAmt(plan.estimatedBudget);
    final spent = _parseAmt(provider.expenseSummary?.totalPaid);
    final remaining = math.max(0.0, budgetTotal - spent);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right Column: Budget
        Expanded(
          flex: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: DashboardUiColors.primaryMaroon, size: 18),
                    SizedBox(width: 6),
                    Text('ملخص الميزانية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.textDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي الميزانية', style: TextStyle(fontSize: 11, color: DashboardUiColors.textGray)),
                          Text(formatNumber(budgetTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DashboardUiColors.textDark), textDirection: TextDirection.ltr),
                          const Text('ر.ي', style: TextStyle(fontSize: 10, color: DashboardUiColors.textGray)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Donut
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CustomPaint(
                        painter: _MiniBudgetPainter(total: budgetTotal > 0 ? budgetTotal : 1, spent: spent, remaining: remaining),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BudgetRow(label: 'المصروف', amount: spent, color: DashboardUiColors.primaryMaroon),
                const SizedBox(height: 8),
                _BudgetRow(label: 'المتبقي', amount: remaining, color: DashboardUiColors.heroGoldLight),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push(AppRouter.finance(plan.id)),
                  child: const Row(
                    children: [
                      Icon(Icons.chevron_left, color: DashboardUiColors.primaryMaroon, size: 16),
                      SizedBox(width: 4),
                      Text('عرض التفاصيل', style: TextStyle(color: DashboardUiColors.primaryMaroon, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Left Column: Quick Glance (نظرة سريعة)
        Expanded(
          flex: 10,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: DashboardUiColors.cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: DashboardUiColors.primaryMaroon, size: 18),
                    SizedBox(width: 6),
                    Text('نظرة سريعة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.primaryMaroon)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _GlanceCard(title: 'الموردين', value: '12', icon: Icons.group_outlined, iconColor: DashboardUiColors.iconGreen, bgColor: DashboardUiColors.bgGreen)),
                    const SizedBox(width: 8),
                    Expanded(child: _GlanceCard(title: 'المهام', value: '$doneTasks/$totalTasks', icon: Icons.assignment_outlined, iconColor: DashboardUiColors.iconRed, bgColor: DashboardUiColors.bgRed)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _GlanceCard(title: 'الضيوف', value: '246', icon: Icons.groups_outlined, iconColor: DashboardUiColors.iconOrange, bgColor: DashboardUiColors.bgOrange)),
                    const SizedBox(width: 8),
                    Expanded(child: _GlanceCard(title: 'المدفوعات', value: '$dueInstallments', icon: Icons.payment_outlined, iconColor: DashboardUiColors.iconPurple, bgColor: DashboardUiColors.bgPurple)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({required this.title, required this.value, required this.icon, required this.iconColor, required this.bgColor});
  final String title, value;
  final IconData icon;
  final Color iconColor, bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: DashboardUiColors.borderLight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: DashboardUiColors.textGray, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13, color: DashboardUiColors.textDark, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MiniBudgetPainter extends CustomPainter {
  _MiniBudgetPainter({required this.total, required this.spent, required this.remaining});
  final double total, spent, remaining;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final stroke = 10.0;
    
    // Background full track (in case there's no spending)
    final bgPaint = Paint()..color = DashboardUiColors.borderLight..style = PaintingStyle.stroke..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;
    void drawSeg(double value, Color color) {
      if (value <= 0) return;
      final sweepAngle = (value / total) * 2 * math.pi;
      final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawSeg(spent, DashboardUiColors.primaryMaroon);
    drawSeg(remaining, DashboardUiColors.heroGoldLight);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.label, required this.amount, required this.color});
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: DashboardUiColors.textGray, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(formatNumber(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DashboardUiColors.textDark), textDirection: TextDirection.ltr),
        const SizedBox(width: 4),
        const Text('ر.ي', style: TextStyle(fontSize: 10, color: DashboardUiColors.textGray)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Quick Actions
// -----------------------------------------------------------------------------
class NewDashboardQuickActions extends StatelessWidget {
  const NewDashboardQuickActions({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    final planId = provider.plan?.id ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, color: DashboardUiColors.heroGold, size: 20),
            SizedBox(width: 6),
            Text('إجراءات سريعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DashboardUiColors.textDark)),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickActionCircle(icon: Icons.add, label: 'نفقات سريعة', onTap: () => context.push(AppRouter.createExpense(planId))),
              _QuickActionCircle(icon: Icons.groups_outlined, label: 'قائمة الضيوف', onTap: () => context.push(AppRouter.sharing(planId))),
              _QuickActionCircle(icon: Icons.calendar_month_outlined, label: 'جدول الزواج', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قيد الإعداد')))),
              _QuickActionCircle(icon: Icons.person_search_outlined, label: 'الموردين', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قيد الإعداد')))),
              _QuickActionCircle(icon: Icons.account_balance_wallet_outlined, label: 'الميزانية', onTap: () => context.push(AppRouter.finance(planId))),
              _QuickActionCircle(icon: Icons.assignment_outlined, label: 'قائمة المهام', onTap: () => context.push(AppRouter.tasks(planId))),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCircle extends StatelessWidget {
  const _QuickActionCircle({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DashboardUiColors.cardBg,
                border: Border.all(color: DashboardUiColors.primaryMaroon.withAlpha(50), width: 1),
              ),
              child: Icon(icon, color: DashboardUiColors.primaryMaroon, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DashboardUiColors.textDark)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Important Notes (Alerts)
// -----------------------------------------------------------------------------
class NewDashboardAlertsList extends StatelessWidget {
  const NewDashboardAlertsList({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    // Determine alerts from nearest task and nearest installment
    final allTasks = provider.tasks ?? [];
    final pendingTasks = allTasks.where((t) => !t.isDone && t.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final nearestTask = pendingTasks.isNotEmpty ? pendingTasks.first : null;

    final installments = provider.dueInstallments ?? [];
    final dueInstallments = List.of(installments)..sort((a, b) => (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));
    final nearestInst = dueInstallments.isNotEmpty ? dueInstallments.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bookmark_outline, color: DashboardUiColors.primaryMaroon, size: 20),
                SizedBox(width: 6),
                Text('ملاحظات مهمة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DashboardUiColors.textDark)),
              ],
            ),
            InkWell(
              onTap: () => context.push(AppRouter.tasks(provider.plan?.id ?? '')),
              child: const Text('عرض الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DashboardUiColors.primaryMaroon)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (nearestTask != null)
          _NoteCard(
            title: nearestTask.title,
            timeLabel: 'تاريخ الاستحقاق: ${formatArDate(nearestTask.dueDate!)}',
            icon: Icons.calendar_today_outlined,
            iconBg: DashboardUiColors.heroMaroonDark.withAlpha(20),
            iconColor: DashboardUiColors.primaryMaroon,
          ),
        if (nearestInst != null) ...[
          if (nearestTask != null) const SizedBox(height: 12),
          _NoteCard(
            title: 'قسط مستحق بقيمة ${formatNumber(double.tryParse(nearestInst.amount) ?? 0)}',
            timeLabel: 'قبل ${formatArDate(nearestInst.dueDate ?? DateTime.now())}',
            icon: Icons.payment_outlined,
            iconBg: DashboardUiColors.heroGoldLight.withAlpha(50),
            iconColor: DashboardUiColors.heroGold,
          ),
        ],
        if (nearestTask == null && nearestInst == null)
          const Center(child: Text('لا توجد ملاحظات حالياً', style: TextStyle(color: DashboardUiColors.textGray, fontSize: 13))),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.timeLabel, required this.icon, required this.iconColor, required this.iconBg});
  final String title, timeLabel;
  final IconData icon;
  final Color iconColor, iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DashboardUiColors.cardBg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.textDark)),
                const SizedBox(height: 4),
                Text(timeLabel, style: const TextStyle(fontSize: 12, color: DashboardUiColors.textGray)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: DashboardUiColors.textLightGray),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared Plans
// -----------------------------------------------------------------------------
class NewDashboardSharedPlansCard extends StatelessWidget {
  const NewDashboardSharedPlansCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.group_outlined, color: DashboardUiColors.primaryMaroon, size: 20),
                SizedBox(width: 6),
                Text('الخطط المشتركة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DashboardUiColors.textDark)),
              ],
            ),
            InkWell(
              onTap: () => context.push(AppRouter.sharedWeddingPlans),
              child: const Text('عرض الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DashboardUiColors.primaryMaroon)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push(AppRouter.sharedWeddingPlans),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: DashboardUiColors.cardBg, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: DashboardUiColors.primaryMaroon, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خطة عائلتنا', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.textDark)),
                      SizedBox(height: 4),
                      Text('آخر تحديث: اليوم، 9:20 ص', style: TextStyle(fontSize: 12, color: DashboardUiColors.textGray)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: DashboardUiColors.textLightGray),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// -----------------------------------------------------------------------------
// Bottom Navigation
// -----------------------------------------------------------------------------
class NewDashboardBottomNav extends StatelessWidget {
  const NewDashboardBottomNav({
    required this.activeIndex,
    required this.onHome,
    required this.onVendors,
    required this.onAdd,
    required this.onTasks,
    required this.onMore,
    super.key,
  });

  final int activeIndex;
  final VoidCallback onHome;
  final VoidCallback onVendors;
  final VoidCallback onAdd;
  final VoidCallback onTasks;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavItem(icon: Icons.home_filled, label: 'الرئيسية', isActive: activeIndex == 0, onTap: onHome),
                  _NavItem(icon: Icons.calendar_today_outlined, label: 'المهام', isActive: activeIndex == 1, onTap: onTasks),
                  const SizedBox(width: 56), // Space for floating button
                  _NavItem(icon: Icons.assignment_ind_outlined, label: 'الموردين', isActive: activeIndex == 2, onTap: onVendors),
                  _NavItem(icon: Icons.grid_view_rounded, label: 'المزيد', isActive: activeIndex == 3, onTap: onMore),
                ],
              ),
            ),
            // Center Floating Action Button
            Positioned(
              top: -24,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: DashboardUiColors.primaryMaroon,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: DashboardUiColors.primaryMaroon.withAlpha(80), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? DashboardUiColors.primaryMaroon : DashboardUiColors.textLightGray;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
