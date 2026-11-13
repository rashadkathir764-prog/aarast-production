import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_contract.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/tasks/tasks_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-203: a plan with no tasks, opened without a connection, showed an
// error: an empty list kept on the phone counted as «no copy». The server's
// empty answer is a copy like any other; only a list never read is not.

class _Server extends ApiClient {
  _Server() : super(tokenProvider: () async => 'token');

  bool offline = false;

  @override
  Future<List<dynamic>> getJsonList(String path) async {
    if (offline) {
      throw const ApiException('ما وصلنا للخادم.', isNetworkFailure: true);
    }
    return const [];
  }
}

Future<(TaskTimelineApi, _Server, JsonLocalDatabase)> _setUp() async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final server = _Server();
  final offline = OfflineSyncService(database: database, apiClient: server);
  await offline.initialize();
  return (TaskTimelineApi(server, offline: offline), server, database);
}

void main() {
  test('a plan read empty stays empty without a connection', () async {
    final (api, server, _) = await _setUp();
    expect(await api.getTasks('plan-1'), isEmpty);

    server.offline = true;
    final served = OfflineReads.copiesServed;
    expect(await api.getTasks('plan-1'), isEmpty);
    expect(OfflineReads.copiesServed, served + 1, reason: 'an old copy');
  });

  test('a plan never read still says it could not be reached', () async {
    final (api, server, _) = await _setUp();
    expect(await api.getTasks('plan-1'), isEmpty);
    server.offline = true;

    await expectLater(api.getTasks('plan-2'), throwsA(isA<ApiException>()));
  });

  test('a plan taken off the phone takes its empty copy with it', () async {
    final (api, server, database) = await _setUp();
    expect(await api.getTasks('plan-1'), isEmpty);
    await database.deletePlanGraph('plan-1');
    server.offline = true;

    await expectLater(api.getTasks('plan-1'), throwsA(isA<ApiException>()));
    expect(
      await database.getMeta(
        keptListMetaKey(OfflineTables.cachedTasks, 'plan-1'),
      ),
      isNull,
    );
  });
}
