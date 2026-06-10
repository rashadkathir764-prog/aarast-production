import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
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

    final dateStr = plan.weddingDate != null
        ? formatArDate(plan.weddingDate!)
        : 'غير محدد';
    String countdown = 'غير محدد';
    if (plan.weddingDate != null) {
      final diff = plan.weddingDate!.difference(DateTime.now());
      if (diff.isNegative) {
        countdown = 'تم الزفاف';
      } else {
        countdown = 'تبقى ${diff.inDays} يوم';
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [DashboardUiColors.maroonBright, DashboardUiColors.maroon],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardUiColors.maroon.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          color: DashboardUiColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'خطة عرسي',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'أنت في الطريق الصحيح!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneTasks من $totalTasks مهمة مكتملة',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DashboardUiColors.gold,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _ProgressDonutPainter(progress: progress),
                      child: Center(
                        child: Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'مكتمل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'استكمال المهام',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    countdown,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: DashboardUiColors.gold,
                    size: 16,
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

  double _parseAmt(String? val) =>
      double.tryParse(val?.replaceAll(',', '') ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final budgetTotal = _parseAmt(plan.estimatedBudget);
    final spent = _parseAmt(provider.expenseSummary?.totalPaid);
    final remaining = math.max(
      0.0,
      budgetTotal - spent,
    ); // In the design it's total - spent = remaining

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Budget Summary
        Expanded(
          flex: 10,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ملخص الميزانية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: DashboardUiColors.ink,
                      ),
                    ),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: DashboardUiColors.maroon,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _BudgetDonutPainter(
                        total: budgetTotal > 0 ? budgetTotal : 1,
                        spent: spent,
                        remaining: remaining,
                        obligations: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'إجمالي الميزانية',
                    style: TextStyle(
                      fontSize: 11,
                      color: DashboardUiColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    formatNumber(budgetTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: DashboardUiColors.ink,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                Center(
                  child: Text(
                    'ر.ي',
                    style: const TextStyle(
                      fontSize: 11,
                      color: DashboardUiColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _BudgetLineItem(
                  label: 'المصروف',
                  amount: spent,
                  currency: plan.currency,
                  color: DashboardUiColors.maroon,
                ),
                const SizedBox(height: 8),
                _BudgetLineItem(
                  label: 'المتبقي',
                  amount: remaining,
                  currency: plan.currency,
                  color: DashboardUiColors.gold,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: DashboardUiColors.maroon,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'عرض التفاصيل',
                      style: TextStyle(
                        color: DashboardUiColors.maroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right Column: Quick Overview
        Expanded(
          flex: 11,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نظرة سريعة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: DashboardUiColors.ink,
                      ),
                    ),
                    Icon(
                      Icons.remove_red_eye_outlined,
                      color: DashboardUiColors.maroon,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.people_outline,
                        iconColor: DashboardUiColors.success,
                        iconBg: DashboardUiColors.successSoft,
                        title: 'الموردين',
                        value: '12',
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.checklist,
                        iconColor: DashboardUiColors.maroon,
                        iconBg: DashboardUiColors.dangerSoft,
                        title: 'المهام',
                        value: '16/26',
                        unit: '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.groups_outlined,
                        iconColor: Colors.orange,
                        iconBg: Colors.orange.shade50,
                        title: 'الضيوف',
                        value: '246',
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.payment_outlined,
                        iconColor: Colors.purple,
                        iconBg: Colors.purple.shade50,
                        title: 'المدفوعات',
                        value: '8',
                        unit: '',
                      ),
                    ),
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

class _BudgetDonutPainter extends CustomPainter {
  _BudgetDonutPainter({
    required this.total,
    required this.spent,
    required this.remaining,
    required this.obligations,
  });
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
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
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
  const _BudgetLineItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });
  final String label, currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DashboardUiColors.ink,
                ),
              ),
              Text(
                '${formatNumber(amount)} $currency',
                style: const TextStyle(
                  fontSize: 12,
                  color: DashboardUiColors.muted,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.unit,
  });
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, value, unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: DashboardUiColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: DashboardUiColors.ink,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: DashboardUiColors.muted,
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: DashboardUiColors.gold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'إجراءات سريعة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: DashboardUiColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.add,
                  label: 'نفقات سريعة',
                  onTap: () => context.push(AppRouter.finance(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.people_outline,
                  label: 'قائمة الضيوف',
                  onTap: () => _showComingSoon(context),
                ),
                _QuickActionBtn(
                  icon: Icons.calendar_month_outlined,
                  label: 'جدول الزواج',
                  onTap: () => _showComingSoon(context),
                ),
                _QuickActionBtn(
                  icon: Icons.storefront_outlined,
                  label: 'الموردين',
                  onTap: () => _showComingSoon(context),
                ),
                _QuickActionBtn(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'الميزانية',
                  onTap: () => context.push(AppRouter.finance(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.checklist,
                  label: 'قائمة المهام',
                  onTap: () => context.push(AppRouter.tasks(planId)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('هذه الميزة قريباً! 🚀')));
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DashboardUiColors.maroon, width: 1.5),
              ),
              child: Icon(icon, color: DashboardUiColors.maroon, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: DashboardUiColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bookmark_outline_rounded,
                    color: DashboardUiColors.maroon,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ملاحظات مهمة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: DashboardUiColors.ink,
                    ),
                  ),
                ],
              ),
              const Text(
                'عرض الكل',
                style: TextStyle(
                  color: DashboardUiColors.maroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const _NoteItem(
                  title: 'تجربة فستان الزفاف',
                  subtitle: 'الأحد، 15 يونيو 2026 - 4:00 مساءً',
                  icon: Icons.calendar_today_outlined,
                  isImportant: false,
                ),
                Divider(color: Colors.grey.shade100, height: 24),
                const _NoteItem(
                  title: 'تأكيد الحجز في قاعة سمو',
                  subtitle: 'قبل 30 يونيو 2026',
                  icon: Icons.circle,
                  iconColor: DashboardUiColors.gold,
                  iconSize: 12,
                  isImportant: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconSize,
    this.isImportant = false,
  });
  final String title, subtitle;
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImportant ? DashboardUiColors.ivory : DashboardUiColors.ivory,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(
            Icons.chevron_left,
            color: DashboardUiColors.muted,
            size: 20,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DashboardUiColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DashboardUiColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            icon,
            color: iconColor ?? DashboardUiColors.maroon,
            size: iconSize ?? 24,
          ),
        ],
      ),
    );
  }
}

