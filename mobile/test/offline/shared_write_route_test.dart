import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-341: a task and a plan were sent under one request id and, when the
// answer was lost, queued under another: the server had no way to tell the
// resend from a new request, and made the task (or the plan) twice. A 5xx
// was not kept at all. Every write path goes through the shared route
// (`OfflineWrites.send`): one request id from the first try to the resend.

/// The server does the write; while [losesAnswers] its answer is lost, and
/// while [failsWith] it answers that status instead.
class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, Object?> routes;
  bool losesAnswers = false;
  int? failsWith;

  /// `METHOD path` → the request id of every try, in order.
  final writes = <String, List<String>>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = '${options.method} ${options.path}';
    if (options.method != 'GET') {
      (writes[call] ??= []).add(
        '${options.headers[ApiClient.clientRequestIdHeader]}',
      );
    }
    if (losesAnswers) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    final status = failsWith;
    if (status != null) {
      return ResponseBody.fromString(
        '{"message":"bad gateway"}',
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(routes[call] ?? const {}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiClient, OfflineSyncService, _Server, ServerReachability)> _setUp(
  Map<String, Object?> routes,
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
  return (api, offline, server, reachability);
}

void main() {
  test('a task whose answer was lost is resent under the same request '
      'id', () async {
    final (api, offline, server, reachability) = await _setUp({
      'POST /api/v1/wedding-plans/p1/tasks': {
        'id': 't-server',
        'weddingPlanId': 'p1',
        'title': 'حجز القاعة',
        'status': 'TODO',
        'priority': 'MEDIUM',
      },
    });
    server.losesAnswers = true;

    final task = await TaskTimelineApi(
      api,
      offline: offline,
    ).createTask(weddingPlanId: 'p1', title: 'حجز القاعة');
    expect(task.id, isNot('t-server'), reason: 'kept on the phone meanwhile');

    server.losesAnswers = false;
    reachability.noteReached();
    await offline.syncPendingChanges();

    final tries = server.writes['POST /api/v1/wedding-plans/p1/tasks']!;
    expect(tries, hasLength(2));
    expect(tries.last, tries.first, reason: 'the resend is the same request');
    expect(await offline.database.pendingSyncCount(), 0);
  });

  // RA-MO-342 for tasks: their list was read past the shared route, so a
  // task changed on the phone showed the server's old one when it answered.
  test(
    'a task changed on the phone stays changed when the list is read',
    () async {
      final (api, offline, server, reachability) = await _setUp({
        'GET /api/v1/wedding-plans/p1/tasks': [
          {
            'id': 't1',
            'weddingPlanId': 'p1',
            'title': 'حجز القاعة',
            'status': 'TODO',
            'priority': 'MEDIUM',
          },
        ],
      });
      final tasks = TaskTimelineApi(api, offline: offline);
      await tasks.getTasks('p1');
      reachability.noteFailure(
        ReachabilityFailure(
          cause: ReachabilityCause.noNetwork,
          at: DateTime(2026, 11, 24),
        ),
      );
      await tasks.updateTask('t1', {'status': 'DONE'});
      expect(server.writes, isEmpty, reason: 'kept on the phone, no try');

      final listed = await tasks.getTasks('p1');

      expect(listed.single.status, 'DONE');
    },
  );

  test('a plan whose answer was lost is resent under the same request '
      'id', () async {
    final (api, offline, server, reachability) = await _setUp({
      'POST /api/v1/wedding-plans': {
        'id': 'p-server',
        'ownerUserId': 'u1',
        'title': 'عرسي',
        'currency': 'YER',
        'status': 'PLANNING',
        'createdAt': '2026-11-24T00:00:00.000Z',
        'updatedAt': '2026-11-24T00:00:00.000Z',
      },
    });
    server.losesAnswers = true;

    final plan = await WeddingPlansApi(
      api,
      offline: offline,
    ).createWeddingPlan(title: 'عرسي');
    expect(plan.id, isNot('p-server'));

    server.losesAnswers = false;
    reachability.noteReached();
    await offline.syncPendingChanges();

    final tries = server.writes['POST /api/v1/wedding-plans']!;
    expect(tries, hasLength(2));
    expect(tries.last, tries.first);
  });

  test('a change answered with a 5xx waits on the phone under its request '
      'id', () async {
    final (api, offline, server, _) = await _setUp({
      'POST /api/v1/wedding-plans/p1/guest-groups': {
        'id': 'g-server',
        'weddingPlanId': 'p1',
        'name': 'آل الحمدي',
      },
    });
    server.failsWith = 503;
    final localId = OfflineWrites.localId('guest-group');

    final row = await OfflineWrites(api, offline).queued(
      entityType: 'guest_group',
      operation: 'create',
      method: 'POST',
      endpoint: '/api/v1/wedding-plans/p1/guest-groups',
      payload: {'name': 'آل الحمدي'},
      table: OfflineTables.cachedGuestGroups,
      localJson: {'id': localId, 'weddingPlanId': 'p1', 'name': 'آل الحمدي'},
      planId: 'p1',
      localEntityId: localId,
    );
    expect(row['id'], localId);
    final waiting = (await offline.database.pendingSyncItems()).single;
    expect(
      waiting.id,
      server.writes['POST /api/v1/wedding-plans/p1/guest-groups']!.single,
    );

    server.failsWith = null;
    await offline.syncPendingChanges();
    expect(await offline.database.pendingSyncCount(), 0);
  });
}
