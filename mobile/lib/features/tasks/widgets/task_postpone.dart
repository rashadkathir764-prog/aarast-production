import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_task.dart';

/// Asks for a day from today on; null when the person backs out.
Future<DateTime?> pickTaskDate(BuildContext context, {DateTime? initial}) {
  releaseFieldFocus();
  final today = DateUtils.dateOnly(DateTime.now());
  final start = initial != null && !initial.isBefore(today) ? initial : today;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: today,
    lastDate: today.add(const Duration(days: 3650)),
    locale: const Locale('ar'),
  );
}

/// «أجّلها»: the new day, or null when the person backs out.
Future<DateTime?> showTaskPostponeSheet(
  BuildContext context,
  WeddingTask task,
) {
  return showJourneySheet<DateTime>(
    context: context,
    builder: (_) => TaskPostponeSheet(task: task),
  );
}

/// «أجّلها»: a few common delays, or a day of one's choosing.
class TaskPostponeSheet extends StatelessWidget {
  const TaskPostponeSheet({required this.task, super.key});

  final WeddingTask task;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final from = task.dueDate != null && !task.dueDate!.isBefore(today)
        ? DateUtils.dateOnly(task.dueDate!)
        : today;
    final options = [
      ('بكرة', today.add(const Duration(days: 1))),
      ('بعد ثلاثة أيام', from.add(const Duration(days: 3))),
      ('بعد أسبوع', from.add(const Duration(days: 7))),
    ];
    return JourneySheetBody(
      title: context.say('لمتى تأجلها؟', 'لمتى تأجلينها؟'),
      children: [
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final (label, date) in options)
                JourneyListRow(
                  key: ValueKey('task-postpone-$label'),
                  icon: LucideIcons.calendarClock,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: label,
                  subtitle: formatArabicWeekdayDayMonth(date),
                  onTap: () => Navigator.pop(context, date),
                ),
              JourneyListRow(
                key: const ValueKey('task-postpone-pick'),
                icon: LucideIcons.calendarDays,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('اختر يوم', 'اختاري يوم'),
                subtitle: 'من التقويم',
                onTap: () async {
                  final date = await pickTaskDate(
                    context,
                    initial: task.dueDate,
                  );
                  if (date != null && context.mounted) {
                    Navigator.pop(context, date);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
