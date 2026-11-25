import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-344 (the rest): a delete of a guest, a task, a cost or a payment
// date made from an older read went through over what the partner changed
// meanwhile. As the edit, it carries what the phone last read of the row
// (`expected`, the fields the server checks), the server refuses it with 409
// CHANGED_ELSEWHERE when one changed since, and the phone says so and reads
// the row again, as it does for an edit.

const _read = '2026-11-24T10:00:00.000Z';
const _changed = '2026-11-24T11:00:00.000Z';

/// Answers `METHOD path` from [routes] (a body, or a status and body).
class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, (int, Object?)> routes;
  bool down = false;

  /// `METHOD path` → every body sent to it, in order.
  final bodies = <String, List<Map<String, dynamic>>>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = '${options.method} ${options.path}';
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        ),
      );
    }
    if (options.method != 'GET') {
      final data = options.data;
      (bodies[call] ??= []).add(
        data is Map ? Map<String, dynamic>.from(data) : const {},
      );
    }
    final (status, body) = routes[call] ?? (404, {'message': 'not found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiClient, OfflineSyncService, _Server)> _setUp(
  Map<String, (int, Object?)> routes,
) async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
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
  await offline.ensureCacheOwner('u1');
  return (api, offline, server);
}

Map<String, dynamic> _guest(String name, String updatedAt) => {
  'id': 'g1',
  'weddingPlanId': 'p1',
  'name': name,
  'side': 'OTHER',
  'status': 'INVITED',
  'seatsCount': 1,
  'createdAt': _read,
  'updatedAt': updatedAt,
};

const _conflict = (
  409,
  {
    'statusCode': 409,
    'code': 'CHANGED_ELSEWHERE',
    'message': 'الضيف تغيّر من جهاز ثاني قبل الحذف، فما انحذف.',
  },
);

const _deleted = (200, {'deleted': true});

Map<String, dynamic> _task(String status) => {
  'id': 't1',
  'weddingPlanId': 'p1',
  'title': 'حجز القاعة',
  'status': status,
  'priority': 'MEDIUM',
  'updatedAt': _read,
};

Map<String, dynamic> _cost(String title) => {
  'id': 'c1',
  'weddingPlanId': 'p1',
  'budgetCategoryId': 'b1',
  'title': title,
  'totalAmount': '500000',
  'paidAmount': '0',
  'status': 'OPEN',
  'updatedAt': _read,
};

Map<String, dynamic> _schedule(String amount) => {
  'id': 's1',
  'weddingPlanId': 'p1',
  'weddingCostId': 'c1',
  'amount': amount,
  'dueDate': '2027-01-10',
  'status': 'PENDING',
  'updatedAt': _read,
};

