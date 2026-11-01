import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../finance/finance_api.dart' show FinanceProvider;
import '../models/wedding_task.dart';

/// What the person picked: an item, a payment, or no link at all.
typedef TaskLinkChoice = ({String? budgetCategoryId, String? scheduleId});

/// R4: what a task waits on. An item ends the task when it is booked, a
/// payment when it is recorded. The mahr's item is left out: it is never
/// booked, so nothing could end the task.
Future<TaskLinkChoice?> showTaskLinkSheet(
  BuildContext context, {
  required FinanceProvider finance,
  required WeddingTask task,
}) {
  return showJourneySheet<TaskLinkChoice>(
    context: context,
    builder: (_) => _TaskLinkSheet(finance: finance, task: task),
  );
}

class _TaskLinkSheet extends StatelessWidget {
  const _TaskLinkSheet({required this.finance, required this.task});

  final FinanceProvider finance;
  final WeddingTask task;

  @override
  Widget build(BuildContext context) {
    final items = finance.summary.categories.where((item) => !item.isMahr);
    final payments = finance.dueSchedules.where((item) => item.isPending);
    final linked =
        task.linkedBudgetCategoryId != null || task.linkedScheduleId != null;
    void choose(TaskLinkChoice choice) => Navigator.of(context).pop(choice);
    return JourneySheetBody(
      title: 'وين تنتهي المهمة؟',
      subtitle: 'تنتهي لحالها لما ينحجز البند أو تنسجّل الدفعة',
      children: [
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              if (linked)
                JourneyListRow(
                  key: const ValueKey('task-link-none'),
                  icon: LucideIcons.unlink,
                  color: AarastV3Color.textMuted,
                  soft: AarastV3Color.line,
                  title: 'بدون ربط',
                  subtitle: 'تبقى المهمة لحالها',
                  onTap: () =>
                      choose((budgetCategoryId: null, scheduleId: null)),
                ),
              for (final item in items)
                JourneyListRow(
                  key: ValueKey('task-link-item-${item.categoryId}'),
                  icon: LucideIcons.tags,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: item.name,
                  subtitle: 'بند',
                  onTap: () => choose((
                    budgetCategoryId: item.categoryId,
                    scheduleId: null,
                  )),
                ),
              for (final payment in payments)
                JourneyListRow(
                  key: ValueKey('task-link-schedule-${payment.id}'),
                  icon: LucideIcons.calendarClock,
                  color: AarastV3Color.cobalt,
                  soft: AarastV3Color.cobaltSoft,
                  title: [
                    payment.note?.trim().isNotEmpty == true
                        ? payment.note!.trim()
                        : payment.costTitle ?? 'دفعة',
                    formatArabicDayMonth(payment.dueDate),
                  ].join(' · '),
                  subtitle: 'دفعة',
                  onTap: () =>
                      choose((budgetCategoryId: null, scheduleId: payment.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
