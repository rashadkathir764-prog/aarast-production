import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_contract.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-336: a participant whose right to the plan's money was withdrawn
// kept the money on the phone: costs, payments, dates, funding, the budget,
// the home's figures. Only a whole plan could be taken off (deletePlanGraph),
// and the plan stays: only its money goes.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const moneyTables = [
    OfflineTables.cachedBudgetCategories,
    OfflineTables.cachedCosts,
    OfflineTables.cachedCostPayments,
    OfflineTables.cachedPaymentSchedules,
    OfflineTables.cachedFundingSources,
    OfflineTables.cachedDashboardSummaries,
  ];
  const moneyMeta = [
    'money_budget',
    'money-summary',
    'money-funding',
    'funding',
  ];

  Future<void> fill(JsonLocalDatabase database, String planId) async {
    for (final table in moneyTables) {
      await database.saveCachedItem(
        table: table,
        json: {
          'id': '$table-$planId',
          'planId': planId,
          'weddingPlanId': planId,
          'amount': '1250000',
        },
      );
      await database.setMeta(keptListMetaKey(table, planId), '1');
    }
    for (final key in moneyMeta) {
      await database.setMeta('$key:$planId', '{"total":"1250000"}');
    }
    // What is not money.
    await database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: {'id': 'g-$planId', 'weddingPlanId': planId, 'name': 'سالم'},
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {'id': 't-$planId', 'weddingPlanId': planId, 'title': 'حجز القاعة'},
    );
    await database.setMeta('timeline:$planId', '[]');
  }

  Future<bool> hasMoney(JsonLocalDatabase database, String planId) async {
    for (final table in moneyTables) {
      final rows = await database.readCachedItem(
        table: table,
        id: '$table-$planId',
      );
      if (rows != null) return true;
      if (await database.getMeta(keptListMetaKey(table, planId)) != null) {
        return true;
      }
    }
    for (final key in moneyMeta) {
      if (await database.getMeta('$key:$planId') != null) return true;
    }
    return false;
  }

  test('only the plan\'s money goes, the plan and the others stay', () async {
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    await fill(database, 'plan-1');
    await fill(database, 'plan-2');
    expect(await hasMoney(database, 'plan-1'), isTrue);

    await database.deletePlanMoney('plan-1');

    expect(await hasMoney(database, 'plan-1'), isFalse);
    // The plan's guests, tasks and timeline are not money.
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedGuests,
        id: 'g-plan-1',
      ),
      isNotNull,
    );
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: 't-plan-1',
      ),
      isNotNull,
    );
    expect(await database.getMeta('timeline:plan-1'), isNotNull);
    // Another plan's money is its own.
    expect(await hasMoney(database, 'plan-2'), isTrue);
  });

  test('a wiped plan\'s money is not read back as an empty list', () async {
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    await fill(database, 'plan-1');

    await database.deletePlanMoney('plan-1');

    // «Kept empty» would read as «no costs» offline (RA-MO-203): no marker
    // is left for the money tables.
    for (final table in moneyTables) {
      expect(await database.getMeta(keptListMetaKey(table, 'plan-1')), isNull);
    }
  });

  test('the sync service wipes it for the signed-in account', () async {
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.ensureCacheOwner('user-A');
    await fill(database, 'plan-1');

    await offline.clearPlanMoney('plan-1');

    expect(await hasMoney(database, 'plan-1'), isFalse);
    expect(await database.getMeta('timeline:plan-1'), isNotNull);
  });
}
