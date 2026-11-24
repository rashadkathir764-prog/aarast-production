import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-BE-184: a task's day went to the server with no zone
// («2027-04-10T00:00:00.000»), so the server read it in its own: right
// only while it ran between UTC-3 and UTC+3. It now carries its zone, the
// day's midnight in UTC, which is what the server kept for it.

class _Api extends ApiClient {
  _Api() : super(tokenProvider: () async => 'token');

  final posted = <Map<String, dynamic>>[];
  final patched = <Map<String, dynamic>>[];

  Map<String, dynamic> _task(Map<String, dynamic> data) => {
    'id': 'task-1',
    'weddingPlanId': 'plan-1',
    'title': 'احجز القاعة',
    'status': 'TODO',
    'priority': 'MEDIUM',
    'createdAt': '2026-11-01T00:00:00.000Z',
    'updatedAt': '2026-11-01T00:00:00.000Z',
    ...data,
  };

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    posted.add(data);
    return _task(data);
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    patched.add(data);
    return _task(data);
  }
}

void main() {
  test('a new task\'s day is sent with its zone', () async {
    final client = _Api();
    await TaskTimelineApi(client).createTask(
      weddingPlanId: 'plan-1',
      title: 'احجز القاعة',
      dueDate: DateTime(2027, 4, 10),
    );

    expect(client.posted.single['dueDate'], '2027-04-10T00:00:00.000Z');
  });

  test('a task moved to another day sends that day with its zone', () async {
    final client = _Api();
    final provider = TaskTimelineProvider(TaskTimelineApi(client));
    final task = WeddingTask(
      id: 'task-1',
      weddingPlanId: 'plan-1',
      title: 'احجز القاعة',
      status: 'TODO',
      priority: 'MEDIUM',
      dueDate: DateTime.utc(2027, 4, 10),
      createdAt: DateTime.utc(2026, 11),
      updatedAt: DateTime.utc(2026, 11),
    );

    // The same day, picked again on the phone: nothing to send for it.
    await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: task.title,
      dueDate: DateTime(2027, 4, 10),
      status: 'TODO',
      priority: 'MEDIUM',
    );
    expect(client.patched, isEmpty);

    await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: task.title,
      dueDate: DateTime(2027, 4, 17),
      status: 'TODO',
      priority: 'MEDIUM',
    );
    expect(client.patched.single['dueDate'], '2027-04-17T00:00:00.000Z');
  });
}
