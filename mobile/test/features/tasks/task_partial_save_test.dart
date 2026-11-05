import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// F05: when the server saves the task fields but rejects the new assignee,
// the app must show what was actually saved and say what was not.
void main() {
  late _PartialTaskApi api;
  late TaskTimelineProvider provider;

  setUp(() async {
    api = _PartialTaskApi();
    provider = TaskTimelineProvider(api);
    await provider.load('plan-1');
  });

  Future<bool> editTitleAndAssignee() => provider.updateTask(
    weddingPlanId: 'plan-1',
    task: api.serverTask,
    title: 'Updated',
    assigneeUserId: 'user-2',
    assigneeName: 'سالم',
    status: 'TODO',
    priority: 'MEDIUM',
  );

  test(
    'a rejected assignee keeps the saved fields and says what failed',
    () async {
      api.rejectAssign = true;

      final ok = await editTitleAndAssignee();

      expect(ok, isFalse);
      expect(api.updateCalls, 1);
      final shown = provider.tasks.singleWhere((task) => task.id == 'task-1');
      expect(shown.title, 'Updated');
      expect(shown.assigneeUserId, isNull);
      expect(provider.errorMessage, contains('انحفظت تفاصيل المهمة'));
      expect(provider.errorMessage, contains('المسؤول غير متاح.'));
    },
  );

  test('retrying after a rejected assignee only retries what failed', () async {
    api.rejectAssign = true;
    await editTitleAndAssignee();

    api.rejectAssign = false;
    final ok = await editTitleAndAssignee();

    expect(ok, isTrue);
    final shown = provider.tasks.singleWhere((task) => task.id == 'task-1');
    expect(shown.title, 'Updated');
    expect(shown.assigneeUserId, 'user-2');
    expect(api.assignCalls, 2);
  });

  test('a rejected field update still restores the previous task', () async {
    api.rejectUpdate = true;

    final ok = await editTitleAndAssignee();

    expect(ok, isFalse);
    expect(api.assignCalls, 0);
    final shown = provider.tasks.singleWhere((task) => task.id == 'task-1');
    expect(shown.title, 'Original');
    expect(provider.errorMessage, 'العنوان غير صالح.');
  });
}

class _PartialTaskApi extends TaskTimelineApi {
  _PartialTaskApi() : super(ApiClient(tokenProvider: () async => null));

  bool rejectAssign = false;
  bool rejectUpdate = false;
  int updateCalls = 0;
  int assignCalls = 0;

  WeddingTask serverTask = WeddingTask(
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'Original',
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
    if (rejectUpdate) {
      throw const ApiException('العنوان غير صالح.', statusCode: 400);
    }
    updateCalls += 1;
    serverTask = serverTask.copyWith(title: data['title'] as String?);
    return serverTask;
  }

  @override
  Future<WeddingTask> assignTask(
    String id, {
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
  }) async {
    assignCalls += 1;
    if (rejectAssign) {
      throw const ApiException('المسؤول غير متاح.', statusCode: 400);
    }
    serverTask = serverTask.copyWith(
      assigneeUserId: assigneeUserId,
      assigneeName: assigneeName,
    );
    return serverTask;
  }
}
