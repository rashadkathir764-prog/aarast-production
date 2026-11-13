import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_postpone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-204: the plan's days are Sana'a's (D11). At 22:30 UTC it is already
// tomorrow in Sana'a; a phone set to another zone counted «بكرة» from its
// own day. Its own file: the clock is pinned for all of it.

WeddingTask _due(DateTime day) => WeddingTask(
  id: 't1',
  weddingPlanId: 'plan-1',
  title: 'حجز الكوافير',
  status: 'TODO',
  priority: 'MEDIUM',
  dueDate: day,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  // Friday 13 November 22:30 UTC: Saturday 14 November in Sana'a.
  setUp(() => pinAppClock(DateTime.utc(2026, 11, 13, 22, 30)));

  testWidgets('«بكرة» is tomorrow in Sana\'a', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TaskPostponeSheet(task: _due(DateTime(2026, 11, 14))),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tomorrow = tester.widget<JourneyListRow>(
      find.byKey(const ValueKey('task-postpone-بكرة')),
    );
    expect(
      tomorrow.subtitle,
      formatArabicWeekdayDayMonth(DateTime(2026, 11, 15)),
    );
  });
}
