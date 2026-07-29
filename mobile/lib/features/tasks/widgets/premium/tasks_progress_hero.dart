import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../models/task_summary.dart';

/// بطل المهام — تقدّم أفقي هادئ + ملخص صادق للحالة.
///
/// الشريط يلخص التقدم، و`footer` فتحة تضع فيها الشاشة شرائح الفلترة
/// الحية فيصير الهيرو هو لوحة التحكم بدل صناديق أرقام جامدة.
class TasksProgressHero extends StatelessWidget {
  const TasksProgressHero({
    required this.summary,
    this.isLocalPlan = false,
    this.footer,
    super.key,
  });

  final TaskSummary summary;
  final bool isLocalPlan;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isFresh = summary.total == 0;
    final ratio = summary.completionRatio;

    return Container(
      key: const ValueKey('tasks-progress-hero'),
      decoration: BoxDecoration(
        color: AarastDesignTokens.surface,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusXl),
        border: Border.all(color: AarastDesignTokens.border),
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.ink.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقدّم المهام',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AarastDesignTokens.title,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _attentionMessage(summary),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AarastDesignTokens.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${summary.completionPercent}%',
                      key: const ValueKey('tasks-progress-percent'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AarastDesignTokens.title,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ),
                    Text(
                      'مكتملة',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AarastDesignTokens.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'تقدّم المهام',
            value: '${summary.completionPercent} بالمئة',
            child: SizedBox(
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AarastDesignTokens.radiusPill,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AarastDesignTokens.border.withValues(alpha: 0.62),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: isFresh ? 0 : ratio,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: AlignmentDirectional.centerStart,
                              end: AlignmentDirectional.centerEnd,
                              colors: [
                                AarastDesignTokens.burgundy,
                                AarastDesignTokens.gold,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.completed} من ${summary.total} مكتملة',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AarastDesignTokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isLocalPlan) const _LocalPlanBadge(),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

class _LocalPlanBadge extends StatelessWidget {
  const _LocalPlanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AarastDesignTokens.surface,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
        border: Border.all(
          color: AarastDesignTokens.gold.withValues(alpha: 0.58),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.smartphone,
            size: 11,
            color: AarastDesignTokens.goldDeep,
          ),
          const SizedBox(width: 4),
          Text(
            'تخطيط محلي',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastDesignTokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _attentionMessage(TaskSummary summary) {
  if (summary.total == 0) {
    return 'ابدأ بأول مهمة، وسنرتب لك الطريق خطوة خطوة.';
  }

  final attentionCount = summary.overdue + summary.dueToday;
  return switch (attentionCount) {
    0 => 'لا توجد مهمة عاجلة الآن — استمر بهدوء.',
    1 => 'مهمة واحدة تحتاج انتباهك الآن.',
    2 => 'مهمتان تحتاجان انتباهك الآن.',
    >= 3 && <= 10 => '$attentionCount مهام تحتاج انتباهك الآن.',
    _ => '$attentionCount مهمة تحتاج انتباهك الآن.',
  };
}
