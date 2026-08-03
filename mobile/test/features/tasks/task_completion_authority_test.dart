import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'task completion does not expose DONE before the server accepts the mutation',
    () async {
      final adapter = _DeferredTaskCompletionAdapter();
      final client = ApiClient(tokenProvider: () async => 'session-token');
      client.dio.httpClientAdapter = adapter;
      final provider = TaskTimelineProvider(TaskTimelineApi(client));
      addTearDown(provider.dispose);
      addTearDown(client.dio.close);

      await provider.load('plan-1');
      final initialTask = provider.tasks.single;

      final completion = provider.markTaskDone('plan-1', initialTask);
      await adapter.updateStarted.future;

      expect(provider.isSubmitting, isTrue);
      expect(provider.tasks.single.status, 'TODO');

      adapter.completeUpdate();
      expect(await completion, isTrue);
      expect(provider.tasks.single.status, 'DONE');
    },
  );
}

class _DeferredTaskCompletionAdapter implements HttpClientAdapter {
  final Completer<void> updateStarted = Completer<void>();
  final Completer<ResponseBody> _updateResponse = Completer<ResponseBody>();

  void completeUpdate() {
    _updateResponse.complete(_jsonResponse(_taskJson(status: 'DONE')));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    switch ('${options.method} ${options.path}') {
      case 'GET /api/v1/wedding-plans/plan-1/tasks':
        return Future<ResponseBody>.value(_jsonResponse([_taskJson()]));
      case 'GET /api/v1/wedding-plans/plan-1/timeline':
        return Future<ResponseBody>.value(
          _jsonResponse(const {'upcomingTasks': [], 'paymentSchedules': []}),
        );
      case 'GET /api/v1/wedding-plans/plan-1/tasks/summary':
        return Future<ResponseBody>.value(
          _jsonResponse(const {'weddingPlanId': 'plan-1'}),
        );
      case 'PATCH /api/v1/tasks/task-1':
        updateStarted.complete();
        return _updateResponse.future;
      default:
        throw StateError(
          'Unexpected request: ${options.method} ${options.path}',
        );
    }
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _taskJson({String status = 'TODO'}) => {
  'id': 'task-1',
  'weddingPlanId': 'plan-1',
  'title': 'تأكيد القاعة',
  'status': status,
  'priority': 'MEDIUM',
  'createdAt': '2026-08-02T00:00:00.000Z',
  'updatedAt': '2026-08-02T00:00:00.000Z',
};

ResponseBody _jsonResponse(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    Headers.contentTypeHeader: const ['application/json'],
  },
);
