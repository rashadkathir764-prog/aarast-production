import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/sync_queue.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A programmable Dio adapter: each call pops the next scripted outcome so
/// a test can drive the sync loop through success, 4xx, and network paths.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.outcomes);

  final List<ResponseBody Function(RequestOptions options)> outcomes;
  final List<RequestOptions> received = [];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    final outcome = outcomes[_index.clamp(0, outcomes.length - 1)];
    _index += 1;
    return outcome(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody _status(int code, String body) => ResponseBody.fromString(
  body,
  code,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

OfflineSyncService _service(
  JsonLocalDatabase database,
  _ScriptedAdapter adapter,
) {
  final apiClient = ApiClient(tokenProvider: () async => 'token');
  apiClient.dio.httpClientAdapter = adapter;
  return OfflineSyncService(database: database, apiClient: apiClient);
}

Future<JsonLocalDatabase> _freshDb() async {
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  return database;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a successful sync clears the queue and marks state synced', () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
      planId: 'plan-1',
      localEntityId: 'local-1',
    );
    final adapter = _ScriptedAdapter([(_) => _ok('{"id":"remote-1"}')]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(await database.pendingSyncCount(), 0);
    expect(service.state, SyncState.synced);
    expect(service.hasPendingChanges, isFalse);
  });

  test('sync sends the item id as the idempotency header', () async {
    final database = await _freshDb();
    final item = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
      planId: 'plan-1',
    );
    final adapter = _ScriptedAdapter([(_) => _ok('{"id":"remote-1"}')]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(adapter.received.single.headers['X-Client-Request-Id'], item.id);
  });

  // D93 (RA-BE-01): «حدّث التطبيق» is not a rejection of the change. The
  // queue stops and keeps every write, for the updated app to send.
  test('426 APP_UPDATE_REQUIRED stops the queue and keeps its writes', () async {
    final database = await _freshDb();
    for (final title in ['مهمة أولى', 'مهمة ثانية']) {
      await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/wedding-plans/plan-1/tasks',
        method: 'POST',
        payload: {'title': title},
        planId: 'plan-1',
      );
    }
    final adapter = _ScriptedAdapter([
      (_) => _status(
        426,
        '{"statusCode":426,"code":"APP_UPDATE_REQUIRED","message":"حدّث"}',
      ),
    ]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(adapter.received, hasLength(1), reason: 'stops at the first');
    expect(await database.pendingSyncCount(), 2);
    expect(service.blockedCount, 0);
    expect(await database.blockedSyncItems(), isEmpty);
  });

  test('a 400 rejection blocks the item immediately (no retry spin)', () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': ''},
      planId: 'plan-1',
    );
    final adapter = _ScriptedAdapter([
      (_) => _status(400, '{"message":"title should not be empty"}'),
    ]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    // Blocked items are excluded from the pending queue: they never replay.
    expect(await database.pendingSyncCount(), 0);
    final rows = await database.pendingSyncItems();
    expect(rows, isEmpty);
    expect(service.state, SyncState.syncError);
    expect(service.blockedCount, 1);

    final restartedService = _service(
      database,
      _ScriptedAdapter([(_) => _ok('{}')]),
    );
    await restartedService.refreshStatus();

    expect(restartedService.state, SyncState.syncError);
    expect(restartedService.blockedCount, 1);
    expect(restartedService.pendingCount, 0);
    // The reason survives the restart, in Arabic: the server's English
    // validation detail never reaches the user (V1 checklist 5.4).
    expect(restartedService.lastError, contains('راجع البيانات المدخلة'));
    expect(
      restartedService.lastError,
      isNot(contains('title should not be empty')),
    );
  });

  test(
    'blocked sync details are actionable without exposing raw errors',
    () async {
      final database = await _freshDb();
      final item = await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/wedding-plans/plan-1/tasks',
        method: 'POST',
        payload: {'title': ''},
        planId: 'plan-1',
        localEntityId: 'local-task-1',
      );
      await database.markSyncItemBlocked(
        item.id,
        'title should not be empty at /api/v1/private-route',
      );
      final service = _service(database, _ScriptedAdapter([(_) => _ok('{}')]));

      final issues = await service.loadBlockedIssues();

      expect(issues, hasLength(1));
      expect(issues.single.entityLabel, 'مهمة');
      expect(issues.single.operationLabel, 'إضافة');
      expect(issues.single.message, contains('رفض الخادم التغيير'));
      expect(issues.single.message, isNot(contains('title should')));
      expect(issues.single.message, isNot(contains('/api/')));
      expect(issues.single.canRetry, isTrue);
    },
  );

  test(
    'blocked sync details name every queued recovery operation safely',
    () async {
      final database = await _freshDb();
      final fixtures = <({String entityType, String operation, String id})>[
        (entityType: 'task', operation: 'assign', id: 'task-1'),
        (entityType: 'cost', operation: 'cancel', id: 'cost-1'),
        (entityType: 'cost_payment', operation: 'reverse', id: 'payment-1'),
        (entityType: 'money_budget', operation: 'replace', id: 'budget-1'),
      ];
      for (final fixture in fixtures) {
        final item = await database.enqueueSync(
          entityType: fixture.entityType,
          operation: fixture.operation,
          endpoint: '/safe-test/${fixture.id}',
          method: 'PATCH',
          payload: const {},
          planId: 'plan-1',
          localEntityId: fixture.id,
        );
        await database.markSyncItemBlocked(item.id, 'private backend detail');
      }
      final service = _service(database, _ScriptedAdapter([(_) => _ok('{}')]));

      final issues = await service.loadBlockedIssues();

      expect(
        {for (final issue in issues) issue.entityLabel: issue.operationLabel},
        {
          'مهمة': 'إسناد',
          'التكلفة': 'إلغاء',
          'الدفعة': 'عكس دفعة',
          'الميزانية': 'استبدال',
        },
      );
      expect(
        issues.every((issue) => !issue.message.contains('private backend')),
        isTrue,
      );
    },
  );

  test('manual recovery requeues blocked work and syncs it once', () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة مصححة'},
      planId: 'plan-1',
      localEntityId: 'local-task-1',
    );
    final adapter = _ScriptedAdapter([
      (_) => _status(400, '{"message":"invalid task"}'),
      (_) => _ok('{"id":"remote-task-1"}'),
    ]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');
    await service.syncPendingChanges();
    expect(service.blockedCount, 1);

    await service.retryBlockedChanges();

    expect(adapter.received, hasLength(2));
    expect(service.blockedCount, 0);
    expect(service.pendingCount, 0);
    expect(service.state, SyncState.synced);
  });

  test(
    'a network failure keeps the item retryable and stops the loop',
    () async {
      final database = await _freshDb();
      await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/wedding-plans/plan-1/tasks-a',
        method: 'POST',
        payload: {'title': 'أ'},
        planId: 'plan-1',
      );
      await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/wedding-plans/plan-1/tasks-b',
        method: 'POST',
        payload: {'title': 'ب'},
        planId: 'plan-1',
      );
      // First item hits a connection error; loop must break before item two.
      final adapter = _ScriptedAdapter([
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'no network',
        ),
      ]);
      final service = _service(database, adapter);
      await service.ensureCacheOwner('user-A');

      await service.syncPendingChanges();

      // Only one request attempted; both items still pending (retryable).
      expect(adapter.received.length, 1);
      expect(await database.pendingSyncCount(), 2);
      expect(service.state, SyncState.offline);
    },
  );

  // RA-MO-29: «not now» is not «no». A 408 or a 429 says nothing about the
  // change, and neither does a 401 the session refresh could not cure (a
  // weak network, or a 429 on the refresh itself). The change keeps waiting,
  // the loop stops as for a network failure, and no retry budget is spent.
  for (final code in [408, 429]) {
    test('a $code keeps every change waiting and stops the loop', () async {
      final database = await _freshDb();
      for (final title in ['أ', 'ب']) {
        await database.enqueueSync(
          entityType: 'task',
          operation: 'create',
          endpoint: '/wedding-plans/plan-1/tasks',
          method: 'POST',
          payload: {'title': title},
          planId: 'plan-1',
        );
      }
      final adapter = _ScriptedAdapter([
        (_) => _status(code, '{"statusCode":$code,"message":"later"}'),
      ]);
      final service = _service(database, adapter);
      await service.ensureCacheOwner('user-A');

      await service.syncPendingChanges();

      expect(adapter.received, hasLength(1), reason: 'stops at the first');
      expect(await database.pendingSyncCount(), 2);
      expect(service.blockedCount, 0);
      // As after a 5xx: waiting to be sent, never «the server refused».
      expect(service.state, SyncState.hasPendingChanges);
    });
  }

  test('a 401 the refresh could not cure keeps the change waiting', () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
      planId: 'plan-1',
    );
    final adapter = _ScriptedAdapter([
      (_) => _status(401, '{"statusCode":401,"message":"Unauthorized"}'),
    ]);
    final apiClient = ApiClient(tokenProvider: () async => 'expired');
    apiClient.dio.httpClientAdapter = adapter;
    var refreshes = 0;
    // The refresh fails the way a weak network fails it.
    apiClient.refreshSession = () async {
      refreshes++;
      throw Exception('refresh timed out');
    };
    final service = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(refreshes, 1);
    expect(await database.pendingSyncCount(), 1);
    expect(service.blockedCount, 0);
  });

  test('a 429 spends no retry budget, even at its edge', () async {
    final database = await _freshDb();
    final item = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
      planId: 'plan-1',
    );
    for (var i = 0; i < SyncQueueItem.maxAutoRetries - 1; i++) {
      await database.markSyncItemFailed(item.id, 'boom');
    }
    final adapter = _ScriptedAdapter([
      (_) => _status(429, '{"statusCode":429,"message":"later"}'),
    ]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(await database.pendingSyncCount(), 1);
    expect(service.blockedCount, 0);
  });

  test('an item blocks after exhausting its automatic retry budget', () async {
    final database = await _freshDb();
    final item = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
      planId: 'plan-1',
    );
    // Force the row to the edge of the retry budget, then fail with a 500
    // (retryable class) — the +1 crosses maxAutoRetries and blocks it.
    for (var i = 0; i < SyncQueueItem.maxAutoRetries - 1; i++) {
      await database.markSyncItemFailed(item.id, 'boom');
    }
    final adapter = _ScriptedAdapter([
      (_) => _status(500, '{"message":"server error"}'),
    ]);
    final service = _service(database, adapter);
    await service.ensureCacheOwner('user-A');

    await service.syncPendingChanges();

    expect(
      await database.pendingSyncCount(),
      0,
      reason: 'blocked, not pending',
    );
  });

  test(
    'ensureCacheOwner wipes the cache when a different user logs in',
    () async {
      final database = await _freshDb();
      await database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: {'id': 't1', 'title': 'سر المستخدم الأول'},
      );
      await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/x',
        method: 'POST',
        payload: {'title': 'قيد الانتظار'},
        planId: 'plan-1',
      );
      final adapter = _ScriptedAdapter([(_) => _ok('{}')]);
      final service = _service(database, adapter);

      await service.ensureCacheOwner('user-A');
      // Same user again: nothing is wiped.
      await service.ensureCacheOwner('user-A');
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedTasks,
          id: 't1',
        ),
        isNotNull,
      );
      expect(await database.pendingSyncCount(), 1);

      // A different account takes over the device.
      await service.ensureCacheOwner('user-B');

      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedTasks,
          id: 't1',
        ),
        isNull,
        reason: 'previous account data must never leak to the next user',
      );
      expect(await database.pendingSyncCount(), 0);
    },
  );

  test('ensureCacheOwner ignores empty and "null" user ids', () async {
    final database = await _freshDb();
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {'id': 't1', 'title': 'بيانات'},
    );
    final adapter = _ScriptedAdapter([(_) => _ok('{}')]);
    final service = _service(database, adapter);

    await service.ensureCacheOwner('user-A');
    await service.ensureCacheOwner('');
    await service.ensureCacheOwner('null');

    // Garbage ids never triggered a wipe.
    expect(
      await database.readCachedItem(table: OfflineTables.cachedTasks, id: 't1'),
      isNotNull,
    );
  });
}
