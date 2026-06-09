import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../providers/dashboard_summary_provider.dart';

class DashboardUiColors {
  static const Color maroon = Color(0xFF6B1530);
  static const Color maroonBright = Color(0xFF8B1A3D);
  static const Color maroonSoft = Color(0xFFF9F2F4);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldSoft = Color(0xFFFDF9EC);
  static const Color ivory = Color(0xFFFAF7F2);
  static const Color card = Colors.white;
  static const Color ink = Color(0xFF1E1E1E);
  static const Color muted = Color(0xFF8C8C8C);
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE8F5E9);
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerSoft = Color(0xFFFFEBEE);
  static const Color blue = Color(0xFF1976D2);
  static const Color blueSoft = Color(0xFFE3F2FD);
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
    String countdown = 'غير محدد';
    if (plan.weddingDate != null) {
      final diff = plan.weddingDate!.difference(DateTime.now());
      if (diff.isNegative) {
        countdown = 'تم الزفاف';
      } else {
        countdown = '${diff.inDays} يوم، ${diff.inHours % 24} ساعات متبقية';
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [DashboardUiColors.maroonBright, DashboardUiColors.maroon],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardUiColors.maroon.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 12),
                _HeroMetaRow(icon: Icons.location_on_outlined, text: plan.city ?? 'صنعاء'),
                const SizedBox(height: 6),
                _HeroMetaRow(icon: Icons.calendar_month_outlined, text: 'تاريخ الزفاف: $dateStr'),
                const SizedBox(height: 6),
                _HeroMetaRow(icon: Icons.hourglass_bottom, text: countdown),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('حالة الخطة', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: DashboardUiColors.gold.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DashboardUiColors.gold),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, color: DashboardUiColors.goldBright, size: 14),
                          SizedBox(width: 4),
                          Text('قيد التخطيط', style: TextStyle(color: DashboardUiColors.goldBright, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(DashboardUiColors.goldBright),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percent% مكتمل',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  '$doneTasks من $totalTasks مهام مكتملة',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _ProgressDonutPainter(progress: progress),
                  child: Center(
                    child: Text(
                      '$percent%',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('مكتمل', style: TextStyle(color: DashboardUiColors.goldBright, fontWeight: FontWeight.w800)),
              Text('$doneTasks مهام', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: DashboardUiColors.goldBright, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ProgressDonutPainter extends CustomPainter {
  _ProgressDonutPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..color = DashboardUiColors.goldBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NewDashboardMetricsBudgetSection extends StatelessWidget {
  const NewDashboardMetricsBudgetSection({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  double _parseAmt(String? val) => double.tryParse(val?.replaceAll(',', '') ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final allTasks = provider.tasks ?? [];
    final pendingTasks = allTasks.where((t) => !t.isDone).length;
    final dueInstallments = provider.dueInstallments?.length ?? 0;
    final debtsTotal = _parseAmt(provider.debtSummary?.totalDebt);

    final budgetTotal = _parseAmt(plan.estimatedBudget);
    final spent = _parseAmt(provider.expenseSummary?.totalPaid);
    final obligations = _parseAmt(provider.debtSummary?.remainingDebt);
    final remaining = math.max(0.0, budgetTotal - spent - obligations);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetricCard(
                icon: Icons.checklist,
                iconColor: DashboardUiColors.success,
                iconBg: DashboardUiColors.successSoft,
                title: 'المهام القادمة',
                value: '$pendingTasks',
                unit: 'مهمة',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniMetricCard(
                icon: Icons.calendar_month,
                iconColor: DashboardUiColors.maroon,
                iconBg: DashboardUiColors.dangerSoft,
                title: 'الأقساط القريبة',
                value: '$dueInstallments',
                unit: 'قسط',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniMetricCard(
                icon: Icons.credit_card,
                iconColor: DashboardUiColors.maroon,
                iconBg: DashboardUiColors.dangerSoft,
                title: 'الديون',
                value: formatNumber(debtsTotal),
                unit: plan.currency,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DashboardUiColors.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: DashboardUiColors.goldSoft, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.savings_outlined, color: DashboardUiColors.gold, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('ملخص الميزانية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
                    ],
                  ),
                  Text(
                    '${formatNumber(budgetTotal)} ${plan.currency}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DashboardUiColors.ink),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BudgetLineItem(label: 'المصروف', amount: spent, currency: plan.currency, color: DashboardUiColors.maroon),
                        const SizedBox(height: 12),
                        _BudgetLineItem(label: 'المتبقي', amount: remaining, currency: plan.currency, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        _BudgetLineItem(label: 'الالتزامات القادمة', amount: obligations, currency: plan.currency, color: DashboardUiColors.gold),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _BudgetDonutPainter(
                        total: budgetTotal > 0 ? budgetTotal : 1,
                        spent: spent,
                        remaining: remaining,
                        obligations: obligations,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetDonutPainter extends CustomPainter {
  _BudgetDonutPainter({required this.total, required this.spent, required this.remaining, required this.obligations});
  final double total, spent, remaining, obligations;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final stroke = 16.0;

    double startAngle = -math.pi / 2;
    void drawSegment(double value, Color color) {
      if (value <= 0) return;
      final sweepAngle = (value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawSegment(spent, DashboardUiColors.maroon);
    drawSegment(remaining, Colors.grey.shade300);
    drawSegment(obligations, DashboardUiColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BudgetLineItem extends StatelessWidget {
  const _BudgetLineItem({required this.label, required this.amount, required this.currency, required this.color});
  final String label, currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DashboardUiColors.ink)),
              Text('${formatNumber(amount)} $currency', style: const TextStyle(fontSize: 12, color: DashboardUiColors.muted), textDirection: TextDirection.ltr),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({required this.icon, required this.iconColor, required this.iconBg, required this.title, required this.value, required this.unit});
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, value, unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DashboardUiColors.muted), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
          Text(unit, style: const TextStyle(fontSize: 11, color: DashboardUiColors.muted)),
        ],
      ),
    );
  }
}

class NewDashboardQuickActions extends StatelessWidget {
  const NewDashboardQuickActions({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    final planId = provider.plan?.id ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: DashboardUiColors.maroonBright, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bolt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('إجراءات سريعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'إضافة مصروف',
                  color: DashboardUiColors.maroon,
                  bg: DashboardUiColors.dangerSoft,
                  onTap: () => context.push(AppRouter.finance(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.credit_card_rounded,
                  label: 'إضافة دين',
                  color: DashboardUiColors.maroon,
                  bg: DashboardUiColors.dangerSoft,
                  onTap: () => context.push(AppRouter.debts(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.check_circle_outline,
                  label: 'إضافة مهمة',
                  color: DashboardUiColors.success,
                  bg: DashboardUiColors.successSoft,
                  onTap: () => context.push(AppRouter.tasks(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'إضافة عضو',
                  color: DashboardUiColors.blue,
                  bg: DashboardUiColors.blueSoft,
                  onTap: () => context.push(AppRouter.sharing(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.note_add_outlined,
                  label: 'خطة جديدة',
                  color: DashboardUiColors.gold,
                  bg: DashboardUiColors.goldSoft,
                  onTap: () => context.push(AppRouter.createWeddingPlan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 86,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DashboardUiColors.ink), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class NewDashboardAlertsMembersGrid extends StatelessWidget {
  const NewDashboardAlertsMembersGrid({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: DashboardUiColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.notifications_active, color: DashboardUiColors.maroon, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('تنبيهات مهمة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DashboardUiColors.ink)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: DashboardUiColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
                      child: const Text('1', style: TextStyle(color: DashboardUiColors.maroon, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('لا توجد تنبيهات حالياً', style: TextStyle(color: DashboardUiColors.muted, fontSize: 12)),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('عرض كل التنبيهات', style: TextStyle(color: DashboardUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
                    Icon(Icons.chevron_left, color: DashboardUiColors.maroon, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المشاركون في\nالخطة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DashboardUiColors.ink, height: 1.2)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: DashboardUiColors.maroon, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Icons.group, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('1 عضو', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: Color(0xFFC05A4A), shape: BoxShape.circle),
                      child: const Center(child: Text('ا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الجحش', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DashboardUiColors.ink)),
                          Text('779800986', style: TextStyle(fontSize: 10, color: DashboardUiColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: DashboardUiColors.successSoft, borderRadius: BorderRadius.circular(6)),
                  child: const Text('مساهم', style: TextStyle(color: DashboardUiColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    final planId = provider.plan?.id;
                    if (planId != null) context.push(AppRouter.sharing(planId));
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('إضافة عضو', style: TextStyle(color: DashboardUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
                      Icon(Icons.chevron_left, color: DashboardUiColors.maroon, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NewDashboardSharedPlansCard extends StatelessWidget {
  const NewDashboardSharedPlansCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('الخطط المشتركة معي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: DashboardUiColors.ink)),
              SizedBox(width: 8),
              Icon(Icons.group, color: DashboardUiColors.maroon, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.push(AppRouter.sharedWeddingPlans),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: DashboardUiColors.maroon,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
                  const Spacer(),
                  const Text('عرض الخطط المشتركة', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.folder_shared, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
