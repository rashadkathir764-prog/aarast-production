import 'wedding_task.dart';

class TaskSummary {
  const TaskSummary({
    required this.weddingPlanId,
    required this.total,
    required this.completed,
    required this.pendingInProgress,
    required this.overdue,
    required this.dueToday,
    required this.highPriority,
    this.assignedToMe = 0,
    this.assigneeSummary = const TaskAssigneeSummary(),
    this.byStatus = const {},
    this.byPriority = const {},
  });

  factory TaskSummary.empty(String weddingPlanId) {
    return TaskSummary(
      weddingPlanId: weddingPlanId,
      total: 0,
      completed: 0,
      pendingInProgress: 0,
      overdue: 0,
      dueToday: 0,
      highPriority: 0,
    );
  }

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      total: _intOrZero(json['total'] ?? json['totalTasks']),
      completed: _intOrZero(json['completed'] ?? json['completedTasks']),
      pendingInProgress: _intOrZero(
        json['pendingInProgress'] ?? json['openTasks'],
      ),
      overdue: _intOrZero(json['overdue'] ?? json['overdueTasks']),
      dueToday: _intOrZero(json['dueToday'] ?? json['todayTasks']),
      highPriority: _intOrZero(json['highPriority']),
      assignedToMe: _intOrZero(json['assignedToMe']),
      assigneeSummary: TaskAssigneeSummary.fromJson(
        _mapOrEmpty(json['assigneeSummary']),
      ),
      byStatus: _intMap(json['byStatus']),
      byPriority: _intMap(json['byPriority']),
    );
  }

  factory TaskSummary.fromTasks({
    required String weddingPlanId,
    required List<WeddingTask> tasks,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    var completed = 0;
    var pendingInProgress = 0;
    var overdue = 0;
    var dueToday = 0;
    var highPriority = 0;
    var assignedCount = 0;
    final byStatus = <String, int>{};
    final byPriority = <String, int>{};

    for (final task in tasks) {
      byStatus[task.status] = (byStatus[task.status] ?? 0) + 1;
      byPriority[task.priority] = (byPriority[task.priority] ?? 0) + 1;
      if (task.isDone) completed++;
      if (!task.isDone && task.status != 'CANCELLED') pendingInProgress++;
      if (task.priority == 'HIGH' || task.priority == 'URGENT') {
        highPriority++;
      }
      if (task.hasResponsibleParticipant) assignedCount++;
      final dueDate = task.dueDate;
      if (dueDate == null || task.isDone || task.status == 'CANCELLED') {
        continue;
      }
      final due = _dateOnly(dueDate);
      if (due.isBefore(today)) overdue++;
      if (due == today) dueToday++;
    }

    return TaskSummary(
      weddingPlanId: weddingPlanId,
      total: tasks.length,
      completed: completed,
      pendingInProgress: pendingInProgress,
      overdue: overdue,
      dueToday: dueToday,
      highPriority: highPriority,
      assigneeSummary: TaskAssigneeSummary(
        assignedCount: assignedCount,
        unassignedCount: tasks.length - assignedCount,
      ),
      byStatus: byStatus,
      byPriority: byPriority,
    );
  }

  final String weddingPlanId;
  final int total;
  final int completed;
  final int pendingInProgress;
  final int overdue;
  final int dueToday;
  final int highPriority;
  final int assignedToMe;
  final TaskAssigneeSummary assigneeSummary;
  final Map<String, int> byStatus;
  final Map<String, int> byPriority;

  int get cancelled => byStatus['CANCELLED'] ?? 0;

  double get completionRatio {
    if (total <= 0) return 0;
    return (completed / total).clamp(0.0, 1.0);
  }

  int get completionPercent => (completionRatio * 100).round();
}

class TaskAssigneeSummary {
  const TaskAssigneeSummary({
    this.assignedToMe = 0,
    this.assignedCount = 0,
    this.unassignedCount = 0,
  });

  factory TaskAssigneeSummary.fromJson(Map<String, dynamic> json) {
    return TaskAssigneeSummary(
      assignedToMe: _intOrZero(json['assignedToMe']),
      assignedCount: _intOrZero(json['assignedCount']),
      unassignedCount: _intOrZero(json['unassignedCount']),
    );
  }

  final int assignedToMe;
  final int assignedCount;
  final int unassignedCount;
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value);
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(
    value,
  ).map((key, value) => MapEntry(key, _intOrZero(value)));
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
