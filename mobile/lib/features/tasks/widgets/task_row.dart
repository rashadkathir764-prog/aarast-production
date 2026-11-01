import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_task.dart';
import '../utils/task_display.dart';

/// When a task is due, the way people say it: «اليوم», «بكرة», «السبت»,
/// «15 نوفمبر», or «كان موعدها 10 أكتوبر» once it is late.
String taskWhenLabel(WeddingTask task, {DateTime? now}) {
  if (task.status == 'CANCELLED') return 'ملغية';
  if (task.isDone) return 'خلصت';
  final due = task.dueDate;
  if (due == null) return 'بدون موعد';
  final today = taskDateOnly(now ?? DateTime.now());
  final day = taskDateOnly(due);
  final days = day.difference(today).inDays;
  if (days < 0) return 'كان موعدها ${formatArabicDayMonth(due)}';
  if (days == 0) return 'اليوم';
  if (days == 1) return 'بكرة';
  if (days < 7) return formatArabicWeekday(due);
  return formatArabicDayMonth(due);
}

/// d01: one task: the circle that finishes it, the title, when and who,
/// its steps, and the responsible person's letter.
class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.task,
    required this.onToggle,
    required this.onOpen,
    this.showResponsible = true,
    this.selfLetter = 'أ',
    this.selfUserId,
    this.busy = false,
    this.onPostpone,
    super.key,
  });

  final WeddingTask task;

  /// Finishes an open task, or reopens a finished one.
  final VoidCallback? onToggle;
  final VoidCallback? onOpen;

  /// False when the list is already filtered to this person.
  final bool showResponsible;

  /// The letter shown for the plan owner's own tasks.
  final String selfLetter;

  /// The reader's account, to know their own tasks.
  final String? selfUserId;
  final bool busy;

  /// w26: «أجّلها» right on a late task.
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
    final late = isTaskLate(task);
    final done = task.isDone || task.status == 'CANCELLED';
    final responsible = task.responsibleLabel;
    final mine = task.isMineFor(selfUserId);
    final steps = task.checklist.isEmpty
        ? null
        : '${task.checklistDoneCount} من ${task.checklist.length}';
    final meta = [
      taskWhenLabel(task),
      if (showResponsible && !mine) responsible,
      ?steps,
    ].join(' · ');
    final letter = mine
        ? selfLetter
        : (responsible.isEmpty ? '؟' : responsible.characters.first);

    return Semantics(
      button: onOpen != null,
      label: '${task.title}، $meta',
      onTap: onOpen,
      excludeSemantics: true,
      customSemanticsActions: onToggle == null
          ? null
          : {
              CustomSemanticsAction(
                label: done ? context.say('أعد فتحها', 'أعيدي فتحها') : 'خلصت',
              ): onToggle!,
            },
      child: AarastPressable(
        onTap: onOpen ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DoneCircle(
                key: ValueKey('task-toggle-${task.id}'),
                done: done,
                late: late,
                onTap: busy ? null : onToggle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            task.title,
                            style:
                                JourneyType.of(
                                  JourneyType.body,
                                  weight: JourneyType.bold,
                                  color: done
                                      ? AarastV3Color.textMuted
                                      : AarastV3Color.ink,
                                ).copyWith(
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AarastV3Color.textMuted,
                                ),
                          ),
                        ),
                        if (task.isPrivate) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.lock,
                            key: ValueKey('task-private-lock'),
                            size: 14,
                            color: AarastV3Color.textMuted,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      meta,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: late ? JourneyType.bold : FontWeight.w400,
                        color: late
                            ? AarastV3Color.danger
                            : AarastV3Color.textMuted,
                      ),
                    ),
                    if (onPostpone != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: JourneyChip(
                          key: ValueKey('task-postpone-${task.id}'),
                          label: context.say('أجّلها', 'أجّليها'),
                          icon: LucideIcons.calendarClock,
                          selected: false,
                          onTap: busy ? null : onPostpone,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              JourneyAvatar(
                letter: letter,
                color: mine ? context.accent.primary : context.accent.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCircle extends StatelessWidget {
  const _DoneCircle({
    required this.done,
    required this.late,
    required this.onTap,
    super.key,
  });

  final bool done;
  final bool late;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AarastV3Color.mint : null,
        border: done
            ? null
            : Border.all(
                color: late ? AarastV3Color.danger : AarastV3Color.lineStrong,
                width: 2,
              ),
      ),
      child: done
          ? const Icon(
              LucideIcons.check,
              size: 16,
              color: AarastV3Color.onPrimary,
            )
          : null,
    );
    if (onTap == null) return circle;
    // A wider target than the circle itself; screen readers get the same
    // action from the row.
    // The 26 circle sits in a 48 target (DESIGN_SYSTEM: touch ≥ 48).
    return AarastPressable(
      onTap: onTap!,
      child: SizedBox.square(
        dimension: AarastV3Space.x12,
        child: Align(alignment: Alignment.topCenter, child: circle),
      ),
    );
  }
}
