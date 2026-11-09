import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/utils/task_display.dart';
import 'package:aarast_mobile/features/tasks/utils/task_groups.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_row.dart';
import 'package:flutter_test/flutter_test.dart';

/// RA-MO-25 (D11): a task's day is a day in Sana'a, as the server counts it.
/// A phone set to another zone, at an hour its date differs, called a task
/// due yesterday «اليوم» and one due today «بكرة».
void main() {
  WeddingTask due(DateTime day) => WeddingTask(
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'تأكيد القاعة',
    status: 'TODO',
    priority: 'MEDIUM',
    // As the server sends it: the day at midnight UTC.
    dueDate: DateTime.utc(day.year, day.month, day.day),
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  // 22:00 UTC on the 6th is 01:00 on the 7th in Sana'a.
  final lateNight = DateTime.utc(2026, 11, 6, 22);

  test('a task due on the 6th is late once the 7th begins in Sana\'a', () {
    expect(isTaskLate(due(DateTime(2026, 11, 6)), now: lateNight), isTrue);
    expect(
      isTaskLate(
        due(DateTime(2026, 11, 6)),
        now: DateTime.utc(2026, 11, 6, 20),
      ),
      isFalse,
      reason: '23:00 in Sana\'a is still the 6th',
    );
  });

  test('RA-MO-58: a cancelled task is not late', () {
    final cancelled = due(DateTime(2026, 11, 1)).copyWith(status: 'CANCELLED');
    expect(isTaskLate(cancelled, now: lateNight), isFalse);
    expect(cancelled.isOpen, isFalse);
  });

  test('«اليوم» and «بكرة» follow the day in Sana\'a', () {
    expect(taskWhenLabel(due(DateTime(2026, 11, 7)), now: lateNight), 'اليوم');
    expect(taskWhenLabel(due(DateTime(2026, 11, 8)), now: lateNight), 'بكرة');
  });

  test('a week out is the week, counted from the day in Sana\'a', () {
    expect(taskGroupOf(due(DateTime(2026, 11, 14)), lateNight), TaskGroup.week);
    expect(
      taskGroupOf(due(DateTime(2026, 11, 6)), lateNight),
      TaskGroup.overdue,
    );
  });
}
