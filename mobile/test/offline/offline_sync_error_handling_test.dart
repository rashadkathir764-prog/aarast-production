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
      localEntityId: 'local-1',
    );
    final adapter = _ScriptedAdapter([(_) => _ok('{"id":"remote-1"}')]);
    final service = _service(database, adapter);

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
    );
    final adapter = _ScriptedAdapter([(_) => _ok('{"id":"remote-1"}')]);
    final service = _service(database, adapter);

    await service.syncPendingChanges();

    expect(
      adapter.received.single.headers['X-Client-Request-Id'],
      item.id,
    );
  });

  test('a 400 rejection blocks the item immediately (no retry spin)', () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': ''},
    );
    final adapter = _ScriptedAdapter([
      (_) => _status(400, '{"message":"title should not be empty"}'),
    ]);
    final service = _service(database, adapter);

    await service.syncPendingChanges();

    // Blocked items are excluded from the pending queue: they never replay.
    expect(await database.pendingSyncCount(), 0);
    final rows = await database.pendingSyncItems();
    expect(rows, isEmpty);
    expect(service.state, SyncState.syncError);
  });

  test('a network failure keeps the item retryable and stops the loop',
      () async {
    final database = await _freshDb();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks-a',
      method: 'POST',
      payload: {'title': 'أ'},
    );
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks-b',
      method: 'POST',
      payload: {'title': 'ب'},
    );
    // First item hits a connection error; loop must break before item two.
    final adapter = _ScriptedAdapter([
      (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'no network',
          ),
    ]);
    final service = _service(database, adapter);

    await service.syncPendingChanges();

    // Only one request attempted; both items still pending (retryable).
    expect(adapter.received.length, 1);
    expect(await database.pendingSyncCount(), 2);
    expect(service.state, SyncState.offline);
  });

  test('an item blocks after exhausting its automatic retry budget',
      () async {
    final database = await _freshDb();
    final item = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'مهمة'},
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

    await service.syncPendingChanges();

    expect(await database.pendingSyncCount(), 0, reason: 'blocked, not pending');
  });

  test('ensureCacheOwner wipes the cache when a different user logs in',
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
  });

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
      await database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: 't1',
      ),
      isNotNull,
    );
  });
}
