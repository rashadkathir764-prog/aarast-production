import '../../tasks/models/wedding_task.dart';

enum WeddingDayPhase { unavailable, countdown, tomorrow, today, wrapUp }

class WeddingDayModeStatus {
  const WeddingDayModeStatus({
    required this.phase,
    required this.daysUntil,
    required this.weddingDate,
  });

  final WeddingDayPhase phase;
  final int? daysUntil;
  final DateTime? weddingDate;

  bool get isVisible => phase != WeddingDayPhase.unavailable;

  String get eyebrow => switch (phase) {
    WeddingDayPhase.countdown => 'الأسبوع الأخير',
    WeddingDayPhase.tomorrow => 'غدًا يومكم',
    WeddingDayPhase.today => 'اليوم الكبير',
    WeddingDayPhase.wrapUp => 'بعد اليوم الكبير',
    WeddingDayPhase.unavailable => 'اليوم الكبير',
  };

  String get title => switch (phase) {
    WeddingDayPhase.countdown => 'اقترب اليوم الكبير',
    WeddingDayPhase.tomorrow => 'كل ما يلزم غدًا في مكان واحد',
    WeddingDayPhase.today => 'يومكم هنا، بهدوء ووضوح',
    WeddingDayPhase.wrapUp => 'راجع ما تبقّى بهدوء',
    WeddingDayPhase.unavailable => 'يُفتح وضع اليوم الكبير في أسبوع العرس',
  };

  String get dashboardLabel => switch (phase) {
    WeddingDayPhase.countdown => 'وضع الأسبوع الأخير · بقي $daysUntil أيام',
    WeddingDayPhase.tomorrow => 'غدًا يومكم · افتح وضع اليوم الكبير',
    WeddingDayPhase.today => 'افتح وضع اليوم الكبير',
    WeddingDayPhase.wrapUp => 'مراجعة اليوم الكبير',
    WeddingDayPhase.unavailable => 'وضع اليوم الكبير',
  };
}

WeddingDayModeStatus resolveWeddingDayMode(
  DateTime? weddingDate, {
  DateTime? now,
}) {
  if (weddingDate == null) {
    return const WeddingDayModeStatus(
      phase: WeddingDayPhase.unavailable,
      daysUntil: null,
      weddingDate: null,
    );
  }
  final today = _dateOnly(now ?? DateTime.now());
  final eventDay = _dateOnly(weddingDate);
  final difference = eventDay.difference(today).inDays;
  final phase = switch (difference) {
    >= 2 && <= 7 => WeddingDayPhase.countdown,
    1 => WeddingDayPhase.tomorrow,
    0 => WeddingDayPhase.today,
    -1 => WeddingDayPhase.wrapUp,
    _ => WeddingDayPhase.unavailable,
  };
  return WeddingDayModeStatus(
    phase: phase,
    daysUntil: difference,
    weddingDate: weddingDate,
  );
}

List<WeddingTask> weddingDayPriorityTasks({
  required List<WeddingTask> tasks,
  required WeddingDayModeStatus status,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final eventDay = status.weddingDate == null
      ? today
      : _dateOnly(status.weddingDate!);
  final cutoff = switch (status.phase) {
    WeddingDayPhase.countdown || WeddingDayPhase.tomorrow => eventDay,
    _ => today,
  };
  final selected = tasks.where((task) {
    if (task.isDone || task.status == 'CANCELLED') return false;
    final dueDate = task.dueDate;
    if (dueDate != null) return !_dateOnly(dueDate).isAfter(cutoff);
    final priority = task.priority.toUpperCase();
    return priority == 'HIGH' || priority == 'URGENT';
  }).toList();
  selected.sort((left, right) {
    final leftDue = left.dueDate;
    final rightDue = right.dueDate;
    if (leftDue == null && rightDue != null) return 1;
    if (leftDue != null && rightDue == null) return -1;
    if (leftDue != null && rightDue != null) {
      final dateOrder = leftDue.compareTo(rightDue);
      if (dateOrder != 0) return dateOrder;
    }
    return _priorityRank(
      right.priority,
    ).compareTo(_priorityRank(left.priority));
  });
  return selected;
}

String weddingPlanMonogram(String title) {
  const ignored = {'خطة', 'عرس', 'زفاف', 'حفل'};
  final words = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty && !ignored.contains(word))
      .take(2)
      .toList();
  if (words.isEmpty) return 'ع';
  return words.map((word) => word.substring(0, 1)).join();
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _priorityRank(String priority) => switch (priority.toUpperCase()) {
  'URGENT' => 4,
  'HIGH' => 3,
  'MEDIUM' => 2,
  _ => 1,
};
