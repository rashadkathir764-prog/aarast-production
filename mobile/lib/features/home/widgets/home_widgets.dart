import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/home_dashboard_provider.dart';

const _arMonths = <String>[
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

String _formatDate(DateTime? date) {
  if (date == null) return 'غير محدد';
  return '${date.day} ${_arMonths[date.month - 1]} ${date.year}';
}

String _formatNumber(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return rounded < 0 ? '-$buffer' : buffer.toString();
}

double _money(Object? value) {
  if (value == null) return 0;
  return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
}

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _skeletonBox(height: 180),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _skeletonBox(height: 160)),
            const SizedBox(width: 12),
            Expanded(child: _skeletonBox(height: 160)),
          ],
        ),
        const SizedBox(height: 16),
        _skeletonBox(height: 118),
      ],
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.dCard2.withAlpha(180),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
    return AarastCard(
      color: AppTheme.dPinkBg.withAlpha(210),
      border: Border.all(color: AppTheme.danger.withAlpha(70)),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class HomeTopHeader extends StatelessWidget {
  const HomeTopHeader({
    required this.userName,
    required this.onNotifications,
    required this.onLogout,
    super.key,
  });

  final String? userName;
  final VoidCallback onNotifications;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final name = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim().split(RegExp(r'\s+')).first
        : 'رشاد';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'أعرسِت',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppTheme.dMaroon,
                      fontFamily: AppTheme.displayFontFamily,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Positioned(
                    top: -4,
                    right: 82,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.dMaroon,
                      size: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'مساء الخير، $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.dGoldDeep,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderCircleIcon(
          icon: Icons.person_outline_rounded,
          borderColor: AppTheme.dGold2,
          onTap: onLogout,
        ),
        const SizedBox(width: 10),
        _HeaderCircleIcon(
          icon: Icons.notifications_none_rounded,
          badgeCount: 3,
          onTap: onNotifications,
        ),
      ],
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  const _HeaderCircleIcon({
    required this.icon,
    required this.onTap,
    this.badgeCount,
    this.borderColor,
  });

  final IconData icon;
  final int? badgeCount;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.dCard2,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor ?? AppTheme.dLine),
                  boxShadow: AppTheme.softShadow(opacity: 0.04),
                ),
                child: Icon(icon, color: AppTheme.dMaroon, size: 23),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dCard2, width: 2),
                  ),
                  child: Text(
                    '$badgeCount',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeCommandHero extends StatelessWidget {
  const HomeCommandHero({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;
    if (plan == null) {
      return AarastEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'لا توجد خطة زفاف حالية',
        message: 'ابدئي بإنشاء خطة واضحة لتظهر الميزانية والمهام هنا.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => context.push(AppRouter.createWeddingPlan),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إنشاء خطة زفاف'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.weddingPlans),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('عرض كل الخطط'),
            ),
          ],
        ),
      );
    }

    final tasks = provider.tasks ?? [];
    final completedTasks = tasks.where((task) => task.isDone).length;
    final totalTasks = tasks.length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final progressPct = (progress * 100).round();
    final remainingDays = math.max(plan.daysRemaining ?? 0, 0);

    return Container(
      decoration: AppTheme.heroDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroFloralPainter())),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 345;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  Icons.favorite_border_rounded,
                                  color: AppTheme.dGold2,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    plan.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(plan.weddingDate),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withAlpha(205),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'أنتِ في الطريق الصحيح!',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedTasks من $totalTasks مهمة مكتملة',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withAlpha(205),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 16),
                        _HeroProgressRing(progressPct: progressPct),
                      ],
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _HeroProgressRing(progressPct: progressPct),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withAlpha(45),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.dGold2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (constraints.maxWidth < 380) ...[
                    _HeroMeta(
                      icon: Icons.calendar_today_outlined,
                      label: 'تبقى $remainingDays يوم',
                    ),
                    const SizedBox(height: 12),
                    _HeroActionButton(
                      onPressed: () {
                        context.push(AppRouter.weddingPlanDashboard(plan.id));
                      },
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMeta(
                            icon: Icons.calendar_today_outlined,
                            label: 'تبقى $remainingDays يوم',
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HeroActionButton(
                          onPressed: () {
                            context.push(
                              AppRouter.weddingPlanDashboard(plan.id),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class HomePlanControls extends StatelessWidget {
  const HomePlanControls({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(12),
      color: AppTheme.dCard2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 350;
          final buttons = [
            OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.weddingPlans),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('عرض كل الخطط'),
            ),
            FilledButton.icon(
              onPressed: () => context.push(AppRouter.weddingPlans),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('تبديل الخطة'),
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [buttons[0], const SizedBox(height: 8), buttons[1]],
            );
          }

          return Row(
            children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: 10),
              Expanded(child: buttons[1]),
            ],
          );
        },
      ),
    );
  }
}