class NewDashboardSharedPlansCard extends StatelessWidget {
  const NewDashboardSharedPlansCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    color: DashboardUiColors.maroon,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الخطط المشتركة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: DashboardUiColors.ink,
                    ),
                  ),
                ],
              ),
              const Text(
                'عرض الكل',
                style: TextStyle(
                  color: DashboardUiColors.maroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Right side: The > icon
                const Icon(
                  Icons.chevron_left,
                  color: DashboardUiColors.muted,
                  size: 20,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خطة عائلتنا',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DashboardUiColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'آخر تحديث: اليوم، 9:20 ص',
                        style: TextStyle(
                          fontSize: 12,
                          color: DashboardUiColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Left side: Avatar stack
                SizedBox(
                  width: 100,
                  height: 36,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade200,
                          child: const Text(
                            '+2',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 24,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/100?img=3',
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 48,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/100?img=4',
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 72,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/100?img=5',
                            ),
                          ),
                        ),
                      ),
                    ],
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

Future<void> showAccountSheet(
  BuildContext context, {
  required String name,
  String? phone,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.dCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppTheme.dPinkBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.dMaroon,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dInk,
                            ),
                          ),
                          if (phone != null)
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.dMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================================
// LOCKED SECTION + LOADING SKELETON
// ============================================================================

class LockedSectionCard extends StatelessWidget {
  const LockedSectionCard({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppTheme.dMuted),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'غير متاح حسب صلاحياتك',
                style: TextStyle(fontSize: 12, color: AppTheme.dMuted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _SectionIcon(icon: icon, color: AppTheme.dMuted, bg: AppTheme.dLine),
        ],
      ),
    );
  }
}

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.75).animate(_controller),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            _box(180),
            const SizedBox(height: 16),
            _box(150),
            const SizedBox(height: 16),
            _box(120),
            const SizedBox(height: 16),
            _box(160),
          ],
        ),
      ),
    );
  }

  Widget _box(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.dTrack.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(22),
    ),
  );
}

// ============================================================================
// SHARED PRIMITIVES
// ============================================================================

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class NewDashboardTopHeader extends StatelessWidget {
  const NewDashboardTopHeader({
    required this.userName,
    this.onProfile,
    this.onNotifications,
    this.hasNotificationDot = true,
    super.key,
  });

  final String userName;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final bool hasNotificationDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Greeting and Logo (Right side in RTL)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'مساء الخير، ${userName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dInk,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🤎', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Action icons (Left side in RTL)
          Row(
            children: [
              _IconButton(
                icon: Icons.notifications_none_rounded,
                onTap: onNotifications,
                showDot: hasNotificationDot,
                badgeCount: '3',
              ),
              const SizedBox(width: 10),
              _IconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.favorite, color: AppTheme.dMaroon, size: 10),
        ),
        const SizedBox(width: 2),
        Text(
          'أعرست',
          style: isTest
              ? const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  height: 1,
                )
              : GoogleFonts.amiri(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  height: 1,
                ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    this.onTap,
    this.showDot = false,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final String? badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          border: Border.all(
            color: DashboardUiColors.maroon.withValues(alpha: 0.1),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: DashboardUiColors.gold),
            if (showDot || badgeCount != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dCard, width: 1.5),
                  ),
                  child: badgeCount != null
                      ? Text(
                          badgeCount!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        )
                      : const SizedBox(width: 4, height: 4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The interlocking wedding rings + star from the brand logo.

class NewDashboardBottomNav extends StatelessWidget {
  const NewDashboardBottomNav({
    this.onMore,
    this.onTasks,
    this.onAdd,
    this.onVendors,
    this.onHome,
    this.activeIndex = 4,
    super.key,
  });

  final VoidCallback? onMore;
  final VoidCallback? onTasks;
  final VoidCallback? onAdd;
  final VoidCallback? onVendors;
  final VoidCallback? onHome;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardUiColors.maroon.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.home_filled,
                      label: 'الرئيسية',
                      active: activeIndex == 4,
                      onTap: onHome,
                    ),
                    _NavItem(
                      icon: Icons.checklist,
                      label: 'المهام',
                      active: activeIndex == 1,
                      onTap: onTasks,
                    ),
                    const SizedBox(width: 60), // Space for FAB
                    _NavItem(
                      icon: Icons.storefront_outlined,
                      label: 'الموردين',
                      active: activeIndex == 3,
                      onTap: onVendors,
                    ),
                    _NavItem(
                      icon: Icons.grid_view_rounded,
                      label: 'المزيد',
                      active: activeIndex == 0,
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -24,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DashboardUiColors.maroon,
                      boxShadow: [
                        BoxShadow(
                          color: DashboardUiColors.maroon.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.dMaroon : AppTheme.dMuted;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: SizedBox(width: 60, child: content),
    );
  }
}

// ============================================================================
// ACCOUNT SHEET (profile + logout)
// ============================================================================
