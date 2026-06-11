import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../providers/home_dashboard_provider.dart';

class HomeUiColors {
  static const maroon = Color(0xFF8B1A3F);
  static const ink = Color(0xFF332B2B);
  static const muted = Color(0xFF8B8484);
  static const gold = Color(0xFFD6A451);
  static const goldSoft = Color(0xFFEEDBB6);
  static const card = Colors.white;
  static const background = Color(0xFFFCF6F4);

  static const pinkSoft = Color(0xFFFFE7EC);
  static const greenSoft = Color(0xFFEAF7E6);
  static const blueSoft = Color(0xFFE9F1FF);
  static const purpleSoft = Color(0xFFF2ECFF);
  static const orangeSoft = Color(0xFFFFF0E6);
}

String _formatDate(DateTime? date) {
  if (date == null) return 'غير محدد';
  const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatNumber(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return rounded < 0 ? '-$buffer' : buffer.toString();
}

double _money(Object? value) {
  if (value == null) return 0;
  return double.tryParse(value.toString()) ?? 0;
}

// -----------------------------------------------------------------------------
// LOADING & ERROR
// -----------------------------------------------------------------------------

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: HomeUiColors.maroon));
}

class HomeErrorCard extends StatelessWidget {
  const HomeErrorCard({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: HomeUiColors.maroon)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: HomeUiColors.maroon),
            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TOP HEADER
// -----------------------------------------------------------------------------

class HomeTopHeader extends StatelessWidget {
  const HomeTopHeader({required this.userName, required this.onLogout, super.key});
  final String? userName;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final greetingName = (userName?.trim().isNotEmpty ?? false) ? userName!.trim() : 'رشاد';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'أعرست',
                        style: TextStyle(color: HomeUiColors.maroon, fontSize: 32, fontWeight: FontWeight.w900, height: 1.0),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.favorite, color: HomeUiColors.maroon, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'مساء الخير، $greetingName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: HomeUiColors.muted, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.favorite, color: HomeUiColors.gold, size: 14),
                  ],
                ),
              ],
            ),
        ),
        Row(
          children: [
            _HeaderCircleIcon(
              icon: Icons.person_outline_rounded,
              borderColor: HomeUiColors.gold,
              onTap: onLogout,
            ),
            const SizedBox(width: 12),
            _HeaderCircleIcon(
              icon: Icons.notifications_none_rounded,
              badgeCount: 3,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  const _HeaderCircleIcon({required this.icon, this.badgeCount, this.borderColor, required this.onTap});
  final IconData icon;
  final int? badgeCount;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor ?? const Color(0xFFEAEAEA), width: 1.5),
            ),
            child: Icon(icon, color: HomeUiColors.maroon, size: 24),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: HomeUiColors.maroon, shape: BoxShape.circle),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HERO BANNER
// -----------------------------------------------------------------------------

