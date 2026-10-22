import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// C58: changes made offline survive an expired session for the same
// account, and never for another account or a sign-out the person chose.

Future<(JsonLocalDatabase, OfflineSyncService)> _signedIn(String user) async {
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final service = OfflineSyncService(
    database: database,
    apiClient: ApiClient(tokenProvider: () async => null),
  );
  await service.ensureCacheOwner(user);
  await database.enqueueSync(
    entityType: 'cost',
    operation: 'create',
    endpoint: '/costs',
    method: 'POST',
    payload: {'title': 'الذهب', 'amount': 300000},
    planId: 'plan-1',
  );
  await database.saveCachedItem(
    table: OfflineTables.cacheTables.first,
    json: {'id': 'cached-1', 'planId': 'plan-1'},
  );
  return (database, service);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'an expired session keeps the unsent change for the same account',
    () async {
      final (database, service) = await _signedIn('user-a');

      await service.clearLocalData(keepUnsentChanges: true);

      expect(await database.pendingSyncCount(), 1);
      expect(
        await database.readCachedList(table: OfflineTables.cacheTables.first),
        isEmpty,
      );
      await service.ensureCacheOwner('user-a');
      expect(await database.pendingSyncCount(), 1);
    },
  );

  test('another account after an expired session drops the change', () async {
    final (database, service) = await _signedIn('user-a');

    await service.clearLocalData(keepUnsentChanges: true);
    await service.ensureCacheOwner('user-b');

    expect(await database.pendingSyncCount(), 0);
  });

  test('a sign-out the person chose drops the change', () async {
    final (database, service) = await _signedIn('user-a');

    await service.clearLocalData();
    await service.ensureCacheOwner('user-a');

    expect(await database.pendingSyncCount(), 0);
  });
}