class _HeroProgressRing extends StatelessWidget {
  const _HeroProgressRing({required this.progressPct});

  final int progressPct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _RingPainter(progress: progressPct / 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$progressPct%',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مكتمل',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(215),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
      children: [
        Icon(icon, color: AppTheme.dGold2, size: 17),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withAlpha(95)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: const Icon(Icons.chevron_left_rounded, size: 18),
      label: const Text(
        'استكمال المهام',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class HomeMetricsBudgetSection extends StatelessWidget {
  const HomeMetricsBudgetSection({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final budget = _BudgetSummaryCard(provider: provider);
        final glance = _QuickGlanceCard(provider: provider);

        if (constraints.maxWidth < 470) {
          return Column(children: [budget, const SizedBox(height: 14), glance]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: budget),
            const SizedBox(width: 14),
            Expanded(child: glance),
          ],
        );
      },
    );
  }
}

class _QuickGlanceCard extends StatelessWidget {
  const _QuickGlanceCard({required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final tasks = provider.tasks ?? [];
    final completedTasks = tasks.where((task) => task.isDone).length;
    final paymentCount =
        (provider.expenseSummary?.countPaid ?? 0) +
        (provider.expenseSummary?.countPlanned ?? 0);

    return AarastCard(
      padding: const EdgeInsets.all(14),
      radius: AppTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            title: 'نظرة سريعة',
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatBox(
                  title: 'الموردين',
                  value: 'متاح',
                  icon: Icons.groups_rounded,
                  color: AppTheme.dGreen,
                  bg: AppTheme.dGreenBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  title: 'المهام',
                  value: '$completedTasks/${tasks.length}',
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppTheme.dMaroon,
                  bg: AppTheme.dPinkBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniStatBox(
                  title: 'الضيوف',
                  value: 'جاهز',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.dGoldDeep,
                  bg: AppTheme.dCreamBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  title: 'المدفوعات',
                  value: '$paymentCount',
                  icon: Icons.credit_card_rounded,
                  color: AppTheme.dBlue,
                  bg: AppTheme.dBlueBg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
            ),
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
    final total = plan != null ? _money(plan.estimatedBudget) : 0.0;
    final spent = _money(provider.expenseSummary?.totalPaid);
    final remaining = math.max(0.0, total - spent);
    final spentRatio = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    return AarastCard(
      padding: const EdgeInsets.all(14),
      radius: AppTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            title: 'ملخص الميزانية',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 14),
          Text(
            'إجمالي الميزانية',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatNumber(total)} ر.ي',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CustomPaint(
                  painter: _BudgetDonutPainter(spentRatio: spentRatio),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _LegendItem(
                      label: 'المصروف',
                      value: '${_formatNumber(spent)} ر.ي',
                      color: AppTheme.dMaroon,
                    ),
                    const SizedBox(height: 10),
                    _LegendItem(
                      label: 'المتبقي',
                      value: '${_formatNumber(remaining)} ر.ي',
                      color: AppTheme.dGoldDeep,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InlineLink(
            label: 'عرض التفاصيل',
            onTap: plan == null
                ? null
                : () => context.push(AppRouter.finance(plan.id)),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.dMaroon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    required this.provider,
    required this.onNeedPlan,
    super.key,
  });

  final HomeDashboardProvider provider;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;

    return AarastCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'إجراءات سريعة',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _QuickActionItem(
                  label: 'نفقات سريعة',
                  icon: Icons.add_rounded,
                  color: AppTheme.dMaroon,
                  onTap: plan == null
                      ? onNeedPlan
                      : () => context.push(AppRouter.createExpense(plan.id)),
                ),
                _QuickActionItem(
                  label: 'قائمة الضيوف',
                  icon: Icons.people_outline_rounded,
                  color: AppTheme.dGoldDeep,
                  onTap: plan == null
                      ? onNeedPlan
                      : () => context.push(AppRouter.guestList(plan.id)),
                ),
                _QuickActionItem(
                  label: 'جدول الزواج',
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.dMaroon,
                  onTap: plan == null
                      ? onNeedPlan
                      : () => context.push(AppRouter.timeline(plan.id)),
                ),
                _QuickActionItem(
                  label: 'الموردين',
                  icon: Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  onTap: () => context.push(AppRouter.providerMarketplace),
                ),
                _QuickActionItem(
                  label: 'الميزانية',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppTheme.dMaroon,
                  onTap: plan == null
                      ? onNeedPlan
                      : () => context.push(AppRouter.finance(plan.id)),
                ),
                _QuickActionItem(
                  label: 'قائمة المهام',
                  icon: Icons.assignment_turned_in_outlined,
                  color: AppTheme.dMaroon,
                  onTap: plan == null
                      ? onNeedPlan
                      : () => context.push(AppRouter.createTask(plan.id)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.dCard2,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeImportantNotesList extends StatelessWidget {
  const HomeImportantNotesList({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.primaryPlan;
    final tasks = (provider.tasks ?? [])
        .where((task) => !task.isDone)
        .take(2)
        .toList();
    final installments = (provider.dueInstallments ?? []).take(1).toList();
    final hasItems = tasks.isNotEmpty || installments.isNotEmpty;

    return AarastCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'ملاحظات مهمة',
            icon: Icons.bookmark_border_rounded,
            actionLabel: 'عرض الكل',
            onAction: () => context.push(
              plan == null
                  ? AppRouter.notifications
                  : AppRouter.planNotifications(plan.id),
            ),
          ),
          const SizedBox(height: 12),
          if (!hasItems)
            const AarastEmptyState(
              title: 'لا توجد تنبيهات قريبة',
              message: 'ستظهر المهام والأقساط القريبة هنا عند إضافتها.',
              icon: Icons.event_available_rounded,
            )
          else ...[
            for (final task in tasks) ...[
              _NoteItem(
                title: task.title,
                subtitle: task.dueDate == null
                    ? 'بدون تاريخ محدد'
                    : 'مستحقة ${_formatDate(task.dueDate)}',
                icon: Icons.calendar_today_outlined,
                tone: task.priority == 'HIGH'
                    ? AppTheme.dPinkBg
                    : AppTheme.dCreamBg,
                onTap: () => context.push(
                  plan == null
                      ? AppRouter.notifications
                      : AppRouter.planNotifications(plan.id),
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (final installment in installments)
              _NoteItem(
                title: 'قسط قريب',
                subtitle:
                    '${_formatNumber(_money(installment.amount))} ر.ي - ${_formatDate(installment.dueDate)}',
                icon: Icons.payments_outlined,
                tone: AppTheme.dCreamBg,
                onTap: () => context.push(
                  plan == null
                      ? AppRouter.notifications
                      : AppRouter.planNotifications(plan.id),
                ),
              ),
          ],
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
    required this.tone,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withAlpha(175),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.dCard2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.dMaroon, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_left_rounded,
            color: AppTheme.dInkSoft,
            size: 21,
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: content,
      ),
    );
  }
}

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({required this.provider, super.key});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasSharedPlans = provider.sharedPlans.isNotEmpty;
    final firstPlan = hasSharedPlans ? provider.sharedPlans.first : null;

    return AarastCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'الخطط المشتركة',
            icon: Icons.groups_outlined,
            actionLabel: 'عرض الكل',
            onAction: () => context.push(AppRouter.sharedWeddingPlans),
          ),
          const SizedBox(height: 12),
          if (!hasSharedPlans)
            const AarastEmptyState(
              title: 'لا توجد خطط مشتركة بعد',
              message: 'عندما يشاركك أحد أفراد العائلة خطة، ستظهر هنا.',
              icon: Icons.group_add_outlined,
            )
          else
            _SharedPlanRow(
              title: firstPlan!.title,
              subtitle: 'آخر تحديث: اليوم',
              onTap: () => context.push(AppRouter.sharedWeddingPlans),
            ),
        ],
      ),
    );
  }
}

class _SharedPlanRow extends StatelessWidget {
  const _SharedPlanRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.dLine),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.dMaroon,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppTheme.dInkSoft),
          ],
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
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 74,
          decoration: BoxDecoration(
            color: AppTheme.dCard2.withAlpha(244),
            border: const Border(top: BorderSide(color: AppTheme.dLine)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dMaroonDeep.withAlpha(18),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: const Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'الرئيسية',
                  isActive: true,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'المهام',
                  isActive: false,
                ),
              ),
              SizedBox(width: 74),
              Expanded(
                child: _NavItem(
                  icon: Icons.work_outline_rounded,
                  label: 'الموردين',
                  isActive: false,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'المزيد',
                  isActive: false,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -26,
          child: GestureDetector(
            onTap: onNeedPlan,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.heroGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.dMaroon.withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.dGold2,
                size: 34,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.dMaroon : AppTheme.dMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.dMaroon,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.dMaroon,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 9.0;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = AppTheme.dGold2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BudgetDonutPainter extends CustomPainter {
  const _BudgetDonutPainter({required this.spentRatio});

  final double spentRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppTheme.dCreamBg;
    final spentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt
      ..color = AppTheme.dMaroon;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * spentRatio.clamp(0.0, 1.0),
      false,
      spentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BudgetDonutPainter oldDelegate) {
    return oldDelegate.spentRatio != spentRatio;
  }
}

class _HeroFloralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withAlpha(18);

    final path = Path()
      ..moveTo(size.width * 0.04, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.48,
        size.width * 0.03,
        size.height * 0.14,
      );
    canvas.drawPath(path, paint);

    for (var i = 0; i < 5; i++) {
      final center = Offset(18 + i * 13, size.height * (0.78 - i * 0.11));
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 20, height: 9),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
