import '../models/wedding_task.dart';
import 'task_display.dart';

/// d01's sections, in the order they are shown: the owner's tasks and the
/// plan's tasks a participant reads (D52) group the same way.
enum TaskGroup { overdue, week, month, later, undated, done }

extension TaskGroupLabel on TaskGroup {
  String get label => switch (this) {
    TaskGroup.overdue => 'متأخرة',
    TaskGroup.week => 'هذا الأسبوع',
    TaskGroup.month => 'هذا الشهر',
    TaskGroup.later => 'بعدين',
    TaskGroup.undated => 'بدون موعد',
    TaskGroup.done => 'خلصت',
  };
}

TaskGroup taskGroupOf(WeddingTask task, DateTime today) {
  if (task.isDone || task.status == 'CANCELLED') return TaskGroup.done;
  if (isTaskLate(task, now: today)) return TaskGroup.overdue;
  final due = task.dueDate;
  if (due == null) return TaskGroup.undated;
  final days = taskDateOnly(due).difference(taskDateOnly(today)).inDays;
  if (days < 7) return TaskGroup.week;
  if (days <= 30) return TaskGroup.month;
  return TaskGroup.later;
}

/// Each section's tasks, soonest first; empty sections are left out.
Map<TaskGroup, List<WeddingTask>> groupTasks(
  List<WeddingTask> tasks,
  DateTime today,
) {
  final groups = <TaskGroup, List<WeddingTask>>{};
  for (final task in tasks) {
    groups.putIfAbsent(taskGroupOf(task, today), () => []).add(task);
  }
  for (final list in groups.values) {
    list.sort((a, b) {
      final first = a.dueDate;
      final second = b.dueDate;
      if (first == null || second == null) {
        return a.createdAt.compareTo(b.createdAt);
      }
      return first.compareTo(second);
    });
  }
  return {
    for (final group in TaskGroup.values)
      if (groups[group] != null) group: groups[group]!,
  };
}
