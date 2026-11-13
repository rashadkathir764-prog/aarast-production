import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/tasks/tasks_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-193: a task finished without a connection still counted open on the
// home: offline the counts came from the server's last summary, read before
// the change. The phone's kept list holds the change, so the counts are its;
// the old summary lends only what the phone cannot know.

class _Server extends ApiClient {
  _Server() : super(tokenProvider: () async => 'token');

  bool offline = false;

  Never _unreachable() =>
      throw const ApiException('ما وصلنا للخادم.', isNetworkFailure: true);

  @override
  Future<List<dynamic>> getJsonList(String path) async {
    if (offline) _unreachable();
    return [_task('t1', 'DONE'), _task('t2', 'TODO')];
  }

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (offline) _unreachable();
    return {
      'weddingPlanId': 'plan-1',
      'total': 2,
      'completed': 1,
      'canKeepPrivateTask': true,
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async => _unreachable();
}

Map<String, dynamic> _task(String id, String status) => {
  'id': id,
  'weddingPlanId': 'plan-1',
  'title': 'مهمة $id',
  'status': status,
  'priority': 'MEDIUM',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': '2026-11-01T00:00:00.000Z',
};

void main() {
  test('a task finished offline counts done in the summary', () async {
    SharedPreferences.setMockInitialValues({});
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    final server = _Server();
    final offline = OfflineSyncService(database: database, apiClient: server);
    await offline.initialize();
    final api = TaskTimelineApi(server, offline: offline);
    final provider = TaskTimelineProvider(api);

    await provider.load('plan-1');
    expect(provider.summary.completed, 1);

    server.offline = true;
    final open = provider.tasks.firstWhere((task) => task.id == 't2');
    expect(await provider.markTaskDone('plan-1', open), isTrue);

    final summary = await api.getTaskSummary('plan-1');
    expect(summary.completed, 2);
    expect(summary.total, 2);
    expect(summary.canKeepPrivateTask, isTrue, reason: 'the server\'s word');
    expect(provider.summary.completed, 2);
  });
}
