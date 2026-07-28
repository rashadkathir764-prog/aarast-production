import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offline create then edit replays one merged create without local ids', () async {
    final harness = await _Harness.create();

    final task = await harness.api.createTask(
      weddingPlanId: 'plan-1',
      title: 'العنوان الأول',
      description: 'الوصف الأول',
    );
    await harness.api.updateTask(task.id, {
      'title': 'العنوان المصحح',
      'priority': 'HIGH',
    });

    final queued = await harness.database.pendingSyncItems();
    expect(queued, hasLength(1));
    expect(queued.single.operation, 'create');
    expect(queued.single.payload['title'], 'العنوان المصحح');
    expect(queued.single.payload['description'], 'الوصف الأول');
    expect(queued.single.payload['priority'], 'HIGH');

    harness.adapter.online = true;
    await harness.offline.syncPendingChanges();

    final replay = harness.adapter.successfulRequests.single;
    expect(replay.path, '/api/v1/wedding-plans/plan-1/tasks');
    expect(replay.path, isNot(contains('local-task-')));
    expect(jsonEncode(replay.data), isNot(contains('local-task-')));
    expect(Map<String, dynamic>.from(replay.data as Map)['title'], 'العنوان المصحح');
    expect(await harness.database.pendingSyncItems(), isEmpty);
  });

  test('offline create then delete cancels the local task without an API delete', () async {
    final harness = await _Harness.create();

    final task = await harness.api.createTask(
      weddingPlanId: 'plan-1',
      title: 'مهمة مؤقتة',
    );
    await harness.api.deleteTask(task.id);

    expect(
      await harness.database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: task.id,
      ),
      isNull,
    );
    expect(await harness.database.pendingSyncItems(), isEmpty);
    expect(
      harness.adapter.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    expect(
      harness.adapter.requests.map((request) => request.path),
      everyElement(isNot(contains('local-task-'))),
    );
  });

  test('offline assigned task creates first then assigns with the remote id', () async {
    final harness = await _Harness.create();

    await harness.api.createTask(
      weddingPlanId: 'plan-1',
      title: 'مهمة مشتركة',
      assigneeUserId: 'member-1',
      assigneeName: 'سارة',
    );
    expect(
      (await harness.database.pendingSyncItems()).map((item) => item.operation),
      ['create', 'assign'],
    );

    harness.adapter.online = true;
    await harness.offline.syncPendingChanges();

    expect(harness.adapter.successfulRequests, hasLength(2));
    final assignRequest = harness.adapter.successfulRequests.last;
    expect(assignRequest.path, '/api/v1/tasks/remote-task-1/assign');
    expect(assignRequest.path, isNot(contains('local-task-')));
    expect(jsonEncode(assignRequest.data), isNot(contains('local-task-')));
    expect(await harness.database.pendingSyncItems(), isEmpty);
  });
}

class _Harness {
  const _Harness({
    required this.database,
    required this.offline,
    required this.api,
    required this.adapter,
  });

  final JsonLocalDatabase database;
  final OfflineSyncService offline;
  final TaskTimelineApi api;
  final _ToggleTaskAdapter adapter;

  static Future<_Harness> create() async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final client = ApiClient(tokenProvider: () async => 'token');
    final adapter = _ToggleTaskAdapter();
    client.dio.httpClientAdapter = adapter;
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.ensureCacheOwner('user-1');
    return _Harness(
      database: database,
      offline: offline,
      api: TaskTimelineApi(client, offline: offline),
      adapter: adapter,
    );
  }
}

class _ToggleTaskAdapter implements HttpClientAdapter {
  bool online = false;
  final List<RequestOptions> requests = [];
  final List<RequestOptions> successfulRequests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!online) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    successfulRequests.add(options);
    final payload = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'remote-task-1',
        'weddingPlanId': 'plan-1',
        ...payload,
        'createdAt': '2026-07-28T00:00:00.000Z',
        'updatedAt': '2026-07-28T00:00:00.000Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