class HomeCommandHero extends StatelessWidget {
  const HomeCommandHero({required this.provider, super.key});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;
    if (plan == null) {
      return Container(
        decoration: BoxDecoration(color: HomeUiColors.maroon, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(20),
        child: const Center(child: Text('لا توجد خطة زفاف حالية', style: TextStyle(color: Colors.white))),
      );
    }

    final tasks = provider.tasks ?? [];
    final completedTasks = tasks.where((t) => t.isDone).length;
    final totalTasks = tasks.length;
    final progressPct = totalTasks == 0 ? 0 : ((completedTasks / totalTasks) * 100).round();
    final progressVal = totalTasks == 0 ? 0.0 : (completedTasks / totalTasks);
    
    // Remaining days
    int remainingDays = 0;
    if (plan.weddingDate != null) {
      final diff = plan.weddingDate!.difference(DateTime.now());
      remainingDays = diff.isNegative ? 0 : diff.inDays;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1A3F), Color(0xFF5D0A24)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: HomeUiColors.maroon.withAlpha(40), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite_border, color: HomeUiColors.goldSoft, size: 22),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(plan.weddingDate),
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'أنت في الطريق الصحيح!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.auto_awesome, color: HomeUiColors.gold, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedTasks من $totalTasks مهمة مكتملة',
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 6,
                    backgroundColor: Colors.white.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation<Color>(HomeUiColors.goldSoft),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'تبقى $remainingDays يوم',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeroRingProgress(progressPct: progressPct),
                const SizedBox(height: 16),
                _HeroButton(onTap: () {
                  context.push(AppRouter.weddingPlanDashboard(plan.id));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRingProgress extends StatelessWidget {
  const _HeroRingProgress({required this.progressPct});
  final int progressPct;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 86, height: 86,
                child: CircularProgressIndicator(
                  value: progressPct / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withAlpha(30),
                  valueColor: const AlwaysStoppedAnimation<Color>(HomeUiColors.goldSoft),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$progressPct%',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('مكتمل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chevron_left, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Flexible(child: Text('استكمال المهام', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// METRICS & BUDGET
// -----------------------------------------------------------------------------

class HomeMetricsBudgetSection extends StatelessWidget {
  const HomeMetricsBudgetSection({required this.provider, super.key});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _QuickGlanceCard(provider: provider)),
        const SizedBox(width: 12),
        Expanded(child: _BudgetSummaryCard(provider: provider)),
      ],
    );
  }
}

class _QuickGlanceCard extends StatelessWidget {
  const _QuickGlanceCard({required this.provider});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final tasks = provider.tasks ?? [];
    final completedTasks = tasks.where((t) => t.isDone).length;
    final tasksVal = '$completedTasks/${tasks.length}';
    final vendorsCount = 12; // Placeholder as requested
    final guestsCount = 246; // Placeholder as requested
    final paymentsCount = 8; // Placeholder as requested

    return Container(
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.remove_red_eye_outlined, color: HomeUiColors.maroon, size: 20),
              SizedBox(width: 6),
              Flexible(child: Text('نظرة سريعة', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HomeUiColors.ink))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStatBox(title: 'المهام', value: tasksVal, icon: Icons.assignment_outlined, color: HomeUiColors.pinkSoft, iconColor: Colors.pink)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatBox(title: 'الموردين', value: vendorsCount.toString(), icon: Icons.people_alt_outlined, color: HomeUiColors.greenSoft, iconColor: Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStatBox(title: 'المدفوعات', value: paymentsCount.toString(), icon: Icons.credit_card_outlined, color: HomeUiColors.purpleSoft, iconColor: Colors.purple)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatBox(title: 'الضيوف', value: guestsCount.toString(), icon: Icons.groups_outlined, color: HomeUiColors.orangeSoft, iconColor: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({required this.title, required this.value, required this.icon, required this.color, required this.iconColor});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HomeUiColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HomeUiColors.muted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 4),
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: HomeUiColors.ink))),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({required this.provider});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;
    final planBudget = plan != null ? _money(plan.estimatedBudget) : 10000000.0;
    final spent = provider.expenseSummary != null ? _money(provider.expenseSummary!.totalPaid) : 6250000.0;
    final remaining = math.max(0.0, planBudget - spent);
    final spentRatio = planBudget > 0 ? (spent / planBudget).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.account_balance_wallet_outlined, color: HomeUiColors.maroon, size: 20),
              SizedBox(width: 6),
              Flexible(child: Text('ملخص الميزانية', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HomeUiColors.ink))),
            ],
          ),
          const SizedBox(height: 16),
          const Text('إجمالي الميزانية', style: TextStyle(fontSize: 12, color: HomeUiColors.muted, fontWeight: FontWeight.w700)),
          Text('${_formatNumber(planBudget)} ر.ي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: HomeUiColors.ink)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CustomPaint(painter: _BudgetDonutPainter(spentRatio: spentRatio)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(label: 'المصروف', value: '${_formatNumber(spent)} ر.ي', color: HomeUiColors.maroon),
                    const SizedBox(height: 12),
                    _LegendItem(label: 'المتبقي', value: '${_formatNumber(remaining)} ر.ي', color: HomeUiColors.gold),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('عرض التفاصيل >', style: TextStyle(color: HomeUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: HomeUiColors.muted)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: HomeUiColors.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetDonutPainter extends CustomPainter {
  final double spentRatio;
  _BudgetDonutPainter({required this.spentRatio});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = HomeUiColors.goldSoft;
    canvas.drawCircle(center, radius, trackPaint);
    
    final spentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt
      ..color = HomeUiColors.maroon;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * spentRatio,
      false,
      spentPaint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// QUICK ACTIONS
// -----------------------------------------------------------------------------

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.provider, required this.onNeedPlan, super.key});
  final HomeDashboardProvider provider;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.bolt, color: HomeUiColors.gold, size: 20),
                SizedBox(width: 6),
                Text('إجراءات سريعة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HomeUiColors.ink)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _QuickActionItem(label: 'نفقات سريعة', icon: Icons.add, isPrimary: true, onTap: () {
                  if (provider.primaryPlan != null) {
                    context.push(AppRouter.createExpense(provider.primaryPlan!.id));
                  } else {
                    onNeedPlan();
                  }
                }),
                _QuickActionItem(label: 'قائمة الضيوف', icon: Icons.people_outline, onTap: () {}),
                _QuickActionItem(label: 'جدول الزواج', icon: Icons.calendar_today_outlined, onTap: () {}),
                _QuickActionItem(label: 'الموردين', icon: Icons.person_outline, onTap: () {}),
                _QuickActionItem(label: 'الميزانية', icon: Icons.account_balance_wallet_outlined, onTap: () {}),
                _QuickActionItem(label: 'قائمة المهام', icon: Icons.assignment_outlined, onTap: () {
                  if (provider.primaryPlan != null) {
                    context.push(AppRouter.createTask(provider.primaryPlan!.id));
                  } else {
                    onNeedPlan();
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.label, required this.icon, this.isPrimary = false, required this.onTap});
  final String label;
  final IconData icon;
  final bool isPrimary;
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
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isPrimary ? HomeUiColors.maroon.withAlpha(50) : const Color(0xFFF0F0F0)),
                color: Colors.white,
              ),
              child: Icon(icon, color: isPrimary ? HomeUiColors.maroon : HomeUiColors.ink, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HomeUiColors.ink)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// IMPORTANT NOTES (Replaces Alerts)
