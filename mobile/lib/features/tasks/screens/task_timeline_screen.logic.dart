part of 'task_timeline_screen.dart';

enum _TaskFilter { all, overdue, today, upcoming, completed }

({String title, Color color}) _bucketMeta(AarastTemporalSection bucket) {
  final color = switch (bucket) {
    AarastTemporalSection.now => AppTheme.danger,
    AarastTemporalSection.today || AarastTemporalSection.week => AppTheme.brand,
    AarastTemporalSection.later => AppTheme.textSecondary,
    AarastTemporalSection.completed => AppTheme.success,
  };
  return (title: bucket.label, color: color);
}

AarastTemporalSection _bucketFor(WeddingTask task, DateTime today) {
  return aarastDeadlineSection(
    dueDate: task.status == 'CANCELLED' ? null : task.dueDate,
    completed: task.isDone,
    now: today,
  );
}

List<WeddingTask> _filteredTasks(List<WeddingTask> tasks, _TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => tasks,
    _TaskFilter.overdue => tasks.where(_isLateTask).toList(),
    _TaskFilter.today => tasks.where((task) {
      final dueDate = task.dueDate;
      return dueDate != null && _isSameDay(dueDate, DateTime.now());
    }).toList(),
    _TaskFilter.upcoming => tasks.where((task) {
      if (task.isDone || task.status == 'CANCELLED') return false;
      if (_isLateTask(task)) return false;
      final dueDate = task.dueDate;
      if (dueDate != null && _isSameDay(dueDate, DateTime.now())) return false;
      return true;
    }).toList(),
    _TaskFilter.completed => tasks.where((task) => task.isDone).toList(),
  };
}

WeddingTask? _selectImportantTask(List<WeddingTask> tasks, DateTime today) {
  final candidates = tasks.where((task) {
    if (task.isDone || task.status == 'CANCELLED') return false;
    final bucket = _bucketFor(task, today);
    return bucket == AarastTemporalSection.now ||
        bucket == AarastTemporalSection.today;
  }).toList();
  if (candidates.isEmpty) return null;

  candidates.sort((first, second) {
    final firstBucket = _bucketFor(first, today);
    final secondBucket = _bucketFor(second, today);
    final firstUrgency = firstBucket == AarastTemporalSection.now ? 0 : 1;
    final secondUrgency = secondBucket == AarastTemporalSection.now ? 0 : 1;
    final urgencyComparison = firstUrgency.compareTo(secondUrgency);
    if (urgencyComparison != 0) return urgencyComparison;

    final dateComparison = first.dueDate!.compareTo(second.dueDate!);
    if (dateComparison != 0) return dateComparison;
    return _priorityRank(
      second.priority,
    ).compareTo(_priorityRank(first.priority));
  });
  return candidates.first;
}

int _priorityRank(String priority) {
  return switch (priority) {
    'URGENT' => 4,
    'HIGH' => 3,
    'MEDIUM' => 2,
    'LOW' => 1,
    _ => 0,
  };
}

bool _isLateTask(WeddingTask task) => isTaskLate(task);

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _taskListTitle(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => 'قائمة المهام',
    _TaskFilter.overdue => 'المهام المتأخرة',
    _TaskFilter.today => 'مهام اليوم',
    _TaskFilter.upcoming => 'المهام القادمة',
    _TaskFilter.completed => 'المهام المكتملة',
  };
}

String _emptyTasksMessage(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all =>
      'لا توجد مهام بعد. أضف مهمة عندما يكون لديك إجراء واضح في الخطة.',
    _TaskFilter.overdue => 'لا توجد مهام متأخرة الآن.',
    _TaskFilter.today => 'لا توجد مهام مستحقة اليوم.',
    _TaskFilter.upcoming => 'لا توجد مهام قادمة الآن.',
    _TaskFilter.completed => 'لا توجد مهام مكتملة بعد.',
  };
}

String _taskCountLabel(int count) {
  return switch (count) {
    0 => 'لا مهام',
    1 => 'مهمة واحدة',
    2 => 'مهمتان',
    >= 3 && <= 10 => '$count مهام',
    _ => '$count مهمة',
  };
}

TaskSummary _summaryForPlan(
  TaskSummary summary,
  String weddingPlanId,
  List<WeddingTask> tasks,
) {
  if (summary.weddingPlanId == weddingPlanId) return summary;
  return TaskSummary.fromTasks(weddingPlanId: weddingPlanId, tasks: tasks);
}

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

bool _isLocalGuestPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}
