import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/plan_day.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/name_letter.dart';
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
  // D11, RA-MO-25: whole days from today in Sana'a.
  final days = daysUntilPlanDay(due, now: now);
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
    // A cancelled task is not a finished one. It still reads as inactive
    // (muted, struck through), but it must not wear the green tick.
    final done = task.isDone;
    final cancelled = task.status == 'CANCELLED';
    final inactive = done || cancelled;
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
    final letter = mine ? selfLetter : nameLetter(responsible);

    return Semantics(
      button: onOpen != null,
      label: '${task.title}، $meta',
      onTap: onOpen,
      excludeSemantics: true,
      customSemanticsActions: onToggle == null
          ? null
          : {
              CustomSemanticsAction(
                label: inactive
                    ? context.say('أعد فتحها', 'أعيدي فتحها')
                    : 'خلصت',
              ): onToggle!,
            },
      child: AarastPressable(
        onTap: onOpen ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DoneCircle(
                key: ValueKey('task-toggle-${task.id}'),
                done: done,
                cancelled: cancelled,
                late: late,
                onTap: busy ? null : onToggle,
              ),
              const SizedBox(width: AarastV3Space.x3),
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
                                  color: inactive
                                      ? AarastV3Color.textMuted
                                      : AarastV3Color.ink,
                                ).copyWith(
                                  decoration: inactive
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AarastV3Color.textMuted,
                                ),
                          ),
                        ),
                        if (task.isPrivate) ...[
                          const SizedBox(width: AarastV3Space.x1),
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
                        padding: const EdgeInsets.only(top: AarastV3Space.x1),
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
              const SizedBox(width: AarastV3Space.x2),
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
    required this.cancelled,
    required this.late,
    required this.onTap,
    super.key,
  });

  final bool done;

  /// Cancelled, not finished: a grey circle with a cross, never the green
  /// tick, so a cancelled task never reads as work completed.
  final bool cancelled;
  final bool late;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = done || cancelled;
    final circle = Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(top: AarastV3Space.half),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AarastV3Color.mint
            : cancelled
            ? AarastV3Color.line
            : null,
        border: filled
            ? null
            : Border.all(
                color: late ? AarastV3Color.danger : AarastV3Color.lineStrong,
                width: 2,
              ),
      ),
      child: filled
          ? Icon(
              done ? LucideIcons.check : LucideIcons.x,
              size: 16,
              color: done ? AarastV3Color.onPrimary : AarastV3Color.textMuted,
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
