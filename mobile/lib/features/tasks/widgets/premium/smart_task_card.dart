import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/offline/offline_status_widgets.dart';
import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/wedding_task.dart';
import '../../utils/task_display.dart';

/// بطاقة المهمة الذكية — صف نحيف: عنوان + سطر ميتا واحد.
///
/// الأولوية تُقرأ من العمود اللوني وشعلة صغيرة، الحالة من الـ checkbox
/// والشطب، والتصنيف والموعد والمسؤول كلها في سطر ميتا واحد.
class SmartTaskCard extends StatelessWidget {
  const SmartTaskCard({
    required this.task,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    this.onMarkDone,
    this.onReopen,
    this.now,
    super.key,
  });

  final WeddingTask task;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMarkDone;
  final VoidCallback? onReopen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isDone;
    final isLate = isTaskLate(task, now: now);
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
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: isDone
                                              ? AarastDesignTokens.muted
                                              : AarastDesignTokens.ink,
                                          fontWeight: FontWeight.w800,
                                          height: 1.3,
                                          decoration: isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor:
                                              AarastDesignTokens.muted,
                                        ),
                                  ),
                                ),
                                if (task.priority == 'HIGH' ||
                                    task.priority == 'URGENT') ...[
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      LucideIcons.flame,
                                      size: 14,
                                      color: taskPriorityColor(task.priority),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            _MetaRow(
                              task: task,
                              isDone: isDone,
                              isLate: isLate,
                              now: now,
                            ),
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
    required this.now,
  });

  final WeddingTask task;
  final bool isDone;
  final bool isLate;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final dueColor = task.dueDate == null
        ? AarastDesignTokens.muted
        : isLate
        ? AarastDesignTokens.danger
        : AarastDesignTokens.gold;
    final dueLabel = task.dueDate == null
        ? 'بدون موعد'
        : taskRelativeDueLabel(task.dueDate!, now: now);
    final phone = task.responsiblePhoneDisplay;
    final metaStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AarastDesignTokens.muted,
      fontWeight: FontWeight.w700,
    );

    // سطر ميتا واحد: التصنيف · الموعد · المسؤول (ورقمه للتنسيق الهاتفي).
    return Wrap(
      spacing: 8,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              taskCategoryIcon(task.taskCategory),
              size: 12,
              color: AarastDesignTokens.muted,
            ),
            const SizedBox(width: 4),
            Text(taskCategoryLabel(task.taskCategory), style: metaStyle),
          ],
        ),
        _DueChip(label: dueLabel, color: dueColor, isDone: isDone),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.user,
              size: 12,
              color: isDone
                  ? AarastDesignTokens.muted
                  : AarastDesignTokens.burgundy,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'المسؤول: ${task.directionalResponsibleLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle?.copyWith(
                  color: isDone
                      ? AarastDesignTokens.muted
                      : AarastDesignTokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (phone != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.phone,
                size: 12,
                color: AarastDesignTokens.muted,
              ),
              const SizedBox(width: 4),
              AarastPhoneText(phone: phone, style: metaStyle),
            ],
          ),
        if (task.hasResponsibleParticipant)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AarastDesignTokens.goldSoft,
              borderRadius: BorderRadius.circular(
                AarastDesignTokens.radiusPill,
              ),
              border: Border.all(
                color: AarastDesignTokens.gold.withValues(alpha: 0.26),
              ),
            ),
            child: Text(
              'مشارك في الخطة',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AarastDesignTokens.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        OfflinePendingBadge(entityType: 'task', entityId: task.id),
      ],
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: effective,
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
          ? const Icon(LucideIcons.check, color: Colors.white, size: 17)
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
          .shimmer(duration: 500.ms, color: AarastDesignTokens.goldGlow);
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
              ? const AarastInlineSpinner(
                  dimension: 20,
                  color: AarastDesignTokens.burgundy,
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
      icon: const Icon(
        LucideIcons.moreVertical,
        color: AarastDesignTokens.muted,
        size: 18,
      ),
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
                isDone ? LucideIcons.rotateCcw : LucideIcons.checkCircle2,
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
              Icon(LucideIcons.fileEdit, color: AarastDesignTokens.burgundy),
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
              Icon(LucideIcons.trash2, color: AarastDesignTokens.danger),
              SizedBox(width: 10),
              Text('حذف المهمة'),
            ],
          ),
        ),
      ],
    );
  }
}