// -----------------------------------------------------------------------------

class HomeImportantNotesList extends StatelessWidget {
  const HomeImportantNotesList({required this.provider, super.key});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bookmark_outline, color: HomeUiColors.maroon, size: 20),
                    SizedBox(width: 6),
                    Flexible(child: Text('ملاحظات مهمة', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HomeUiColors.ink))),
                  ],
                ),
              ),
              const Text('عرض الكل', style: TextStyle(color: HomeUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: HomeUiColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const _NoteItem(
                  title: 'تجربة فستان الزفاف',
                  subtitle: 'الأحد، 15 يونيو 2026 - 4:00 مساءً',
                  trailingIcon: Icons.calendar_today_outlined,
                ),
                const Divider(height: 24, color: Color(0xFFE5E5E5)),
                const _NoteItem(
                  title: 'تأكيد الحجز في قاعة سمو',
                  subtitle: 'قبل 30 يونيو 2026',
                  trailingColor: HomeUiColors.gold,
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
  const _NoteItem({required this.title, required this.subtitle, this.trailingIcon, this.trailingColor});
  final String title, subtitle;
  final IconData? trailingIcon;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (trailingIcon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Icon(trailingIcon, color: HomeUiColors.maroon, size: 16),
          )
        else if (trailingColor != null)
          Container(
            width: 12, height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: trailingColor, shape: BoxShape.circle),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: HomeUiColors.ink)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: HomeUiColors.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left, color: HomeUiColors.muted, size: 20),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SHARED PLANS
// -----------------------------------------------------------------------------

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({required this.provider, super.key});
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: HomeUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.people_outline, color: HomeUiColors.maroon, size: 20),
                    SizedBox(width: 6),
                    Flexible(child: Text('الخطط المشتركة', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HomeUiColors.ink))),
                  ],
                ),
              ),
              const Text('عرض الكل', style: TextStyle(color: HomeUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: HomeUiColors.maroon, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('خطة عائلتنا', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: HomeUiColors.ink)),
                    Text('آخر تحديث: اليوم، 9:20 ص', style: TextStyle(fontSize: 12, color: HomeUiColors.muted)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: HomeUiColors.goldSoft, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Text('+2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HomeUiColors.muted)),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, color: HomeUiColors.muted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BOTTOM NAVIGATION
// -----------------------------------------------------------------------------

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({required this.provider, required this.onNeedPlan, super.key});
  final HomeDashboardProvider provider;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Expanded(child: _NavItem(icon: Icons.home_rounded, label: 'الرئيسية', isActive: true)),
              const Expanded(child: _NavItem(icon: Icons.calendar_today_outlined, label: 'المهام', isActive: false)),
              const SizedBox(width: 60), // Space for FAB
              const Expanded(child: _NavItem(icon: Icons.assignment_ind_outlined, label: 'الموردين', isActive: false)),
              const Expanded(child: _NavItem(icon: Icons.grid_view_rounded, label: 'المزيد', isActive: false)),
            ],
          ),
        ),
        Positioned(
          bottom: 25,
          child: InkWell(
            onTap: onNeedPlan,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeUiColors.maroon,
                boxShadow: [
                  BoxShadow(color: HomeUiColors.maroon.withAlpha(80), blurRadius: 12, offset: const Offset(0, 6)),
                ]
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.isActive});
  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? HomeUiColors.maroon : HomeUiColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}
