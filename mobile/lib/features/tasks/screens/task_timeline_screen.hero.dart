part of 'task_timeline_screen.dart';

// Rashad 2026-11-17: the tasks tab's hero, the home's own look and size
// (TaskProgressHero, shared with a participant's tasks). The list under it
// names each task, so the hero names none. It follows the person chosen
// under it.

class _TasksHero extends StatelessWidget {
  const _TasksHero({required this.tasks, required this.today});

  /// What the screen shows («الكل», «لي» or one person).
  final List<WeddingTask> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final counted = [
      for (final task in tasks)
        if (task.status != 'CANCELLED') task,
    ];
    return TaskProgressHero(
      open: counted
          .where((task) => isOpenTaskGroup(taskGroupOf(task, today)))
          .length,
      done: counted.where((task) => task.isDone).length,
      total: counted.length,
      late: counted
          .where((task) => taskGroupOf(task, today) == TaskGroup.overdue)
          .length,
    );
  }
}
