import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/sync_queue.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy queue migration accepts a trusted top-level plan id', () async {
    SharedPreferences.setMockInitialValues({
      _financeSchemaMarker: 2,
      _queueKey: jsonEncode([
        _legacyQueueRow(
          id: 'trusted-row',
          payload: {'weddingPlanId': 'plan-1', 'title': 'مهمة'},
        ),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);

    await database.initialize();

    final pending = await database.pendingSyncItems();
    expect(pending, hasLength(1));
    expect(pending.single.planId, 'plan-1');
    expect(await database.blockedSyncItems(), isEmpty);
    expect(preferences.getInt(_queueSchemaMarker), 7);
  });

  test(
    'legacy queue migration does not infer ownership from cache endpoint or nested json',
    () async {
      SharedPreferences.setMockInitialValues({
        _financeSchemaMarker: 2,
        _cachedTasksKey: jsonEncode([
          {
            'id': 'task-1',
            'planId': 'plan-secret',
            'rawJson': jsonEncode({
              'id': 'task-1',
              'weddingPlanId': 'plan-secret',
            }),
            'dirty': 1,
            'deletedLocally': 0,
            'updatedAt': DateTime.utc(2026).toIso8601String(),
          },
        ]),
        _queueKey: jsonEncode([
          _legacyQueueRow(
            id: 'ambiguous-row',
            endpoint: '/api/v1/wedding-plans/plan-secret/tasks/task-1',
            localEntityId: 'task-1',
            payload: {
              'data': {'weddingPlanId': 'plan-secret'},
            },
          ),
        ]),
      });
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);

      await database.initialize();

      expect(await database.pendingSyncItems(), isEmpty);
      final blocked = await database.blockedSyncItems();
      expect(blocked, hasLength(1));
      expect(blocked.single.planId, isNull);
      expect(blocked.single.lastError, unknownSyncQueuePlanOwnershipError);
      expect(await database.requeueBlockedSyncItems(), 0);
      expect(await database.blockedSyncItems(), hasLength(1));
    },
  );

  test('legacy queue migration rejects conflicting top-level ids', () async {
    SharedPreferences.setMockInitialValues({
      _financeSchemaMarker: 2,
      _queueKey: jsonEncode([
        _legacyQueueRow(
          id: 'conflicting-row',
          payload: {'planId': 'plan-1', 'weddingPlanId': 'plan-2'},
        ),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);

    await database.initialize();

    expect(await database.pendingSyncItems(), isEmpty);
    expect(
      (await database.blockedSyncItems()).single.lastError,
      unknownSyncQueuePlanOwnershipError,
    );
  });

  test('legacy account-scoped row with a plan id is quarantined', () async {
    SharedPreferences.setMockInitialValues({
      _financeSchemaMarker: 2,
      _queueKey: jsonEncode([
        _legacyQueueRow(
          id: 'invalid-scope-row',
          entityType: 'favorite_provider',
          planId: 'plan-1',
          payload: const {},
        ),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);

    await database.initialize();

    expect(await database.pendingSyncItems(), isEmpty);
    final blocked = (await database.blockedSyncItems()).single;
    expect(blocked.planId, isNull);
    expect(blocked.lastError, invalidSyncQueuePlanScopeError);
    expect(await database.requeueBlockedSyncItems(), 0);
  });

  test('sync fail-closes a corrupt plan-scoped row with no plan id', () async {
    SharedPreferences.setMockInitialValues({
      _financeSchemaMarker: 2,
      _queueSchemaMarker: 7,
      _queueKey: jsonEncode([
        _legacyQueueRow(
          id: 'corrupt-queued-row',
          payload: const {'title': 'لا ترسلني'},
        ),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final adapter = _RecordingAdapter();
    final apiClient = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = adapter;
    final service = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    await service.ensureCacheOwner('user-1');

    await service.syncPendingChanges();

    expect(adapter.requestCount, 0);
    expect(await database.pendingSyncItems(), isEmpty);
    final blocked = (await database.blockedSyncItems()).single;
    expect(blocked.lastError, unknownSyncQueuePlanOwnershipError);
    expect(await database.requeueBlockedSyncItems(), 0);
  });

  test(
    'sync fail-closes conflicting explicit and top-level payload plan ids',
    () async {
      SharedPreferences.setMockInitialValues({
        _financeSchemaMarker: 2,
        _queueSchemaMarker: 7,
        _queueKey: jsonEncode([
          _legacyQueueRow(
            id: 'conflicting-runtime-row',
            planId: 'plan-2',
            payload: const {'weddingPlanId': 'plan-1', 'title': 'لا ترسلني'},
          ),
        ]),
      });
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final adapter = _RecordingAdapter();
      final apiClient = ApiClient(tokenProvider: () async => 'token')
        ..dio.httpClientAdapter = adapter;
      final service = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      await service.ensureCacheOwner('user-1');

      await service.syncPendingChanges();

      expect(adapter.requestCount, 0);
      expect(await database.pendingSyncItems(), isEmpty);
      final blocked = (await database.blockedSyncItems()).single;
      expect(blocked.lastError, invalidSyncQueuePlanScopeError);
      expect(await database.requeueBlockedSyncItems(), 0);
    },
  );

  test('runtime ownership validation uses top-level ids only', () {
    expect(
      hasInvalidRuntimeSyncQueuePlanOwnership(
        planId: 'plan-1',
        payloadJson: jsonEncode({
          'planId': 'plan-1',
          'weddingPlanId': 'plan-1',
        }),
      ),
      isFalse,
    );
    expect(
      hasInvalidRuntimeSyncQueuePlanOwnership(
        planId: 'plan-2',
        payloadJson: jsonEncode({
          'nested': {'weddingPlanId': 'plan-1'},
        }),
      ),
      isFalse,
    );
    expect(
      hasInvalidRuntimeSyncQueuePlanOwnership(
        planId: 'plan-2',
        payloadJson: jsonEncode({'planId': 'plan-1'}),
      ),
      isTrue,
    );
    expect(
      hasInvalidRuntimeSyncQueuePlanOwnership(
        planId: 'plan-1',
        payloadJson: jsonEncode({'weddingPlanId': 1}),
      ),
      isTrue,
    );
    expect(
      hasInvalidRuntimeSyncQueuePlanOwnership(
        planId: 'plan-1',
        payloadJson: '{invalid-json',
      ),
      isTrue,
    );
  });

  test('enqueue requires explicit ownership matching entity scope', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();

    await expectLater(
      database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/plan-1/tasks',
        method: 'POST',
        payload: const {'title': 'مهمة'},
        planId: null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      database.enqueueSync(
        entityType: 'favorite_provider',
        operation: 'create',
        endpoint: '/api/v1/providers/provider-1/favorite',
        method: 'POST',
        payload: const {},
        planId: 'plan-1',
      ),
      throwsArgumentError,
    );

    final accountScoped = await database.enqueueSync(
      entityType: 'favorite_provider',
      operation: 'create',
      endpoint: '/api/v1/providers/provider-1/favorite',
      method: 'POST',
      payload: const {},
      planId: null,
    );
    expect(accountScoped.planId, isNull);
  });

  test('queue coalescing never crosses an explicit plan boundary', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();

    Future<void> enqueue(String planId, String title) async {
      await database.enqueueSync(
        entityType: 'task',
        operation: 'update',
        endpoint: '/api/v1/tasks/shared-local-id',
        method: 'PATCH',
        payload: {'title': title},
        planId: planId,
        localEntityId: 'shared-local-id',
        replacePendingForEntity: true,
      );
    }

    await enqueue('plan-1', 'الأولى');
    await enqueue('plan-2', 'الثانية');
    await enqueue('plan-1', 'الأحدث للأولى');

    final pending = await database.pendingSyncItems();
    expect(pending, hasLength(2));
    expect(
      pending.singleWhere((item) => item.planId == 'plan-1').payload['title'],
      'الأحدث للأولى',
    );
    expect(
      pending.singleWhere((item) => item.planId == 'plan-2').payload['title'],
      'الثانية',
    );
  });

  test('SQLite queue schema v7 uses payload-only ownership migration', () {
    final source = File(
      'lib/core/offline/local_database_mobile.dart',
    ).readAsStringSync();

    expect(source, contains('static const _databaseVersion = 7;'));
    expect(source, contains('planId TEXT,'));
    expect(source, contains('sync_queue_plan_id_idx'));
    expect(source, contains("trustedLegacyQueuePlanId(row['payloadJson'])"));
    expect(source, isNot(contains('SET planId = localEntityId')));
    expect(source, isNot(contains('SELECT planId FROM')));
    expect(source, isNot(contains('payloadJson LIKE')));
  });
}

const _financeSchemaMarker = 'aarast_offline:finance_schema_version';
const _queueSchemaMarker = 'aarast_offline:queue_schema_version';
const _queueKey = 'aarast_offline:sync_queue';
const _cachedTasksKey = 'aarast_offline:cached_tasks';

Map<String, Object?> _legacyQueueRow({
  required String id,
  required Map<String, Object?> payload,
  String entityType = 'task',
  String endpoint = '/api/v1/tasks/task-1',
  String? localEntityId = 'task-1',
  String? planId,
}) {
  final createdAt = DateTime.utc(2026).toIso8601String();
  final row = <String, Object?>{
    'id': id,
    'entityType': entityType,
    'operation': 'update',
    'endpoint': endpoint,
    'method': 'PATCH',
    'payloadJson': jsonEncode(payload),
    'status': SyncQueueItem.queued,
    'retryCount': 0,
    'localEntityId': localEntityId,
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };
  if (planId != null) row['planId'] = planId;
  return row;
}

class _RecordingAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
