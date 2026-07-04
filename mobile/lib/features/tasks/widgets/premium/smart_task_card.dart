import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/offline/offline_status_widgets.dart';
import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/wedding_task.dart';
import '../../utils/task_display.dart';

/// بطاقة المهمة الذكية — سطر نظيف، لا حساء chips.
///
/// الأولوية تُقرأ من العمود اللوني، الحالة من الـ checkbox والشطب،
/// التصنيف كنص خافت، ويبقى chip واحد فقط: الموعد.
class SmartTaskCard extends StatelessWidget {
  const SmartTaskCard({
    required this.task,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    this.onMarkDone,
    this.onReopen,
    super.key,
  });

  final WeddingTask task;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMarkDone;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isDone;
    final isLate = isTaskLate(task);
    final spineColor = isDone
        ? AarastDesignTokens.success
        : isLate
            ? AarastDesignTokens.danger
            : taskPriorityColor(task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(
              color: isLate
                  ? AarastDesignTokens.dangerSoft
                  : AarastDesignTokens.border,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: spineColor),
                ),
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoldBurstCheck(
                        isDone: isDone,
                        isBusy: isBusy,
                        onTap: onMarkDone,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  taskCategoryIcon(task.taskCategory),
                                  size: 13,
                                  color: AarastDesignTokens.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  taskCategoryLabel(task.taskCategory),
                                  style: const TextStyle(
                                    color: AarastDesignTokens.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (task.priority == 'HIGH' ||
                                    task.priority == 'URGENT') ...[
                                  const SizedBox(width: 6),
                                  Icon(LucideIcons.flame,
                                      size: 12,
                                      color: taskPriorityColor(task.priority)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDone
                                    ? AarastDesignTokens.muted
                                    : AarastDesignTokens.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AarastDesignTokens.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MetaRow(task: task, isDone: isDone, isLate: isLate),
                            const SizedBox(height: 8),
                            _ResponsibleLine(task: task, isDone: isDone),
                          ],
                        ),
                      ),
                      _TaskMenu(
                        isDone: isDone,
                        onMarkDone: onMarkDone,
                        onReopen: onReopen,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ],
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.task,
    required this.isDone,
    required this.isLate,
  });

  final WeddingTask task;
  final bool isDone;
  final bool isLate;

  @override
  Widget build(BuildContext context) {
    final dueColor = task.dueDate == null
        ? AarastDesignTokens.muted
        : isLate
            ? AarastDesignTokens.danger
            : AarastDesignTokens.gold;
    final dueLabel = task.dueDate == null
        ? 'بدون موعد'
        : taskRelativeDueLabel(task.dueDate!);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DueChip(label: dueLabel, color: dueColor, isDone: isDone),
        OfflinePendingBadge(entityType: 'task', entityId: task.id),
      ],
    );
  }
}

/// سطر المسؤول — من يتابع المهمة + رقمه للتواصل + شارة المشارك.
/// عنصر تنسيق حقيقي (اتصال هاتفي هو أساس تنسيق الأعراس اليمنية).
class _ResponsibleLine extends StatelessWidget {
  const _ResponsibleLine({required this.task, required this.isDone});

  final WeddingTask task;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final phone = task.responsiblePhoneDisplay;
    final textColor =
        isDone ? AarastDesignTokens.muted : AarastDesignTokens.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AarastDesignTokens.ivory,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
        border: Border.all(color: AarastDesignTokens.gold.withValues(alpha: 0.13)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(LucideIcons.user,
              size: 15,
              color:
                  isDone ? AarastDesignTokens.muted : AarastDesignTokens.burgundy),
          Text(
            'المسؤول: ${task.responsibleLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (phone != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.phone,
                    size: 13, color: AarastDesignTokens.muted),
                const SizedBox(width: 4),
                Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AarastDesignTokens.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          if (task.hasResponsibleParticipant)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AarastDesignTokens.goldSoft,
                borderRadius:
                    BorderRadius.circular(AarastDesignTokens.radiusPill),
                border: Border.all(
                    color: AarastDesignTokens.gold.withValues(alpha: 0.26)),
              ),
              child: const Text(
                'مشارك في الخطة',
                style: TextStyle(
                  color: AarastDesignTokens.burgundy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.label,
    required this.color,
    required this.isDone,
  });

  final String label;
  final Color color;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final effective = isDone ? AarastDesignTokens.muted : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendar, size: 12, color: effective),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: effective,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// checkbox ملكي: عند الإنجاز ينبثق منه توهّج ذهبي قصير.
class _GoldBurstCheck extends StatelessWidget {
  const _GoldBurstCheck({
    required this.isDone,
    required this.isBusy,
    required this.onTap,
  });

  final bool isDone;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);

    Widget box = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDone ? AarastDesignTokens.success : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone
              ? AarastDesignTokens.success
              : AarastDesignTokens.border,
          width: 2,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : null,
    );

    if (isDone && !reduceMotion) {
      box = box
          .animate()
          .scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1, 1),
            duration: 380.ms,
            curve: Curves.elasticOut,
          )
          // توهج ذهبي ينبثق مرة واحدة لحظة الإنجاز.
          .then()
          .shimmer(
            duration: 500.ms,
            color: AarastDesignTokens.goldGlow,
          );
    }

    return Semantics(
      button: true,
      checked: isDone,
      label: isDone ? 'مهمة مكتملة' : 'وضع علامة إنجاز',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AarastDesignTokens.burgundy,
                  ),
                )
              : InkWell(
                  onTap: isDone ? null : onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: box,
                ),
        ),
      ),
    );
  }
}

class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.isDone,
    required this.onMarkDone,
    required this.onReopen,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isDone;
  final VoidCallback? onMarkDone;
  final VoidCallback? onReopen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'إجراءات المهمة',
      icon: const Icon(LucideIcons.moreVertical,
          color: AarastDesignTokens.muted, size: 18),
      onSelected: (value) {
        switch (value) {
          case 'done':
            onMarkDone?.call();
          case 'reopen':
            onReopen?.call();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: isDone ? 'reopen' : 'done',
          enabled: isDone ? onReopen != null : onMarkDone != null,
          child: Row(
            children: [
              Icon(
                isDone
                    ? Icons.restart_alt_rounded
                    : Icons.check_circle_outline_rounded,
                color: isDone
                    ? AarastDesignTokens.burgundy
                    : AarastDesignTokens.success,
              ),
              const SizedBox(width: 10),
              Text(isDone ? 'إعادة فتح المهمة' : 'إنجاز المهمة'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AarastDesignTokens.burgundy),
              SizedBox(width: 10),
              Text('تعديل المهمة'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: AarastDesignTokens.danger),
              SizedBox(width: 10),
              Text('حذف المهمة'),
            ],
          ),
        ),
      ],
    );
  }
}
