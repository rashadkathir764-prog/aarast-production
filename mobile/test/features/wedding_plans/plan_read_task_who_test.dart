import 'package:aarast_mobile/features/wedding_plans/models/plan_read_view.dart';
import 'package:flutter_test/flutter_test.dart';

// V-03: a task nobody was named for is the owner's (D52), so the one who
// follows the plan reads «على محمد», never a step with no one behind it.
void main() {
  PlanReadTask task(Object? assignee) => PlanReadTask.fromJson({
    'id': 't1',
    'title': 'حدد موعد عقد القران',
    'status': 'TODO',
    'assignee': assignee,
  }, 'plan-1');

  test('a task with no one named is on the owner', () {
    expect(task(null).whoLine(ownerWord: 'محمد'), 'على محمد');
    expect(task(null).whoLine(ownerWord: 'العريس'), 'على العريس');
  });

  test('a named person keeps their name', () {
    expect(
      task({'kind': 'MEMBER', 'firstName': 'صالح'}).whoLine(ownerWord: 'محمد'),
      'على صالح',
    );
    expect(
      task({'kind': 'YOU', 'firstName': 'صالح'}).whoLine(ownerWord: 'محمد'),
      'هذي المهمة عليك',
    );
  });

  test('a member without a name is still not the owner', () {
    expect(task({'kind': 'MEMBER'}).whoLine(ownerWord: 'محمد'), isNull);
  });
}
