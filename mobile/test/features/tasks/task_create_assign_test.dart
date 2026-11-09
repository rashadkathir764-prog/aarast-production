import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/tasks/tasks_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-55: a task given to a member is made, then given. The server made
// it and only the giving was lost on the network: the task is made once,
// and only its giving waits to be sent.

class _Server extends ApiClient {
  _Server() : super(tokenProvider: () async => 'token');

  final created = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    created.add(body);
    return {
      'id': 'task-1',
      'weddingPlanId': 'plan-1',
      ...body,
      'createdAt': '2026-11-09T00:00:00.000Z',
      'updatedAt': '2026-11-09T00:00:00.000Z',
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw const ApiException('ما وصلنا للخادم.', isNetworkFailure: true);
  }
}

void main() {
  test('a task made on the server is never queued to be made again', () async {
    SharedPreferences.setMockInitialValues({});
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    final server = _Server();
    final offline = OfflineSyncService(database: database, apiClient: server);
    await offline.initialize();
    final api = TaskTimelineApi(server, offline: offline);

    final task = await api.createTask(
      weddingPlanId: 'plan-1',
      title: 'رتّب الغداء',
      assigneeUserId: 'user-saleh',
      assigneeName: 'صالح',
    );

    expect(server.created, hasLength(1));
    expect(task.id, 'task-1');
    final queued = await database.pendingSyncItems();
    expect(
      queued.where((item) => item.operation == 'create'),
      isEmpty,
      reason: 'the task was made already',
    );
    expect(
      queued.where((item) => item.operation == 'assign').single.endpoint,
      '/api/v1/tasks/task-1/assign',
    );
    final cached = await database.readCachedList(
      table: OfflineTables.cachedTasks,
    );
    expect(cached.map((row) => row['id']), ['task-1']);
  });
}
