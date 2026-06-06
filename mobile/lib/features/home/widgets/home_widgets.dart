import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../debts/models/installment.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import '../providers/home_dashboard_provider.dart';

const _cardBorder = Color(0xFFEDE7DF);
const _mutedText = Color(0xFF6F6764);
const _softGold = Color(0xFFF5E6B8);
const _softBurgundy = Color(0xFFF1DFE4);
const _softGreen = Color(0xFFEAF3E8);
const _softRed = Color(0xFFF3DDE1);

String _formatDate(DateTime? date) {
  if (date == null) return 'غير محدد';
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

String _formatShortDate(DateTime? date) {
  if (date == null) return 'بدون تاريخ';
  return _formatDate(date);
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

String _roleLabel(String role) {
  return switch (role) {
    'MANAGER' => 'مدير',
    'CONTRIBUTOR' => 'مساهم',
    'VIEWER' => 'مشاهد',
    'EDITOR' => 'محرر',
    _ => role,
  };
}

class HomeTopHeader extends StatelessWidget {
  const HomeTopHeader({
    required this.userName,
    required this.isDesktop,
    required this.onLogout,
    super.key,
  });

  final String? userName;
  final bool isDesktop;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final greetingName = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim()
        : 'رشاد';

    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.person,
              tooltip: 'الحساب',
              onTap: onLogout,
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.notifications_none,
              tooltip: 'التنبيهات',
              onTap: () {},
              showDot: true,
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اعّرست',
                  style: TextStyle(
                    color: AppTheme.deepBurgundy,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: isDesktop ? 82 : 70,
                  height: isDesktop ? 54 : 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 11,
                        top: 17,
                        child: _RingMark(
                          size: isDesktop ? 31 : 27,
                          color: AppTheme.deepBurgundy,
                        ),
                      ),
                      Positioned(
                        right: 13,
                        top: 16,
                        child: _RingMark(
                          size: isDesktop ? 30 : 26,
                          color: AppTheme.warmGold,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: isDesktop ? 8 : 7,
                        child: Icon(
                          Icons.diamond_outlined,
                          color: AppTheme.warmGold,
                          size: isDesktop ? 20 : 17,
                        ),
                      ),
                      Text(
                        'ع',
                        style: TextStyle(
                          color: AppTheme.deepBurgundy,
                          fontSize: isDesktop ? 50 : 42,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: isDesktop ? 360 : 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'أهلاً $greetingName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.deepBurgundy,
                  fontWeight: FontWeight.w900,
                  fontSize: isDesktop ? 29 : 21,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'هذه لمحة سريعة عن تجهيزات زفافك',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingMark extends StatelessWidget {
  const _RingMark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppTheme.deepBurgundy),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.deepBurgundy,
                      shape: BoxShape.circle,
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

class HomeCommandHero extends StatelessWidget {
  const HomeCommandHero({
    required this.provider,
    required this.isDesktop,
    super.key,
  });

  final HomeDashboardProvider provider;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;
    if (plan == null) {
      return _HeroShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ابدأ بإنشاء خطة زفافك الأولى',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أنشئ خطة لتتبع الميزانية والمهام والديون والمشاركين.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withAlpha(210),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: _HeroButton(
                label: 'إنشاء خطة زفاف',
                icon: Icons.add_box_outlined,
                onTap: () => context.push(AppRouter.createWeddingPlan),
              ),
            ),
          ],
        ),
      );
    }

    final tasks = provider.tasks ?? const <WeddingTask>[];
    final completedTasks = tasks.where((task) => task.isDone).length;
    final totalTasks = tasks.length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final progressPct = (progress * 100).round();
    final taskProgressText = totalTasks == 0
        ? 'أضف مهام الزفاف لقياس نسبة التجهيز'
        : '$completedTasks من $totalTasks مهام مكتملة';

    final heroContent = isDesktop
        ? Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeroProgress(
                progress: progress,
                progressPct: progressPct,
                taskProgressText: taskProgressText,
                compact: false,
              ),
              const SizedBox(width: 34),
              Expanded(
                child: _HeroCenterPanel(
                  progress: progress,
                  taskProgressText: taskProgressText,
                  remainingText: _remainingText(plan.weddingDate),
                  status: plan.status,
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                child: _HeroPlanInfo(
                  title: plan.title,
                  city: plan.city,
                  weddingDate: plan.weddingDate,
                  planId: plan.id,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroPlanInfo(
                title: plan.title,
                city: plan.city,
                weddingDate: plan.weddingDate,
                planId: plan.id,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroCenterPanel(
                      progress: progress,
                      taskProgressText: taskProgressText,
                      remainingText: _remainingText(plan.weddingDate),
                      status: plan.status,
                    ),
                  ),
                  const SizedBox(width: 18),
                  _HeroProgress(
                    progress: progress,
                    progressPct: progressPct,
                    taskProgressText: taskProgressText,
                    compact: true,
                  ),
                ],
              ),
            ],
          );

    return _HeroShell(child: heroContent);
  }

  String _remainingText(DateTime? date) {
    if (date == null) return 'تاريخ الزفاف غير محدد';
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'موعد الزفاف مضى';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return 'متبقي $days يوم، $hours ساعات، $minutes دقيقة';
    }
    if (hours > 0) {
      return 'متبقي $hours ساعات، $minutes دقيقة';
    }
    return 'متبقي $minutes دقيقة';
  }
}

