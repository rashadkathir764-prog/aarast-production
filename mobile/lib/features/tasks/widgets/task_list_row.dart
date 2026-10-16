import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_task.dart';
import '../utils/task_display.dart';

/// بطاقة المهمة الذكية — صف نحيف: عنوان + سطر ميتا واحد.
///
/// الأولوية تُقرأ من العمود اللوني وشعلة صغيرة، الحالة من الـ checkbox
/// والشطب، والتصنيف والموعد والمسؤول كلها في سطر ميتا واحد.
class TaskListRow extends StatelessWidget {
  const TaskListRow({
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
        ? AppTheme.success
        : isLate
        ? AppTheme.danger
        : taskPriorityColor(task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isLate ? AppTheme.danger : AppTheme.border,
              ),
            ),
          ),
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
                    _CompletionBurst(
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
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: isDone
                                            ? AppTheme.textSecondary
                                            : AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        height: 1.3,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: AppTheme.textSecondary,
                                      ),
                                ),
                              ),
                              // V1 checklist 4.10: seen by this account alone.
                              if (task.isPrivate) ...[
                                const SizedBox(width: 6),
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(
                                    LucideIcons.lock,
                                    key: ValueKey('task-private-lock'),
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                    semanticLabel: 'مهمة خاصة',
                                  ),
                                ),
                              ],
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
                          if (isLate && !isDone) ...[
                            const SizedBox(height: 2),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: isBusy ? null : onEdit,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  LucideIcons.calendarClock,
                                  size: 15,
                                ),
                                label: const Text('إعادة الجدولة'),
                              ),
                            ),
                          ],
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
        ? AppTheme.textSecondary
        : isLate
        ? AppTheme.danger
        : AppTheme.focus;
    final dueLabel = task.dueDate == null
        ? 'بدون موعد'
        : taskRelativeDueLabel(task.dueDate!, now: now);
    final phone = task.responsiblePhoneDisplay;
    final metaStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppTheme.textSecondary,
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
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(taskCategoryLabel(task.taskCategory), style: metaStyle),
          ],
        ),
        _DueChip(label: dueLabel, color: dueColor, isDone: isDone),
        if (task.checklist.isNotEmpty)
          Row(
            key: const ValueKey('task-row-checklist-progress'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.listChecks,
                size: 12,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${task.checklistDoneCount}/${task.checklist.length}',
                style: metaStyle,
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.user,
              size: 12,
              color: isDone ? AppTheme.textSecondary : AppTheme.brand,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'المسؤول: ${task.directionalResponsibleLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle?.copyWith(
                  color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
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
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              AarastPhoneText(phone: phone, style: metaStyle),
            ],
          ),
        if (task.hasResponsibleParticipant)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.focus.withValues(alpha: 0.26)),
            ),
            child: Text(
              'مشارك في الخطة',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.brand,
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
    final effective = isDone ? AppTheme.textSecondary : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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

/// مؤشر إنجاز حي: عند الإنجاز ينبثق منه توهّج قصير.
class _CompletionBurst extends StatelessWidget {
  const _CompletionBurst({
    required this.isDone,
    required this.isBusy,
    required this.onTap,
  });

  final bool isDone;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDone ? AppTheme.success : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppTheme.success : AppTheme.border,
          width: 2,
        ),
      ),
      child: isDone
          ? const Icon(LucideIcons.check, color: Colors.white, size: 17)
          : null,
    );

    return Semantics(
      button: true,
      checked: isDone,
      label: isDone ? 'مهمة مكتملة' : 'وضع علامة إنجاز',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: isBusy
              ? const AarastInlineSpinner(dimension: 20, color: AppTheme.brand)
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
        color: AppTheme.textSecondary,
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
                color: isDone ? AppTheme.brand : AppTheme.success,
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
              Icon(LucideIcons.fileEdit, color: AppTheme.brand),
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
              Icon(LucideIcons.trash2, color: AppTheme.danger),
              SizedBox(width: 10),
              Text('حذف المهمة'),
            ],
          ),
        ),
      ],
    );
  }
}
