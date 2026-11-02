part of 'task_timeline_screen.dart';

/// w24 «على الوقت»: every task by its month, finished ones ticked, the
/// current month marked «الآن», and undated ones at the end.
class _MonthsTimeline extends StatelessWidget {
  const _MonthsTimeline({required this.tasks, required this.onOpen});

  final List<WeddingTask> tasks;
  final ValueChanged<WeddingTask> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = appNow();
    final months = <DateTime, List<WeddingTask>>{};
    final undated = <WeddingTask>[];
    for (final task in tasks) {
      if (task.status == 'CANCELLED') continue;
      final due = task.dueDate;
      if (due == null) {
        undated.add(task);
        continue;
      }
      months.putIfAbsent(DateTime(due.year, due.month), () => []).add(task);
    }
    final keys = months.keys.toList()..sort();
    for (final list in months.values) {
      list.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final month in keys)
          _MonthBlock(
            key: ValueKey('task-month-${month.year}-${month.month}'),
            title: month.year == now.year && month.month == now.month
                ? '${arabicMonthName(month.month)} · الآن'
                : month.year == now.year
                ? arabicMonthName(month.month)
                : '${arabicMonthName(month.month)} ${month.year}',
            now: month.year == now.year && month.month == now.month,
            tasks: months[month]!,
            onOpen: onOpen,
          ),
        if (undated.isNotEmpty)
          _MonthBlock(
            key: const ValueKey('task-month-undated'),
            title: 'بدون موعد',
            now: false,
            tasks: undated,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _MonthBlock extends StatelessWidget {
  const _MonthBlock({
    required this.title,
    required this.now,
    required this.tasks,
    required this.onOpen,
    super.key,
  });

  final String title;
  final bool now;
  final List<WeddingTask> tasks;
  final ValueChanged<WeddingTask> onOpen;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: AarastV3Space.x1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: now ? context.accent.primary : null,
                  border: Border.all(color: context.accent.primary, width: 2),
                ),
              ),
              const Expanded(
                child: VerticalDivider(
                  width: 14,
                  thickness: 2,
                  color: AarastV3Color.line,
                ),
              ),
            ],
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AarastV3Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: now
                          ? context.accent.primary
                          : AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x1),
                  for (final task in tasks)
                    Semantics(
                      button: true,
                      label: task.title,
                      onTap: () => onOpen(task),
                      excludeSemantics: true,
                      child: AarastPressable(
                        key: ValueKey('task-month-row-${task.id}'),
                        onTap: () => onOpen(task),
                        // A 48 target per task (DESIGN_SYSTEM).
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AarastV3Space.x12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                task.isDone
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.circle,
                                size: 17,
                                color: task.isDone
                                    ? AarastV3Color.mint
                                    : isTaskLate(task)
                                    ? AarastV3Color.danger
                                    : AarastV3Color.textFaint,
                              ),
                              const SizedBox(width: AarastV3Space.x2),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: JourneyType.of(
                                    JourneyType.body,
                                    color: task.isDone
                                        ? AarastV3Color.textFaint
                                        : AarastV3Color.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