class _HeroShell extends StatelessWidget {
  const _HeroShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF97002B), Color(0xFF650018)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBurgundy.withAlpha(60),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              left: -62,
              top: -48,
              child: _DecorativeCircle(size: 170, alpha: 22),
            ),
            Positioned(
              right: -34,
              bottom: -58,
              child: _DecorativeCircle(size: 160, alpha: 16),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Icon(
                Icons.favorite_border,
                color: Colors.white.withAlpha(14),
                size: 120,
              ),
            ),
            Padding(padding: const EdgeInsets.all(26), child: child),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.alpha});

  final double size;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(alpha), width: 24),
      ),
    );
  }
}

class _HeroPlanInfo extends StatelessWidget {
  const _HeroPlanInfo({
    required this.title,
    required this.city,
    required this.weddingDate,
    required this.planId,
  });

  final String title;
  final String? city;
  final DateTime? weddingDate;
  final String planId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _HeroMeta(icon: Icons.location_on, label: city ?? 'غير محدد'),
            _HeroMeta(icon: Icons.schedule, label: _formatDate(weddingDate)),
            const _HeroMeta(icon: Icons.calendar_today, label: 'تاريخ الزفاف'),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: _HeroButton(
            label: 'فتح لوحة التحكم',
            icon: Icons.dashboard_customize_outlined,
            onTap: () => context.push(AppRouter.weddingPlanDashboard(planId)),
          ),
        ),
      ],
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, color: Colors.white.withAlpha(210), size: 17),
      ],
    );
  }
}

class _HeroCenterPanel extends StatelessWidget {
  const _HeroCenterPanel({
    required this.progress,
    required this.taskProgressText,
    required this.remainingText,
    required this.status,
  });

