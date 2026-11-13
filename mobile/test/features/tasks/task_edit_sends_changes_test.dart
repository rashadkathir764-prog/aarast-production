import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/cache_policy.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-183 (batch 5): postponing a task, or editing one, sent the whole
// task as the phone held it: its title, its note, its status, who does it.
// From a copy that was a little old, «أجّلها» reopened a task the partner
// had finished since (and the server then kept it open against its own
// booking link, as «reopened by hand»), and brought back a title and an
// assignment someone else had changed. A change sends what was changed.
void main() {
  late _RecordingTaskApi api;
  late TaskTimelineProvider provider;

  setUp(() async {
    api = _RecordingTaskApi();
    provider = TaskTimelineProvider(api);
    await provider.load('plan-1');
  });

  // RA-MO-192: a task the server has, changed with no network, said
  // «انحفظت» as if sent; the notice was tied to tasks never sent.
  test('a change that waits on the phone says so', () async {
    api.queued = true;
    final task = api.serverTask;
    final ok = await provider.updateTaskStatus('plan-1', task, 'DONE');

    expect(ok, isTrue);
    expect(provider.noticeMessage, CachePolicy.offlineWriteMessage);
  });

  test('postponing a task sends its new day and nothing else', () async {
    final ok = await provider.rescheduleTask(
      'plan-1',
      api.serverTask,
      DateTime(2026, 12, 20),
    );

    expect(ok, isTrue);
    expect(api.sent, hasLength(1));
    expect(api.sent.single.keys, ['dueDate']);
    expect(
      DateTime.parse(api.sent.single['dueDate'] as String),
      DateTime(2026, 12, 20),
    );
  });

  test('an edit sends the fields the person changed', () async {
    final task = api.serverTask;
    final ok = await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: 'احجز القاعة الكبيرة',
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      responsibleName: task.responsibleName,
      responsiblePhone: task.responsiblePhone,
      responsibleSource: task.responsibleSource,
      status: task.status,
      priority: 'HIGH',
    );

    expect(ok, isTrue);
    expect(api.sent.single, {
      'title': 'احجز القاعة الكبيرة',
      'priority': 'HIGH',
    });
  });

  test('a status is sent only when the person changed it', () async {
    final task = api.serverTask;
    await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      responsibleName: task.responsibleName,
      responsiblePhone: task.responsiblePhone,
      responsibleSource: task.responsibleSource,
      status: 'DONE',
      priority: task.priority,
    );

    expect(api.sent.single, {'status': 'DONE'});
  });

  test('who does it by name is sent only when it changed', () async {
    final task = api.serverTask;
    await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      responsibleName: 'خالد',
      responsiblePhone: '+967777000111',
      responsibleSource: task.responsibleSource,
      status: task.status,
      priority: task.priority,
    );

    expect(api.sent.single, {
      'responsibleName': 'خالد',
      'responsiblePhone': '+967777000111',
      'responsibleSource': task.responsibleSource,
    });
  });

  test('nothing changed sends nothing and is not a failure', () async {
    final task = api.serverTask;
    final ok = await provider.updateTask(
      weddingPlanId: 'plan-1',
      task: task,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      responsibleName: task.responsibleName,
      responsiblePhone: task.responsiblePhone,
      responsibleSource: task.responsibleSource,
      status: task.status,
      priority: task.priority,
    );

    expect(ok, isTrue);
    expect(api.sent, isEmpty);
  });
}

class _RecordingTaskApi extends TaskTimelineApi {
  _RecordingTaskApi() : super(ApiClient(tokenProvider: () async => null));

  final sent = <Map<String, dynamic>>[];

  /// The change waits on the phone (no network).
  bool queued = false;

  @override
  bool hasUnsentChange(String taskId) => queued;

  WeddingTask serverTask = WeddingTask(
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'احجز القاعة',
    description: 'قاعة سبأ',
    dueDate: DateTime(2026, 12, 1),
    taskCategory: 'VENUE',
    responsibleName: 'الوالد',
    responsibleSource: 'MANUAL',
    status: 'TODO',
    priority: 'MEDIUM',
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [
    serverTask,
  ];

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    sent.add(data);
    return serverTask;
  }
}
