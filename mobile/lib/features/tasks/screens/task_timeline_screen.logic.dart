part of 'task_timeline_screen.dart';

/// The person filter: everyone, the owner's own tasks («لي»), or one
/// responsible person by name.
const _everyone = '';
const _mine = 'me';

String _personKey(WeddingTask task, String? userId) =>
    task.isMineFor(userId) ? _mine : task.responsibleLabel;

/// Everyone besides the owner who has a task, most tasks first.
List<String> _people(List<WeddingTask> tasks, String? userId) {
  final counts = <String, int>{};
  for (final task in tasks) {
    final key = _personKey(task, userId);
    if (key == _mine) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
}

/// «باقي 3 خلال أسبوع، وواحدة متأخرة» (d01), from the real counts (C6).
///
/// It is given the tasks the person filter is showing, not all of them: the
/// «X من Y» beside the filter counts the same set, and the two lines used to
/// describe different sets with nothing saying so.
String _statusLine(
  List<WeddingTask> tasks,
  DateTime today,
  JourneyProfile profile, {
  bool filtered = false,
}) {
  if (tasks.isEmpty) {
    return filtered
        ? 'ما فيه مهام لهذا الاختيار'
        : profile.say('ابدأ بأول مهمة', 'ابدئي بأول مهمة');
  }
  final open = tasks
      .where((task) => isOpenTaskGroup(taskGroupOf(task, today)))
      .toList();
  // RA-MO-185: «خلصت كل المهام» was said of a plan whose tasks were all
  // cancelled («ما نحتاجها») and none done.
  if (open.isEmpty) {
    return tasks.any((task) => task.isDone)
        ? 'خلصت كل المهام'
        : 'ما فيه مهام مفتوحة';
  }
  final overdue = open
      .where((task) => taskGroupOf(task, today) == TaskGroup.overdue)
      .length;
  final week = open
      .where((task) => taskGroupOf(task, today) == TaskGroup.week)
      .length;
  final late = overdue == 0
      ? null
      : arabicCount(
          overdue,
          one: 'واحدة متأخرة',
          two: 'ثنتين متأخرة',
          few: 'متأخرة',
          many: 'متأخرة',
        );
  if (week == 0) {
    final left = 'باقي ${_taskCountLabel(open.length)}';
    return late == null ? left : '$left، منها $late';
  }
  final thisWeek = 'باقي ${_taskCountLabel(week)} خلال أسبوع';
  return late == null ? thisWeek : '$thisWeek، و$late';
}

String _taskCountLabel(int count) => arabicCount(
  count,
  one: 'مهمة وحدة',
  two: 'مهمتين',
  few: 'مهام',
  many: 'مهمة',
);
