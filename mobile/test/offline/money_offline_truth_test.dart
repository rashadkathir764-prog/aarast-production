import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D86: money kept on the phone is never lost to a context switch, a parent
// that failed never gets its child refused, a refused change can be
// discarded, and the money picture without the server is the server's last
// answer, never a sum the phone made up.

class _Server implements HttpClientAdapter {
  _Server(this.routes);

  /// `METHOD path` → status code and body.
  final Map<String, (int, Object?)> routes;
  bool down = false;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.uri.path}';
    calls.add(key);
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
    }
    final (status, body) = routes[key] ?? (404, {'message': 'not found'});
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(JsonLocalDatabase, OfflineSyncService, ApiClient, _Server)> _setUp(
  Map<String, (int, Object?)> routes,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final reachability = ServerReachability();
  final api = ApiClient(
    tokenProvider: () async => 'token',
    reachability: reachability,
  );
  final server = _Server(routes);
  api.dio.httpClientAdapter = server;
  final offline = OfflineSyncService(
    database: database,
    apiClient: api,
    reachability: reachability,
  );
  await offline.refreshStatus();
  await offline.ensureCacheOwner('u1');
  return (database, offline, api, server);
}

Future<void> _queuePayment(JsonLocalDatabase database) async {
  await database.saveCachedItem(
    table: OfflineTables.cachedCostPayments,
    json: {
      'id': 'local-payment-1',
      'costId': 'cost-1',
      'weddingPlanId': 'plan-a',
      'amount': '1000',
      'entryType': 'PAYMENT',
      'paidAt': '2026-11-01T00:00:00.000Z',
    },
    dirty: true,
  );
  await database.enqueueSync(
    entityType: 'cost_payment',
    operation: 'create',
    endpoint: '/api/v1/costs/cost-1/payments',
    method: 'POST',
    payload: {'amount': '1000'},
    planId: 'plan-a',
    localEntityId: 'local-payment-1',
  );
}

void main() {
  test(
    'switching to another plan keeps the first plan\'s queued money',
    () async {
      final (database, offline, _, _) = await _setUp({});
      await _queuePayment(database);
      expect(await database.pendingSyncCount(), 1);

      await offline.switchPlanContext('plan-a');

      expect(await database.pendingSyncCount(), 1);
      final rows = await database.readCachedList(
        table: OfflineTables.cachedCostPayments,
        parentColumn: 'planId',
        parentId: 'plan-a',
      );
      expect(rows.single['id'], 'local-payment-1');
    },
  );

  test(
    'a child waits while its parent is refused, and is sent after it',
    () async {
      final (database, offline, _, server) = await _setUp({
        'POST /api/v1/wedding-plans/plan-a/costs': (500, {'message': 'boom'}),
        'POST /api/v1/costs/local-cost-1/payments': (404, {'message': 'no'}),
      });
      await database.enqueueSync(
        entityType: 'cost',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/plan-a/costs',
        method: 'POST',
        payload: {'title': 'القاعة'},
        planId: 'plan-a',
        localEntityId: 'local-cost-1',
      );
      await database.enqueueSync(
        entityType: 'cost_payment',
        operation: 'create',
        endpoint: '/api/v1/costs/local-cost-1/payments',
        method: 'POST',
        payload: {'amount': '1000'},
        planId: 'plan-a',
        localEntityId: 'local-payment-1',
      );

      await offline.syncPendingChanges();

      // The payment was never sent with its parent's local id.
      expect(server.calls, ['POST /api/v1/wedding-plans/plan-a/costs']);
      expect(await database.blockedSyncItems(), isEmpty);
      expect(await database.pendingSyncCount(), 2);

      // The server accepts the cost: the payment follows under the real id.
      server.routes['POST /api/v1/wedding-plans/plan-a/costs'] = (
        201,
        {'id': 'cost-9', 'weddingPlanId': 'plan-a', 'title': 'القاعة'},
      );
      server.routes['POST /api/v1/costs/cost-9/payments'] = (
        201,
        {'id': 'pay-9', 'costId': 'cost-9', 'weddingPlanId': 'plan-a'},
      );
      await offline.syncPendingChanges();
      expect(server.calls.last, 'POST /api/v1/costs/cost-9/payments');
      expect(await database.pendingSyncCount(), 0);
    },
  );

  test('a refused change can be discarded with its row', () async {
    final (database, offline, _, _) = await _setUp({
      'POST /api/v1/costs/cost-1/payments': (400, {'message': 'bad'}),
    });
    await _queuePayment(database);
    await offline.syncPendingChanges();
    final blocked = await database.blockedSyncItems();
    expect(blocked, hasLength(1));
    final changes = await offline.loadPendingChanges();
    expect(changes.single.blocked, isTrue);

    await offline.discardBlockedChange(changes.single.id);

    expect(await database.blockedSyncItems(), isEmpty);
    expect(await offline.loadPendingChanges(), isEmpty);
    final rows = await database.readCachedList(
      table: OfflineTables.cachedCostPayments,
      parentColumn: 'planId',
      parentId: 'plan-a',
    );
    expect(rows, isEmpty);
  });

  test(
    'the money picture without the server is the server\'s last answer',
    () async {
      final summary = {
        'weddingPlanId': 'plan-a',
        'currency': 'YER',
        'budget': {'total': '5000000', 'confirmedCost': '3000000'},
        'costs': {
          'total': '3000000',
          'paid': '1000000',
          'remaining': '2000000',
        },
      };
      final (database, offline, api, server) = await _setUp({
        'GET /api/v1/wedding-plans/plan-a/money-summary': (200, summary),
      });
      final finance = FinanceApi(api, offline: offline);

      final online = await finance.getMoneySummary('plan-a');
      expect(online.costs.total, '3000000');

      // A payment kept on the phone does not change the server's numbers.
      await _queuePayment(database);
      server.down = true;
      final cached = await finance.cachedMoneySummary('plan-a');
      expect(cached?.costs.paid, '1000000');
      final offlineRead = await finance.getMoneySummary('plan-a');
      expect(offlineRead.costs.paid, '1000000');
      expect(await finance.pendingMoneyChangeCount('plan-a'), 1);
    },
  );

  test(
    'due schedules do not erase the other schedules kept on the phone',
    () async {
      final (database, offline, api, _) = await _setUp({
        'GET /api/v1/wedding-plans/plan-a/payment-schedules/due': (
          200,
          [
            {
              'id': 's-due',
              'costId': 'cost-1',
              'weddingPlanId': 'plan-a',
              'status': 'PENDING',
              'amount': '1',
              'dueDate': '2026-11-10',
            },
          ],
        ),
      });
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 's-far',
          'costId': 'cost-1',
          'weddingPlanId': 'plan-a',
          'status': 'PENDING',
          'amount': '2',
          'dueDate': '2027-03-01',
        },
      );

      await FinanceApi(api, offline: offline).getDuePaymentSchedules('plan-a');

      final rows = await database.readCachedList(
        table: OfflineTables.cachedPaymentSchedules,
        parentColumn: 'planId',
        parentId: 'plan-a',
      );
      expect(rows.map((r) => r['id']).toSet(), {'s-due', 's-far'});
    },
  );
}
