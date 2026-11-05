import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D89: a task's sub-steps, who it is assigned to and the bulk date shift
// need the server now; without it the failure names the measured cause
// and why it cannot wait on the phone (D85 serverOnly), never a generic
// «ما انحفظت».
class _Server implements HttpClientAdapter {
  bool down = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'id': 'step-9', 'taskId': 'task-1', 'title': 'x'}),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a sub-step without the server says why it cannot wait', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final reachability = ServerReachability();
    final apiClient = ApiClient(
      tokenProvider: () async => 'token',
      reachability: reachability,
    );
    apiClient.dio.httpClientAdapter = _Server();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
      reachability: reachability,
    );
    await offline.refreshStatus();
    final api = TaskTimelineApi(apiClient, offline: offline);
    final task = WeddingTask(
      id: 'task-1',
      weddingPlanId: 'plan-1',
      title: 'احجز القاعة',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

    Object? failure;
    try {
      await api.createChecklistItem(task, 'اتصل بالقاعة');
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isA<ApiException>());
    final exception = failure! as ApiException;
    expect(exception.isNetworkFailure, isTrue);
    expect(exception.message, contains('الخطوات الفرعية'));
    expect(exception.message, contains('المهمة نفسها محفوظة في جوالك'));
  });
}
