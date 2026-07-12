import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/widgets/aarast_progress_ring.dart';
import '../../models/task_summary.dart';

/// بطل المهام — حلقة إنجاز + نبض ذكي.
///
/// بدل شبكة الأصفار الأربعة، نعرض ما يهم فقط: نسبة الإنجاز في حلقة،
/// وثلاث نوافذ حية (متأخرة/اليوم/مكتملة). المستخدم الجديد يرى دعوة، لا أصفارًا.
class TasksProgressHero extends StatelessWidget {
  const TasksProgressHero({
    required this.summary,
    this.isLocalPlan = false,
    super.key,
  });

  final TaskSummary summary;
  final bool isLocalPlan;

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
                      style: const TextStyle(
                        color: AarastDesignTokens.title,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'إنجاز',
                      style: TextStyle(
                        color: AarastDesignTokens.muted,
                        fontSize: 10,
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
                    const Text(
                      'إنجاز المهام',
                      style: TextStyle(
                        color: AarastDesignTokens.title,
                        fontSize: 16.5,
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
                      style: const TextStyle(
                        color: AarastDesignTokens.muted,
                        fontSize: 12.5,
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.smartphone,
                              size: 11,
                              color: AarastDesignTokens.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'تخطيط محلي',
                              style: TextStyle(
                                color: AarastDesignTokens.ink,
                                fontSize: 10.5,
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
          if (!isFresh) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _TaskStat(
                  label: 'متأخرة',
                  value: summary.overdue,
                  icon: LucideIcons.alarmClock,
                  color: summary.overdue > 0
                      ? AarastDesignTokens.danger
                      : AarastDesignTokens.muted,
                  emphasize: summary.overdue > 0,
                ),
                const SizedBox(width: 10),
                _TaskStat(
                  label: 'اليوم',
                  value: summary.dueToday,
                  icon: LucideIcons.calendarDays,
                  color: AarastDesignTokens.burgundy,
                ),
                const SizedBox(width: 10),
                _TaskStat(
                  label: 'مكتملة',
                  value: summary.completed,
                  icon: LucideIcons.checkCheck,
                  color: AarastDesignTokens.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskStat extends StatelessWidget {
  const _TaskStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: emphasize
              ? color.withValues(alpha: 0.08)
              : AarastDesignTokens.ivory,
          borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
          border: Border.all(
            color: emphasize
                ? color.withValues(alpha: 0.25)
                : AarastDesignTokens.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AarastDesignTokens.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                color: emphasize ? color : AarastDesignTokens.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