  final double progress;
  final String taskProgressText;
  final String remainingText;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'حالة الخطة',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _StatusBadge(status: status),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                remainingText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.timer_outlined, color: Colors.white70, size: 19),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            color: AppTheme.warmGold,
            backgroundColor: Colors.white.withAlpha(45),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          taskProgressText,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'PLANNING' => 'قيد التخطيط',
      'ARCHIVED' => 'مؤرشفة',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.warmGold.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.warmGold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.lock_clock, color: AppTheme.warmGold, size: 14),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  const _HeroProgress({
    required this.progress,
    required this.progressPct,
    required this.taskProgressText,
    required this.compact,
  });

  final double progress;
  final int progressPct;
  final String taskProgressText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 106.0 : 144.0;
    return SizedBox(
      width: compact ? 122 : 176,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: compact ? 9 : 12,
                  color: AppTheme.warmGold,
                  backgroundColor: Colors.white.withAlpha(40),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '$progressPct%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 24 : 31,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$progressPct% مكتمل',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            taskProgressText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(28),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withAlpha(55)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class HomeMetricsBudgetSection extends StatelessWidget {
  const HomeMetricsBudgetSection({
    required this.provider,
    required this.isDesktop,
    super.key,
  });

  final HomeDashboardProvider provider;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (provider.primaryPlan == null) return const SizedBox.shrink();

    final metrics = _MetricCards(provider: provider);
    final budget = _BudgetSummaryCard(provider: provider);

    if (isDesktop) {
      return Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 430, child: metrics),
          const SizedBox(width: 18),
          Expanded(child: budget),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [metrics, const SizedBox(height: 14), budget],
    );
  }
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final tasks = _sortedUpcomingTasks(provider.tasks ?? const []);
    final installments = _sortedDueInstallments(
      provider.dueInstallments ?? const [],
    );
    final debt = provider.debtSummary;
    final totalDebt = _money(debt?.totalDebt);
    final remainingDebt = _money(debt?.remainingDebt);

    final cards = [
      _MetricCard(
        icon: Icons.task_alt,
        iconColor: const Color(0xFF2F8D4B),
        title: 'المهام القادمة',
        value: '${tasks.length}',
        subtitle: 'مهمة',
        footerTitle: tasks.isEmpty ? 'لا توجد مهام قادمة' : 'أقرب مهمة',
        footerValue: tasks.isEmpty
            ? ''
            : '${tasks.first.title}\n${_formatShortDate(tasks.first.dueDate)}',
      ),
      _MetricCard(
        icon: Icons.event_note,
        iconColor: const Color(0xFFC66B35),
        title: 'الأقساط القريبة',
        value: '${installments.length}',
        subtitle: 'قسط',
        footerTitle: installments.isEmpty ? 'لا توجد أقساط قريبة' : 'المبلغ',
        footerValue: installments.isEmpty
            ? ''
            : '${_formatNumber(_money(installments.first.amount))} YER\n${_formatShortDate(installments.first.dueDate)}',
      ),
      _MetricCard(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: AppTheme.deepBurgundy,
        title: 'الديون',
        value: _formatNumber(totalDebt),
        subtitle: 'YER',
        footerTitle: totalDebt <= 0 ? 'لا توجد ديون' : 'المتبقي',
        footerValue: totalDebt <= 0
            ? ''
            : '${_formatNumber(remainingDebt)} YER',
      ),
    ];

    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.footerTitle,
    required this.footerValue,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final String footerTitle;
  final String footerValue;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _mutedText, fontSize: 12),
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: _cardBorder),
          const SizedBox(height: 10),
          Text(
            footerTitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (footerValue.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              footerValue,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.deepBurgundy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
    final plan = provider.primaryPlan!;
    final expense = provider.expenseSummary;
    final debt = provider.debtSummary;
    final planBudget = _money(plan.estimatedBudget);
    final summaryBudget = _money(expense?.totalPlanned);
    final totalBudget = planBudget > 0 ? planBudget : summaryBudget;
    final spent = _money(expense?.totalPaid);
    final remaining = totalBudget > 0
        ? math.max(0.0, totalBudget - spent)
        : 0.0;
    final totalDebt = _money(debt?.totalDebt);
    final dueInstallments = provider.dueInstallments ?? const <Installment>[];
    final dueAmount = dueInstallments.fold<double>(
      0,
      (sum, item) => sum + _money(item.amount),
    );
    final commitments = totalDebt + dueAmount;
    final hasBudget = totalBudget > 0;
    final spentRatio = hasBudget
        ? (spent / totalBudget).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final debtRatio = hasBudget
        ? (totalDebt / totalBudget).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final commitmentRatio = hasBudget
        ? (commitments / totalBudget).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _softGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: AppTheme.warmGold,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ملخص الميزانية',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasBudget)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softBurgundy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'لم تحدد الميزانية بعد',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppTheme.deepBurgundy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Text(
              '${_formatNumber(totalBudget)} ${plan.currency}',
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _BudgetLine(
                      label: 'الميزانية الكلية',
                      value: hasBudget
                          ? '${_formatNumber(totalBudget)} ${plan.currency}'
                          : 'غير محددة',
                      dotColor: AppTheme.warmGold,
                    ),
                    _BudgetLine(
                      label: 'المصروف',
                      value: '${_formatNumber(spent)} ${plan.currency}',
                      dotColor: AppTheme.deepBurgundy,
                    ),
                    _BudgetLine(
                      label: 'المتبقي',
                      value: hasBudget
                          ? '${_formatNumber(remaining)} ${plan.currency}'
                          : 'غير محسوب',
                      dotColor: Colors.grey,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _BudgetDonut(
                  spentRatio: spentRatio,
                  debtRatio: debtRatio,
                  commitmentRatio: commitmentRatio,
                  hasBudget: hasBudget,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _BudgetLine(
                      label: 'الديون',
                      value: '${_formatNumber(totalDebt)} ${plan.currency}',
                      dotColor: AppTheme.deepBurgundy,
                    ),
                    _BudgetLine(
                      label: 'الأقساط القادمة',
                      value: '${_formatNumber(dueAmount)} ${plan.currency}',
                      dotColor: AppTheme.warmGold,
                    ),
                    _BudgetLine(
                      label: 'الالتزامات القادمة',
                      value: '${_formatNumber(commitments)} ${plan.currency}',
                      dotColor: const Color(0xFFC0932F),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SegmentedBudgetBar(
            spentRatio: spentRatio,
            debtRatio: debtRatio,
            commitmentRatio: commitmentRatio,
            hasBudget: hasBudget,
          ),
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  final String label;
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _mutedText, fontSize: 11),
                ),
                Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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

class _BudgetDonut extends StatelessWidget {
  const _BudgetDonut({
    required this.spentRatio,
    required this.debtRatio,
    required this.commitmentRatio,
    required this.hasBudget,
  });

  final double spentRatio;
  final double debtRatio;
  final double commitmentRatio;
  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(
        painter: _BudgetDonutPainter(
          spentRatio: spentRatio,
          debtRatio: debtRatio,
          commitmentRatio: commitmentRatio,
          hasBudget: hasBudget,
        ),
        child: Center(
          child: Text(
            hasBudget ? '${(spentRatio * 100).round()}%' : '—',
            style: const TextStyle(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetDonutPainter extends CustomPainter {
  const _BudgetDonutPainter({
    required this.spentRatio,
    required this.debtRatio,
    required this.commitmentRatio,
    required this.hasBudget,
  });

  final double spentRatio;
  final double debtRatio;
  final double commitmentRatio;
  final bool hasBudget;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFE2DED8);

    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (!hasBudget) return;

    final segments = [
      (spentRatio, AppTheme.deepBurgundy),
      (debtRatio, const Color(0xFF9A1235)),
      (commitmentRatio, AppTheme.warmGold),
    ];
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.max(0.03, segment.$1) * math.pi * 1.65;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt
        ..color = segment.$2;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + 0.08;
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetDonutPainter oldDelegate) {
    return spentRatio != oldDelegate.spentRatio ||
        debtRatio != oldDelegate.debtRatio ||
        commitmentRatio != oldDelegate.commitmentRatio ||
        hasBudget != oldDelegate.hasBudget;
  }
}

class _SegmentedBudgetBar extends StatelessWidget {
  const _SegmentedBudgetBar({
    required this.spentRatio,
    required this.debtRatio,
    required this.commitmentRatio,
    required this.hasBudget,
  });

  final double spentRatio;
  final double debtRatio;
  final double commitmentRatio;
  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    if (!hasBudget) {
      return Container(
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E0D8),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            Expanded(
              flex: math.max(1, (spentRatio * 100).round()),
              child: Container(color: AppTheme.deepBurgundy),
            ),
            Expanded(
              flex: math.max(1, (debtRatio * 100).round()),
              child: Container(color: const Color(0xFF9A1235)),
            ),
            Expanded(
              flex: math.max(1, (commitmentRatio * 100).round()),
              child: Container(color: AppTheme.warmGold),
            ),
            Expanded(
              flex: math.max(
                1,
                ((1 - math.min(1.0, spentRatio + debtRatio + commitmentRatio)) *
                        100)
                    .round(),
              ),
              child: Container(color: const Color(0xFFE2DED8)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    required this.provider,
    required this.isDesktop,
    required this.onNeedPlan,
    super.key,
  });

  final HomeDashboardProvider provider;
  final bool isDesktop;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    final planId = provider.primaryPlan?.id;
    final actions = [
      _QuickAction(
        label: 'خطة جديدة',
        icon: Icons.add_box_outlined,
        color: AppTheme.warmGold,
        enabled: true,
        onTap: () => context.push(AppRouter.createWeddingPlan),
      ),
      _QuickAction(
        label: 'إضافة عضو',
        icon: Icons.person_add_alt,
        color: const Color(0xFF236B92),
        enabled: planId != null,
        onTap: () => context.push(AppRouter.addSharedMember(planId ?? '')),
      ),
      _QuickAction(
        label: 'إضافة مهمة',
        icon: Icons.task_alt,
        color: const Color(0xFF2F8D4B),
        enabled: planId != null,
        onTap: () => context.push(AppRouter.createTask(planId ?? '')),
      ),
      _QuickAction(
        label: 'إضافة دين',
        icon: Icons.credit_card,
        color: AppTheme.deepBurgundy,
        enabled: planId != null,
        onTap: () => context.push(AppRouter.createDebt(planId ?? '')),
      ),
      _QuickAction(
        label: 'إضافة مصروف',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.deepBurgundy,
        enabled: planId != null,
        onTap: () => context.push(AppRouter.createExpense(planId ?? '')),
      ),
    ];

    final content = isDesktop
        ? Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Expanded(
                  child: _QuickActionCard(
                    action: actions[i],
                    onNeedPlan: onNeedPlan,
                  ),
                ),
                if (i != actions.length - 1) const SizedBox(width: 12),
              ],
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: [
                for (final action in actions)
                  SizedBox(
                    width: 132,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _QuickActionCard(
                        action: action,
                        onNeedPlan: onNeedPlan,
                      ),
                    ),
                  ),
              ],
            ),
          );

    return _SectionShell(title: 'إجراءات سريعة ⚡', child: content);
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onNeedPlan});

  final _QuickAction action;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.enabled ? action.onTap : onNeedPlan,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: action.enabled ? 1 : 0.54,
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 27),
              const SizedBox(height: 9),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.charcoal,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeAlertsMembersGrid extends StatelessWidget {
  const HomeAlertsMembersGrid({
    required this.provider,
    required this.isDesktop,
    super.key,
  });

  final HomeDashboardProvider provider;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final alerts = HomeAlertsCard(provider: provider);
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeMembersCard(provider: provider),
        const SizedBox(height: 18),
        HomeSharedPlansCard(provider: provider),
      ],
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [alerts, const SizedBox(height: 18), side],
      );
    }

    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: alerts),
        const SizedBox(width: 18),
        Expanded(child: side),
      ],
    );
  }
}