void main() {
  test('a guest\'s delete carries what the phone read of the guest', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/guests/g1': _deleted,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خالد', _read),
    );

    await GuestsApi(api, offline: offline).deleteGuest('g1');

    expect(server.bodies['DELETE /api/v1/guests/g1']!.single['expected'], {
      'name': 'خالد',
      'side': 'OTHER',
      'status': 'INVITED',
      'seatsCount': 1,
    });
  });

  test('a guest deleted without a net waits with what it read; refused, it '
      'waits for the person with the reason and is not retried', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/guests/g1': _conflict,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خلد', _read),
    );
    server.down = true;
    await GuestsApi(api, offline: offline).deleteGuest('g1');

    final waiting = (await offline.database.pendingSyncItems()).single;
    expect(waiting.operation, 'delete');
    expect((waiting.payload['expected'] as Map)['name'], 'خلد');

    server.down = false;
    await offline.syncPendingChanges();
    await offline.retryBlockedChanges();

    expect(server.bodies['DELETE /api/v1/guests/g1'], hasLength(1));
    final refused = (await offline.loadPendingChanges()).single;
    expect(refused.blocked, isTrue);
    expect(refused.changedElsewhere, isTrue);
    expect(refused.reason, contains('الضيف تغيّر من جهاز ثاني'));
  });

  test('a guest deleted while its own edit waits goes without: the edit '
      'lands first and would refuse it', () async {
    final (api, offline, server) = await _setUp({});
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خلد', _read),
    );
    final guests = GuestsApi(api, offline: offline);
    server.down = true;
    await guests.updateGuest(id: 'g1', name: 'خالد');
    await guests.deleteGuest('g1');

    final waiting = await offline.database.pendingSyncItems();
    expect(waiting.map((item) => item.operation), ['update', 'delete']);
    expect(waiting.first.payload['expected'], {'name': 'خلد'});
    expect(waiting.last.payload.containsKey('expected'), isFalse);
  });

  test(
    'a task edited and then deleted without a net: the delete takes the '
    'edit\'s place and deletes from the read the edit was made from',
    () async {
      final (api, offline, server) = await _setUp({});
      await offline.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: _task('TODO'),
      );
      final tasks = TaskTimelineApi(api, offline: offline);
      server.down = true;
      await tasks.updateTask('t1', {'status': 'DONE'});
      await tasks.deleteTask('t1');

      final waiting = await offline.database.pendingSyncItems();
      expect(waiting.map((item) => item.operation), ['delete']);
      expect(waiting.single.payload['expected'], {'status': 'TODO'});
    },
  );

  test('a refused guest delete reads the guest again and says why', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/guests/g1': _conflict,
      'GET /api/v1/wedding-plans/p1/guests': (200, [_guest('خالد', _read)]),
      'GET /api/v1/wedding-plans/p1/guest-groups': (200, const []),
      'GET /api/v1/wedding-plans/p1/guests/summary': (
        200,
        {'weddingPlanId': 'p1', 'total': 1},
      ),
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خالد', _read),
    );
    final provider = GuestsProvider(GuestsApi(api, offline: offline));
    await provider.loadGuests('p1');
    server.routes['GET /api/v1/wedding-plans/p1/guests'] = (
      200,
      [_guest('خالد الحمدي', _changed)],
    );

    final deleted = await provider.deleteGuest(provider.guests.single);

    expect(deleted, isFalse);
    expect(provider.guests.single.name, 'خالد الحمدي');
    expect(provider.errorMessage, contains('الضيف تغيّر من جهاز ثاني'));
    expect(provider.errorMessage, contains('فما انحذف'));
  });

  test('a task\'s delete carries what the phone read of the task', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/tasks/t1': _deleted,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: _task('TODO'),
    );

    await TaskTimelineApi(api, offline: offline).deleteTask('t1');

    expect(server.bodies['DELETE /api/v1/tasks/t1']!.single['expected'], {
      'title': 'حجز القاعة',
      'status': 'TODO',
      'priority': 'MEDIUM',
    });
  });

  test('a task deleted without a net waits with what it read', () async {
    final (api, offline, server) = await _setUp({});
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: _task('TODO'),
    );
    server.down = true;

    await TaskTimelineApi(api, offline: offline).deleteTask('t1');

    final waiting = (await offline.database.pendingSyncItems()).single;
    expect(waiting.operation, 'delete');
    expect((waiting.payload['expected'] as Map)['status'], 'TODO');
  });

  test('a cost\'s delete carries what the phone read of the cost', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/costs/c1': _deleted,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: _cost('القاعة'),
    );

    await FinanceApi(
      api,
      offline: offline,
    ).deleteCost(WeddingCost.fromJson(_cost('القاعة')));

    expect(server.bodies['DELETE /api/v1/costs/c1']!.single['expected'], {
      'budgetCategoryId': 'b1',
      'title': 'القاعة',
      'totalAmount': '500000',
    });
  });

  test('a payment date\'s delete carries what the phone read of it', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/payment-schedules/s1': _deleted,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedPaymentSchedules,
      json: _schedule('100000'),
    );

    await FinanceApi(
      api,
      offline: offline,
    ).deleteSchedule(PaymentSchedule.fromJson(_schedule('100000')));

    expect(
      server.bodies['DELETE /api/v1/payment-schedules/s1']!.single['expected'],
      {'amount': '100000', 'dueDate': '2027-01-10'},
    );
  });

  test('a cost deleted while its own edit waits goes without: the edit '
      'lands first and would refuse it', () async {
    final (api, offline, server) = await _setUp({});
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: _cost('القاعة'),
    );
    final finance = FinanceApi(api, offline: offline);
    final cost = WeddingCost.fromJson(_cost('القاعة'));
    server.down = true;
    await finance.updateCost(
      cost: cost,
      budgetCategoryId: 'b1',
      title: 'قاعة الأفراح',
      totalAmount: '500000',
    );

    await finance.deleteCost(cost);

    final waiting = await offline.database.pendingSyncItems();
    final delete = waiting.singleWhere((item) => item.operation == 'delete');
    expect(delete.payload.containsKey('expected'), isFalse);
  });

  test('a refused task delete keeps the task, reads again, and says it was '
      'the delete', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/tasks/t1': (
        409,
        {
          'statusCode': 409,
          'code': 'CHANGED_ELSEWHERE',
          'message': 'المهمة تغيّرت من جهاز ثاني قبل الحذف، فما انحذفت.',
        },
      ),
      'GET /api/v1/wedding-plans/p1/tasks': (200, [_task('DONE')]),
      'GET /api/v1/wedding-plans/p1/timeline': (200, {'tasks': []}),
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: _task('TODO'),
    );
    final provider = TaskTimelineProvider(
      TaskTimelineApi(api, offline: offline),
    );

    final deleted = await provider.deleteTask('p1', 't1');

    expect(deleted, isFalse);
    expect(provider.errorMessage, contains('قبل الحذف'));
    expect(provider.errorMessage, contains('فما انحذف'));
    expect(server.bodies['DELETE /api/v1/tasks/t1'], hasLength(1));
  });

  test('a delete of a row the phone never read sends no read', () async {
    final (api, offline, server) = await _setUp({
      'DELETE /api/v1/guests/g9': _deleted,
    });

    await GuestsApi(api, offline: offline).deleteGuest('g9');

    expect(server.bodies['DELETE /api/v1/guests/g9']!.single, isEmpty);
  });
}
