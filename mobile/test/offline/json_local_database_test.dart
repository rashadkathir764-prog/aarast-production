import 'dart:convert';

import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'replaces cached list by parent without deleting other parents',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();

      await database.replaceCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: 'plan-1',
        items: [
          {'id': 'task-1', 'weddingPlanId': 'plan-1', 'title': 'First'},
        ],
      );
      await database.replaceCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: 'plan-2',
        items: [
          {'id': 'task-2', 'weddingPlanId': 'plan-2', 'title': 'Second'},
        ],
      );
      await database.replaceCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: 'plan-1',
        items: [
          {'id': 'task-3', 'weddingPlanId': 'plan-1', 'title': 'Replacement'},
        ],
      );

      final planOne = await database.readCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: 'plan-1',
      );
      final planTwo = await database.readCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: 'plan-2',
      );

      expect(planOne.single['id'], 'task-3');
      expect(planTwo.single['id'], 'task-2');
    },
  );

  test('sync queue keeps failed writes until they are marked synced', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();

    final queued = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'Offline task'},
      planId: 'plan-1',
      localEntityId: 'local-task-1',
    );

    var pending = await database.pendingSyncItems();
    expect(pending, hasLength(1));
    expect(pending.single.id, queued.id);
    expect(jsonDecode(pending.single.payloadJson)['title'], 'Offline task');

    await database.markSyncItemFailed(queued.id, 'network down');

    pending = await database.pendingSyncItems();
    expect(pending.single.retryCount, 1);
    expect(pending.single.lastError, 'network down');

    await database.markSyncItemSynced(queued.id);

    pending = await database.pendingSyncItems();
    expect(pending, isEmpty);
  });
}
