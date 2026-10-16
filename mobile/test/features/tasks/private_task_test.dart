import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_list_row.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.10: a task the owner or partner keeps to themselves.

void main() {
  test('a private task and the right to keep one read from the server', () {
    expect(_task(isPrivate: true).isPrivate, isTrue);
    expect(
      WeddingTask.fromJson({
        'id': 't',
        'weddingPlanId': 'plan-1',
        'title': 'x',
      }).isPrivate,
      isFalse,
    );
    expect(
      TaskSummary.fromJson({'canKeepPrivateTask': true}).canKeepPrivateTask,
      isTrue,
    );
    expect(TaskSummary.fromJson(const {}).canKeepPrivateTask, isFalse);
    // A summary built from cached tasks never offers privacy on its own.
    expect(
      TaskSummary.fromTasks(weddingPlanId: 'plan-1', tasks: const [])
          .canKeepPrivateTask,
      isFalse,
    );
    expect(_task(isPrivate: true).copyWith(title: 'y').isPrivate, isTrue);
  });

  test('the provider sends privacy on create and shares a private task', () async {
    final api = _PrivacyApi();
    final provider = TaskTimelineProvider(api);

    await provider.createTask(
      weddingPlanId: 'plan-1',
      title: 'هدية العروس',
      isPrivate: true,
    );
    expect(api.createdPrivate, [true]);
    expect(provider.tasks.single.isPrivate, isTrue);

    final shared = await provider.shareTaskWithPlan(
      'plan-1',
      provider.tasks.single,
    );
    expect(shared, isTrue);
    expect(api.updates.single, {'isPrivate': false});
    expect(provider.tasks.single.isPrivate, isFalse);
  });

  testWidgets('a private task shows a lock in the list, a shared one does not', (
    tester,
  ) async {
    Widget row(bool isPrivate) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TaskListRow(
          task: _task(isPrivate: isPrivate),
          isBusy: false,
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    await tester.pumpWidget(row(true));
    expect(find.byKey(const ValueKey('task-private-lock')), findsOneWidget);

    await tester.pumpWidget(row(false));
    expect(find.byKey(const ValueKey('task-private-lock')), findsNothing);
  });

  test('the privacy refusals reach the user in Arabic', () {
    for (final code in [
      'COST_PRIVACY_NOT_ALLOWED',
      'COST_PRIVACY_AT_CREATION_ONLY',
      'TASK_PRIVACY_NOT_ALLOWED',
      'TASK_PRIVACY_AT_CREATION_ONLY',
      'TASK_PRIVATE_ASSIGNMENT',
    ]) {
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/tasks/t'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/tasks/t'),
            statusCode: 400,
            data: {'code': code, 'message': 'English server text'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(exception.serverCode, code);
      expect(exception.message, isNot(contains('English')));
      expect(exception.message, contains('خاص'));
    }
  });
}

WeddingTask _task({required bool isPrivate}) => WeddingTask.fromJson({
  'id': 'task-1',
  'weddingPlanId': 'plan-1',
  'title': 'هدية العروس',
  'status': 'TODO',
  'priority': 'MEDIUM',
  'isPrivate': isPrivate,
});

class _PrivacyApi extends TaskTimelineApi {
  _PrivacyApi() : super(ApiClient(tokenProvider: () async => null));

  final List<bool> createdPrivate = [];
  final List<Map<String, dynamic>> updates = [];
  final List<WeddingTask> _tasks = [];

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => _tasks;

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  @override
  Future<WeddingTask> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
    String status = 'TODO',
    String priority = 'MEDIUM',
    bool isPrivate = false,
  }) async {
    createdPrivate.add(isPrivate);
    final task = _task(isPrivate: isPrivate);
    _tasks
      ..clear()
      ..add(task);
    return task;
  }

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    final task = _tasks.single.copyWith(isPrivate: data['isPrivate'] == true);
    _tasks
      ..clear()
      ..add(task);
    return task;
  }
}
