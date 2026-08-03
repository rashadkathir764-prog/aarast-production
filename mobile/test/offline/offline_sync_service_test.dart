import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('refreshStatus exposes pending count and pending entity keys', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    final service = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );

    await service.refreshStatus();
    expect(service.pendingCount, 0);
    expect(service.hasPendingEntity('task', 'local-task-1'), isFalse);

    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'Offline task'},
      planId: 'plan-1',
      localEntityId: 'local-task-1',
    );

    await service.refreshStatus();

    expect(service.pendingCount, 1);
    expect(service.hasPendingEntity('task', 'local-task-1'), isTrue);
  });

  test(
    'replaceCachedItemId swaps local ids for remote ids after sync',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();

      await database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: {
          'id': 'local-task-1',
          'weddingPlanId': 'plan-1',
          'title': 'Offline task',
        },
        dirty: true,
      );

      await database.replaceCachedItemId(
        table: OfflineTables.cachedTasks,
        localId: 'local-task-1',
        remoteJson: {
          'id': 'remote-task-1',
          'weddingPlanId': 'plan-1',
          'title': 'Offline task',
        },
      );

      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedTasks,
          id: 'local-task-1',
        ),
        isNull,
      );
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedTasks,
          id: 'remote-task-1',
        ),
        isNotNull,
      );
    },
  );
}
