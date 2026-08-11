import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/task_summary.dart';

/// A compact command header for the tasks tab. It exposes the real attention
/// signal and counts without pushing the task list below a decorative hero.
class TasksProgressBrief extends StatelessWidget {
  const TasksProgressBrief({
    required this.summary,
    this.isLocalPlan = false,
    this.footer,
    this.heroTag,
    super.key,
  });

  final TaskSummary summary;
  final bool isLocalPlan;
  final Widget? footer;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final isFresh = summary.total == 0;
    final attentionCount = summary.overdue + summary.dueToday;
    final remaining = (summary.total - summary.completed).clamp(
      0,
      summary.total,
    );
    final title = isFresh
        ? 'ابدأ أول مهمة'
        : attentionCount > 0
        ? _attentionTitle(attentionCount)
        : 'الخطة تسير بهدوء';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('tasks-progress-brief'),
          padding: const EdgeInsets.all(AarastV3Space.x4),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (heroTag == null)
                    const Icon(
                      LucideIcons.listChecks,
                      size: 19,
                      color: AarastV3Color.primary,
                    )
                  else
                    AarastV3HeroIcon(
                      heroTag: heroTag,
                      icon: LucideIcons.listChecks,
                      size: 19,
                      color: AarastV3Color.primary,
                    ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      'تقدّم المهام',
                      style: AarastV3Type.label(
                        context,
                      ).copyWith(color: AarastV3Color.primary),
                    ),
                  ),
                  if (isLocalPlan) const _LocalPlanBadge(),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AarastV3Type.section(
                            context,
                          ).copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AarastV3Space.x1),
                        Text(
                          _attentionMessage(summary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AarastV3Color.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Text(
                    isFresh ? '—' : '${summary.completionPercent}%',
                    style: AarastV3Type.display(context).copyWith(
                      color: attentionCount > 0
                          ? AarastV3Color.rose
                          : AarastV3Color.primary,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              Row(
                children: [
                  _TaskMetric(label: 'متبقية', value: '$remaining'),
                  _TaskMetric(label: 'مكتملة', value: '${summary.completed}'),
                  _TaskMetric(
                    label: summary.overdue > 0 ? 'متأخرة' : 'اليوم',
                    value: summary.overdue > 0
                        ? '${summary.overdue}'
                        : '${summary.dueToday}',
                    accent: attentionCount > 0
                        ? AarastV3Color.rose
                        : AarastV3Color.mint,
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              AarastV3PlanPath(
                value: summary.total == 0
                    ? 0
                    : summary.completed / summary.total,
                semanticsLabel: 'مسار إنجاز المهام',
                color: attentionCount > 0
                    ? AarastV3Color.rose
                    : AarastV3Color.primary,
              ),
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          footer!,
        ],
      ],
    );
  }
}

class _TaskMetric extends StatelessWidget {
  const _TaskMetric({
    required this.label,
    required this.value,
    this.accent = AarastV3Color.primary,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AarastV3Color.textMuted),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AarastV3Color.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.smartphone,
            size: 12,
            color: AarastV3Color.primary,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Text(
            'تخطيط محلي',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastV3Color.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _attentionTitle(int count) {
  return switch (count) {
    1 => 'مهمة واحدة تحتاج قرارك',
    2 => 'مهمتان تحتاجان قرارك',
    >= 3 && <= 10 => '$count مهام تحتاج قرارك',
    _ => '$count مهمة تحتاج قرارك',
  };
}

String _attentionMessage(TaskSummary summary) {
  if (summary.total == 0) return 'أضف عنوانًا وموعدًا ومسؤولًا فقط.';
  final attentionCount = summary.overdue + summary.dueToday;
  return switch (attentionCount) {
    0 => 'لا توجد مهمة عاجلة الآن.',
    1 => 'مهمة واحدة تحتاج انتباهك الآن.',
    2 => 'مهمتان تحتاجان انتباهك الآن.',
    >= 3 && <= 10 => '$attentionCount مهام تحتاج انتباهك الآن.',
    _ => '$attentionCount مهمة تحتاج انتباهك الآن.',
  };
}
