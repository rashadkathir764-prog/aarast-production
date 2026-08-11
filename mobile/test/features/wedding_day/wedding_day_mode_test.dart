import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_day/models/wedding_day_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wedding day mode window', () {
    test('opens only from the last week through the following day', () {
      final today = DateTime(2026, 8, 9, 18);

      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 16), now: today).phase,
        WeddingDayPhase.countdown,
      );
      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 10), now: today).phase,
        WeddingDayPhase.tomorrow,
      );
      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 9, 21), now: today).phase,
        WeddingDayPhase.today,
      );
      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 8), now: today).phase,
        WeddingDayPhase.wrapUp,
      );
      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 17), now: today).isVisible,
        isFalse,
      );
      expect(
        resolveWeddingDayMode(DateTime(2026, 8, 7), now: today).isVisible,
        isFalse,
      );
    });

    test('selects only real unfinished tasks due by the active cutoff', () {
      final now = DateTime(2026, 8, 9);
      final status = resolveWeddingDayMode(DateTime(2026, 8, 10), now: now);
      final tasks = [
        _task('overdue', dueDate: DateTime(2026, 8, 8), priority: 'MEDIUM'),
        _task('event', dueDate: DateTime(2026, 8, 10), priority: 'HIGH'),
        _task('later', dueDate: DateTime(2026, 8, 11), priority: 'URGENT'),
        _task('undated-high', priority: 'HIGH'),
        _task('undated-low', priority: 'LOW'),
        _task('done', dueDate: DateTime(2026, 8, 9), status: 'DONE'),
      ];

      final result = weddingDayPriorityTasks(
        tasks: tasks,
        status: status,
        now: now,
      );

      expect(result.map((task) => task.id), [
        'overdue',
        'event',
        'undated-high',
      ]);
    });

    test('monogram uses the truthful plan title', () {
      expect(weddingPlanMonogram('عرس ريان وسارة'), 'رو');
      expect(weddingPlanMonogram('خطة الزفاف'), 'ا');
      expect(weddingPlanMonogram(''), 'ع');
    });
  });
}

WeddingTask _task(
  String id, {
  DateTime? dueDate,
  String priority = 'MEDIUM',
  String status = 'TODO',
}) {
  return WeddingTask(
    id: id,
    weddingPlanId: 'plan-1',
    title: id,
    status: status,
    priority: priority,
    dueDate: dueDate,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}
