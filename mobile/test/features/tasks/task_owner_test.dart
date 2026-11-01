import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Choosing «أنا» saves the owner's account and name on the task. The task is
// still the owner's own, and is not shown as someone else's.

WeddingTask _task({String? assigneeUserId, String? assigneeName}) {
  return WeddingTask(
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'احجز القاعة',
    status: 'TODO',
    priority: 'MEDIUM',
    assigneeUserId: assigneeUserId,
    assigneeName: assigneeName,
    createdAt: DateTime(2026, 6, 28),
    updatedAt: DateTime(2026, 6, 28),
  );
}

void main() {
  test('a task saved on the reader\'s account is theirs, named or not', () {
    final named = _task(assigneeUserId: 'user-1', assigneeName: 'رشاد');
    expect(named.responsibleLabel, 'رشاد');
    expect(named.isMineFor('user-1'), isTrue);
    expect(named.isMineFor('user-2'), isFalse);

    // No one named: the owner's.
    expect(_task().isMineFor('user-1'), isTrue);
    expect(_task().isMineFor(null), isTrue);

    // Another member's task, also when the reader is unknown.
    final other = _task(assigneeUserId: 'user-2', assigneeName: 'ليلى');
    expect(other.isMineFor('user-1'), isFalse);
    expect(other.isMineFor(null), isFalse);
  });

  testWidgets('the owner\'s own row shows his letter, not his name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TaskRow(
              task: _task(assigneeUserId: 'user-1', assigneeName: 'رشاد'),
              selfUserId: 'user-1',
              selfLetter: 'ر',
              onToggle: () {},
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The meta line names someone only when the task is not the reader's.
    expect(find.textContaining('رشاد'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
