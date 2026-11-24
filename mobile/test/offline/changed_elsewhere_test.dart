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
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-344: no conflict was detected but the budget's. A guest, a task, a
// cost or a payment date edited on a phone without a net was sent later
// over what the partner (or the guest's own answer) changed meanwhile: the
// last writer won. Each edit now carries the version it was made from (the
// row's `updatedAt` as the server last gave it), the server refuses an edit
// of a row changed since (409 CHANGED_ELSEWHERE), and the phone says so as
// it does for the budget: it reads the row again and shows it.

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
    'message': 'الضيف تغيّر من جهاز ثاني. حدّث الشاشة وعدّل من جديد.',
  },
);

void main() {
  test('a guest\'s edit carries the version it was made from', () async {
    final (api, offline, server) = await _setUp({
      'PATCH /api/v1/guests/g1': (200, _guest('خالد', _changed)),
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خلد', _read),
    );

    await GuestsApi(api, offline: offline).updateGuest(id: 'g1', name: 'خالد');

    expect(
      server.bodies['PATCH /api/v1/guests/g1']!.single['expectedVersion'],
      _read,
    );
  });

  test('a guest edited twice without a net goes once, from the first '
      'read; refused, it waits for the person with the reason', () async {
    final (api, offline, server) = await _setUp({
      'PATCH /api/v1/guests/g1': _conflict,
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خلد', _read),
    );
    final guests = GuestsApi(api, offline: offline);
    server.down = true;
    await guests.updateGuest(id: 'g1', name: 'خالد');
    await guests.updateGuest(id: 'g1', notes: 'من جهة العريس');

    final waiting = (await offline.database.pendingSyncItems()).single;
    expect(waiting.payload['expectedVersion'], _read);
    expect(waiting.payload['name'], 'خالد');

    server.down = false;
    await offline.syncPendingChanges();

    expect(await offline.database.pendingSyncCount(), 0);
    final refused = (await offline.loadPendingChanges()).single;
    expect(refused.blocked, isTrue);
    expect(refused.reason, contains('الضيف تغيّر من جهاز ثاني'));
  });

  test('a refused edit reads the guest again and says why, as the '
      'budget', () async {
    final (api, offline, server) = await _setUp({
      'PATCH /api/v1/guests/g1': _conflict,
      'GET /api/v1/wedding-plans/p1/guests': (
        200,
        [_guest('خالد الحمدي', _changed)],
      ),
      'GET /api/v1/wedding-plans/p1/guest-groups': (200, const []),
      'GET /api/v1/wedding-plans/p1/guests/summary': (
        200,
        {'weddingPlanId': 'p1', 'total': 1},
      ),
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: _guest('خلد', _read),
    );
    final provider = GuestsProvider(GuestsApi(api, offline: offline));
    await provider.loadGuests('p1');
    // The partner renamed the guest after this phone read the list.
    server.routes['GET /api/v1/wedding-plans/p1/guests'] = (
      200,
      [_guest('خالد الحمدي', _changed)],
    );

    final saved = await provider.updateGuest(
      guest: provider.guests.single,
      name: 'خالد',
    );

    expect(saved, isFalse);
    expect(provider.guests.single.name, 'خالد الحمدي');
    expect(provider.errorMessage, contains('الضيف تغيّر من جهاز ثاني'));
    expect(provider.errorMessage, isNot(contains('مضاف')));
  });

  test('a task\'s edit carries the version it was made from', () async {
    final (api, offline, server) = await _setUp({
      'PATCH /api/v1/tasks/t1': (
        200,
        {
          'id': 't1',
          'weddingPlanId': 'p1',
          'title': 'حجز القاعة',
          'status': 'DONE',
          'priority': 'MEDIUM',
          'updatedAt': _changed,
        },
      ),
    });
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 't1',
        'weddingPlanId': 'p1',
        'title': 'حجز القاعة',
        'status': 'TODO',
        'priority': 'MEDIUM',
        'updatedAt': _read,
      },
    );

    await TaskTimelineApi(
      api,
      offline: offline,
    ).updateTask('t1', {'status': 'DONE'});

    expect(
      server.bodies['PATCH /api/v1/tasks/t1']!.single['expectedVersion'],
      _read,
    );
  });

  test('a cost\'s edit carries its version; one made while another waits '
      'goes without, so it is not refused for the first one\'s '
      'landing', () async {
    final (api, offline, server) = await _setUp({});
    final row = {
      'id': 'c1',
      'weddingPlanId': 'p1',
      'budgetCategoryId': 'b1',
      'title': 'القاعة',
      'totalAmount': '500000',
      'paidAmount': '0',
      'status': 'OPEN',
      'updatedAt': _read,
    };
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: row,
    );
    final finance = FinanceApi(api, offline: offline);
    final cost = WeddingCost.fromJson(row);
    server.down = true;

    await finance.updateCost(
      cost: cost,
      budgetCategoryId: 'b1',
      title: 'قاعة الأفراح',
      totalAmount: '500000',
    );
    await finance.updateCost(
      cost: cost,
      budgetCategoryId: 'b1',
      title: 'قاعة الأفراح',
      totalAmount: '600000',
    );

    final waiting = (await offline.database.pendingSyncItems())
        .where((item) => item.entityType == 'cost')
        .toList();
    expect(waiting, hasLength(2));
    expect(waiting.first.payload['expectedVersion'], _read);
    expect(waiting.last.payload.containsKey('expectedVersion'), isFalse);
  });
}
