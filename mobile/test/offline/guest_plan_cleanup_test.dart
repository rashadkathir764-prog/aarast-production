import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guest plan cleanup removes only its graph and queue', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();

    await database.saveCachedItem(
      table: OfflineTables.currentUserProfile,
      json: {'id': 'user-1', 'name': 'Authenticated user'},
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      json: {'id': 'guest-plan-1', 'title': 'Guest plan'},
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 'guest-task',
        'weddingPlanId': 'guest-plan-1',
        'title': 'Guest task',
      },
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 'account-task',
        'weddingPlanId': 'account-plan-1',
        'title': 'Account task',
      },
    );
    await database.setMeta('timeline:guest-plan-1', '{"guest":true}');
    await database.setMeta('timeline:account-plan-1', '{"account":true}');
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/guest-plan-1/tasks',
      method: 'POST',
      payload: {'weddingPlanId': 'guest-plan-1'},
    );
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/account-plan-1/tasks',
      method: 'POST',
      payload: {'weddingPlanId': 'account-plan-1'},
    );

    await database.deletePlanGraph('guest-plan-1');

    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        id: 'guest-plan-1',
      ),
      isNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: 'guest-task',
      ),
      isNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: 'account-task',
      ),
      isNotNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.currentUserProfile,
        id: 'user-1',
      ),
      isNotNull,
    );
    expect(await database.pendingSyncItems(), hasLength(1));
    expect(await database.getMeta('timeline:guest-plan-1'), isNull);
    expect(await database.getMeta('timeline:account-plan-1'), isNotNull);
  });
}
