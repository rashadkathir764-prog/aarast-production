import '../models/wedding_task.dart';
import 'task_display.dart';

/// d01's sections, in the order they are shown: the owner's tasks and the
/// plan's tasks a participant reads (D52) group the same way.
enum TaskGroup { overdue, week, month, later, undated, done, cancelled }

extension TaskGroupLabel on TaskGroup {
  String get label => switch (this) {
    TaskGroup.overdue => 'متأخرة',
    // Rolling windows, not calendar ones, and the labels say so: a task due
    // next Thursday is «خلال أسبوع» whatever day of the week it is read on.
    TaskGroup.week => 'خلال أسبوع',
    TaskGroup.month => 'خلال شهر',
    TaskGroup.later => 'بعدين',
    TaskGroup.undated => 'بدون موعد',
    TaskGroup.done => 'خلصت',
    TaskGroup.cancelled => 'ملغية',
  };
}

/// The groups that are still work. One definition, because the sections, the
/// «X من Y» count and the header's line all have to agree: a cancelled task
/// used to sit under «خلصت» while the count left it out, so the two numbers
/// contradicted each other on the same screen.
bool isOpenTaskGroup(TaskGroup group) =>
    group != TaskGroup.done && group != TaskGroup.cancelled;

TaskGroup taskGroupOf(WeddingTask task, DateTime today) {
  // Cancelled is its own group: it is not finished work.
  if (task.status == 'CANCELLED') return TaskGroup.cancelled;
  if (task.isDone) return TaskGroup.done;
  if (isTaskLate(task, now: today)) return TaskGroup.overdue;
  final due = task.dueDate;
  if (due == null) return TaskGroup.undated;
  final days = taskDateOnly(due).difference(taskDateOnly(today)).inDays;
  // Both bounds inclusive: a day exactly a week out belongs to the week,
  // the way its label reads. The two used to disagree (< 7 against <= 30).
  if (days <= 7) return TaskGroup.week;
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
