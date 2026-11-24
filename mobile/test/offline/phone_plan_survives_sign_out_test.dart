import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-319: a plan made on the phone before signing in keeps its guests,
// tasks and money in the phone's tables (dirty, never queued: no account
// owns it). Signing out, a session that ran out, or another account
// signing in wiped every table with it, while «الخروج» said «خطتك تبقى».
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(JsonLocalDatabase, OfflineSyncService)> phoneWithBothPlans() async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.ensureCacheOwner('user-A');

    // The phone's plan.
    await database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: {
        'id': 'local-guest-1',
        'weddingPlanId': 'local-guest-plan',
        'name': 'خالد',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 'local-task-1',
        'weddingPlanId': 'local-guest-plan',
        'title': 'حجز القاعة',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: {
        'id': 'local-cost-1',
        'weddingPlanId': 'local-guest-plan',
        'title': 'القاعة',
      },
      dirty: true,
    );
    await database.setMeta('money_budget:local-guest-plan', '{"total":"1"}');

    // The account's plan.
    await database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: {'id': 'g-1', 'weddingPlanId': 'plan-1', 'name': 'سالم'},
    );
    await database.saveCachedItem(
      table: OfflineTables.currentUserProfile,
      json: {'id': 'user-A'},
    );
    await database.setMeta('money_budget:plan-1', '{"total":"2"}');
    return (database, offline);
  }

  Future<void> expectPhonePlanKept(JsonLocalDatabase database) async {
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedGuests,
        id: 'local-guest-1',
      ),
      isNotNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: 'local-task-1',
      ),
      isNotNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedCosts,
        id: 'local-cost-1',
      ),
      isNotNull,
    );
    expect(await database.getMeta('money_budget:local-guest-plan'), isNotNull);
  }

  Future<void> expectAccountWiped(JsonLocalDatabase database) async {
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedGuests,
        id: 'g-1',
      ),
      isNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.currentUserProfile,
        id: 'user-A',
      ),
      isNull,
    );
    expect(await database.getMeta('money_budget:plan-1'), isNull);
  }

  test('signing out keeps the phone plan and wipes the account', () async {
    final (database, offline) = await phoneWithBothPlans();

    await offline.clearLocalData();

    await expectPhonePlanKept(database);
    await expectAccountWiped(database);
  });

  test('a session that ran out keeps the phone plan', () async {
    final (database, offline) = await phoneWithBothPlans();

    await offline.clearLocalData(keepUnsentChanges: true);

    await expectPhonePlanKept(database);
    await expectAccountWiped(database);
  });

  test('another account signing in keeps the phone plan', () async {
    final (database, offline) = await phoneWithBothPlans();

    await offline.ensureCacheOwner('user-B');

    await expectPhonePlanKept(database);
    await expectAccountWiped(database);
  });
}
