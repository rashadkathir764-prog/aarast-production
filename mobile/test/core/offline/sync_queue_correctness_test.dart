import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<JsonLocalDatabase> buildDatabase() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    return database;
  }

  test('rewriteQueuedReferences fixes local FK ids in pending payloads',
      () async {
    final database = await buildDatabase();
    await database.enqueueSync(
      entityType: 'expense',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/expenses',
      method: 'POST',
      payload: {
        'title': 'عربون القاعة',
        'amount': '200000',
        'budgetCategoryId': 'local-budget-category-7',
      },
      localEntityId: 'local-expense-1',
    );
    await database.enqueueSync(
      entityType: 'budget_category',
      operation: 'update',
      endpoint: '/budget-categories/local-budget-category-7',
      method: 'PATCH',
      payload: {'name': 'القاعة'},
      localEntityId: 'local-budget-category-7',
    );

    await database.rewriteQueuedReferences(
      localId: 'local-budget-category-7',
      remoteId: 'srv-cat-99',
    );

    final items = await database.pendingSyncItems();
    final expense = items.firstWhere((item) => item.entityType == 'expense');
    final category = items.firstWhere(
      (item) => item.entityType == 'budget_category',
    );
    expect(expense.payload['budgetCategoryId'], 'srv-cat-99');
    expect(category.endpoint, '/budget-categories/srv-cat-99');
  });

  test('blocked items are excluded from automatic replay', () async {
    final database = await buildDatabase();
    final item = await database.enqueueSync(
      entityType: 'expense',
      operation: 'create',
      endpoint: '/expenses',
      method: 'POST',
      payload: {'amount': 'not-a-number'},
      localEntityId: 'local-expense-2',
    );

    await database.markSyncItemBlocked(item.id, 'amount must be valid');

    expect(await database.pendingSyncItems(), isEmpty);
  });

  test('failed items keep retrying until blocked', () async {
    final database = await buildDatabase();
    final item = await database.enqueueSync(
      entityType: 'expense',
      operation: 'create',
      endpoint: '/expenses',
      method: 'POST',
      payload: {'amount': '100'},
      localEntityId: 'local-expense-3',
    );

    await database.markSyncItemFailed(item.id, 'server hiccup');

    final pending = await database.pendingSyncItems();
    expect(pending, hasLength(1));
    expect(pending.single.retryCount, 1);
    expect(pending.single.status, SyncQueueItem.failed);
  });
}
