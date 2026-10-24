part of 'task_timeline_screen.dart';

/// d01's sections, in the order they are shown.
enum _TaskGroup { overdue, week, month, later, undated, done }

extension on _TaskGroup {
  String get label => switch (this) {
    _TaskGroup.overdue => 'متأخرة',
    _TaskGroup.week => 'هذا الأسبوع',
    _TaskGroup.month => 'هذا الشهر',
    _TaskGroup.later => 'بعدين',
    _TaskGroup.undated => 'بدون موعد',
    _TaskGroup.done => 'خلصت',
  };
}

_TaskGroup _groupOf(WeddingTask task, DateTime today) {
  if (task.isDone || task.status == 'CANCELLED') return _TaskGroup.done;
  if (isTaskLate(task, now: today)) return _TaskGroup.overdue;
  final due = task.dueDate;
  if (due == null) return _TaskGroup.undated;
  final days = taskDateOnly(due).difference(taskDateOnly(today)).inDays;
  if (days < 7) return _TaskGroup.week;
  if (days <= 30) return _TaskGroup.month;
  return _TaskGroup.later;
}

/// Each section's tasks, soonest first; empty sections are left out.
Map<_TaskGroup, List<WeddingTask>> _grouped(
  List<WeddingTask> tasks,
  DateTime today,
) {
  final groups = <_TaskGroup, List<WeddingTask>>{};
  for (final task in tasks) {
    groups.putIfAbsent(_groupOf(task, today), () => []).add(task);
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
    for (final group in _TaskGroup.values)
      if (groups[group] != null) group: groups[group]!,
  };
}

/// The person filter: everyone, the owner's own tasks («لي»), or one
/// responsible person by name.
const _everyone = '';
const _mine = 'me';

bool _isMine(WeddingTask task, String? userId) {
  if (task.assigneeUserId != null && task.assigneeUserId == userId) {
    return true;
  }
  return task.responsibleLabel == 'أنا';
}

String _personKey(WeddingTask task, String? userId) =>
    _isMine(task, userId) ? _mine : task.responsibleLabel;

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

/// «باقي 3 هذا الأسبوع، وواحدة متأخرة» (d01), from the real counts (C6).
String _statusLine(
  List<WeddingTask> tasks,
  DateTime today,
  JourneyProfile profile,
) {
  if (tasks.isEmpty) return profile.say('ابدأ بأول مهمة', 'ابدئي بأول مهمة');
  final open = tasks
      .where((task) => _groupOf(task, today) != _TaskGroup.done)
      .toList();
  if (open.isEmpty) return 'خلصت كل المهام';
  final overdue = open
      .where((task) => _groupOf(task, today) == _TaskGroup.overdue)
      .length;
  final week = open
      .where((task) => _groupOf(task, today) == _TaskGroup.week)
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
  final thisWeek = 'باقي $week هذا الأسبوع';
  return late == null ? thisWeek : '$thisWeek، و$late';
}

String _taskCountLabel(int count) => arabicCount(
  count,
  one: 'مهمة وحدة',
  two: 'مهمتين',
  few: 'مهام',
  many: 'مهمة',
);

List<SharedMember> _membersForPlan(
  List<SharedMember> members,
  String weddingPlanId,
) {
  return members
      .where((member) => member.weddingPlanId == weddingPlanId)
      .toList(growable: false);
}

WeddingTask _hydrateTaskParticipant(
  WeddingTask task,
  List<SharedMember> members,
) {
  if (!task.hasResponsibleParticipant) return task;
  for (final member in members) {
    if (member.userId != task.assigneeUserId) continue;
    return task.copyWith(
      assigneeName: member.displayName,
      assigneePhone: member.user?.phone,
      assigneeRole: member.role,
    );
  }
  return task;
}
