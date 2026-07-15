import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/widgets/aarast_progress_ring.dart';
import '../../models/task_summary.dart';

/// بطل المهام — حلقة إنجاز + نبض ذكي.
///
/// الحلقة تلخص التقدم، و`footer` فتحة تضع فيها الشاشة شرائح الفلترة
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
    final ringColors = summary.overdue > 0 && !isFresh
        ? const [
            AarastDesignTokens.warning,
            AarastDesignTokens.warningLight,
            AarastDesignTokens.warningSoft,
          ]
        : const [
            AarastDesignTokens.goldDeep,
            AarastDesignTokens.gold,
            AarastDesignTokens.goldLight,
          ];

    return Container(
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
            children: [
              AarastProgressRing(
                progress: isFresh ? 0 : ratio,
                size: 76,
                strokeWidth: 7,
                trackColor: AarastDesignTokens.border.withValues(alpha: 0.7),
                gradientColors: ringColors,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.completionPercent}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AarastDesignTokens.title,
                        fontSize: 19,
                        height: 1,
                      ),
                    ),
                    Text(
                      'إنجاز',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AarastDesignTokens.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إنجاز المهام',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AarastDesignTokens.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFresh
                          ? 'ابدأ بأول مهمة، وسنرتب لك الطريق خطوة خطوة.'
                          : summary.overdue > 0
                          ? 'لديك ${summary.overdue} مهمة متأخرة — عالجها أولًا.'
                          : summary.dueToday > 0
                          ? 'اليوم عندك ${summary.dueToday} مهمة — بالتوفيق.'
                          : 'أنجزت ${summary.completed} من ${summary.total} — استمر.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AarastDesignTokens.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    if (isLocalPlan) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AarastDesignTokens.goldSoft,
                          borderRadius: BorderRadius.circular(
                            AarastDesignTokens.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.smartphone,
                              size: 11,
                              color: AarastDesignTokens.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'تخطيط محلي',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AarastDesignTokens.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}