class HomeAlertsCard extends StatelessWidget {
  const HomeAlertsCard({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts();

    return _SectionShell(
      title: 'تنبيهات مهمة 🔔',
      titleIcon: Icons.notifications_active_outlined,
      child: _SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: alerts.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'لا توجد تنبيهات مهمة حالياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]
              : alerts.take(3).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildAlerts() {
    final alerts = <Widget>[];
    final installments = _sortedDueInstallments(
      provider.dueInstallments ?? const [],
    );
    if (installments.isNotEmpty) {
      final item = installments.first;
      alerts.add(
        _AlertItem(
          icon: Icons.event_busy,
          background: _softRed,
          iconColor: AppTheme.deepBurgundy,
          title: 'قسط قريب الاستحقاق',
          message: 'لديك قسط بقيمة ${_formatNumber(_money(item.amount))} YER',
          detail: _dueText(item.dueDate),
        ),
      );
    }

    final plan = provider.primaryPlan;
    final budget = math.max(
      _money(plan?.estimatedBudget),
      _money(provider.expenseSummary?.totalPlanned),
    );
    final spent = _money(provider.expenseSummary?.totalPaid);
    if (budget > 0 && spent > 0) {
      final spentPct = ((spent / budget) * 100).clamp(0, 999).round();
      alerts.add(
        _AlertItem(
          icon: Icons.trending_up,
          background: const Color(0xFFF3E7D2),
          iconColor: const Color(0xFFB57A13),
          title: 'مصروفات مرتفعة',
          message: 'لقد وصلت المصروفات إلى $spentPct% من إجمالي الميزانية',
          detail: 'راجع ملخص الميزانية',
        ),
      );
    }

    final tasks = _sortedUpcomingTasks(provider.tasks ?? const []);
    if (tasks.isNotEmpty) {
      final task = tasks.first;
      alerts.add(
        _AlertItem(
          icon: Icons.fact_check_outlined,
          background: _softGreen,
          iconColor: const Color(0xFF2F8D4B),
          title: 'مهمة قريبة',
          message: task.title,
          detail: _formatShortDate(task.dueDate),
        ),
      );
    }

    return alerts;
  }

  String _dueText(DateTime? dueDate) {
    if (dueDate == null) return 'بدون تاريخ محدد';
    final diff = dueDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'يستحق اليوم';
    return 'يستحق خلال $diff أيام';
  }
}

class _AlertItem extends StatelessWidget {
  const _AlertItem({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.detail,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final String title;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMembersCard extends StatelessWidget {
  const HomeMembersCard({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final members = provider.sharedMembers ?? const <SharedMember>[];
    final planId = provider.primaryPlan?.id;

    return _SectionShell(
      title: 'المشاركون في الخطة',
      trailing: '${members.length} عضو',
      titleIcon: Icons.groups,
      child: _SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا يوجد مشاركون في هذه الخطة بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _mutedText),
                ),
              )
            else
              for (final member in members.take(3)) ...[
                _MemberRow(member: member),
                if (member != members.take(3).last) const SizedBox(height: 9),
              ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: planId == null
                    ? null
                    : () => context.push(AppRouter.addSharedMember(planId)),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('إضافة عضو'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.deepBurgundy,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final SharedMember member;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName;
    final phone = member.displaySubtitle ?? 'بدون رقم هاتف';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _softBurgundy,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  phone,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _softGold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _roleLabel(member.role),
              style: const TextStyle(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '؟';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return String.fromCharCode(parts.first.runes.first);
    return '${String.fromCharCode(parts.first.runes.first)}${String.fromCharCode(parts.last.runes.first)}';
  }
}

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final sharedCount = provider.sharedPlans.length;

    return _SectionShell(
      title: 'الخطط المشتركة معي',
      trailing: '$sharedCount خطة مشتركة',
      titleIcon: Icons.group_work,
      child: _SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => context.push(AppRouter.sharedWeddingPlans),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softBurgundy,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: AppTheme.deepBurgundy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sharedCount == 0
                        ? 'لا توجد خطط مشتركة حالياً'
                        : 'عرض الخطط المشتركة',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppTheme.deepBurgundy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _softGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_shared,
                    color: AppTheme.deepBurgundy,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    required this.provider,
    required this.onNeedPlan,
    super.key,
  });

  final HomeDashboardProvider provider;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    final planId = provider.primaryPlan?.id;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: NavigationBar(
        height: 70,
        selectedIndex: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: _softBurgundy,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 0) return;
          if (index == 1) {
            context.go(AppRouter.weddingPlans);
            return;
          }
          if (index == 2) {
            context.push(AppRouter.createWeddingPlan);
            return;
          }
          if (index == 3) {
            if (planId == null) {
              onNeedPlan();
            } else {
              context.push(AppRouter.tasks(planId));
            }
            return;
          }
          if (index == 4) {
            context.push(AppRouter.sharedWeddingPlans);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'الخطط'),
          NavigationDestination(
            icon: Icon(Icons.add_circle, size: 34),
            label: '',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'المهام'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'المزيد'),
        ],
      ),
    );
  }
}

class HomeErrorCard extends StatelessWidget {
  const HomeErrorCard({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonBlock(height: 214, radius: 24, color: AppTheme.deepBurgundy),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: _SkeletonBlock(height: 150)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 150)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 150)),
          ],
        ),
        const SizedBox(height: 18),
        const _SkeletonBlock(height: 90),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: _SkeletonBlock(height: 230)),
            SizedBox(width: 18),
            Expanded(child: _SkeletonBlock(height: 230)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.radius = 18, this.color});

  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color?.withAlpha(120) ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _cardBorder),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.trailing,
    this.titleIcon,
  });

  final String title;
  final String? trailing;
  final IconData? titleIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: _mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            if (titleIcon != null) ...[
              const SizedBox(width: 8),
              Icon(titleIcon, color: AppTheme.deepBurgundy, size: 21),
            ],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

List<WeddingTask> _sortedUpcomingTasks(List<WeddingTask> tasks) {
  final upcoming = tasks.where((task) => !task.isDone).toList();
  upcoming.sort((a, b) {
    final aDate = a.dueDate ?? DateTime(3000);
    final bDate = b.dueDate ?? DateTime(3000);
    return aDate.compareTo(bDate);
  });
  return upcoming;
}

List<Installment> _sortedDueInstallments(List<Installment> installments) {
  final pending = installments.where((item) => item.status != 'PAID').toList();
  pending.sort((a, b) {
    final aDate = a.dueDate ?? DateTime(3000);
    final bDate = b.dueDate ?? DateTime(3000);
    return aDate.compareTo(bDate);
  });
  return pending;
}
