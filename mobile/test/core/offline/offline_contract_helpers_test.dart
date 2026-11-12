import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/cached_first_load.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D85: the one read/write contract, on the JSON database with a fake server.

/// Answers from a map of path → JSON, or fails in transport when [down].
class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, Object?> routes;
  bool down = false;
  final calls = <String>[];

  /// The `X-Client-Request-Id` of every write, in order: the key the server
  /// tells a resend from a new request by.
  final writeRequestIds = <String>[];

  /// The server does the write, then the answer is lost on the way back.
  bool losesAnswers = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    if (options.method != 'GET' && !down) {
      writeRequestIds.add(
        '${options.headers[ApiClient.clientRequestIdHeader]}',
      );
    }
    if (losesAnswers) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
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
    final body = routes['${options.method} ${options.path}'];
    if (body == null) {
      return ResponseBody.fromString(
        '{"message":"not found"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('OfflineReads.list', () {
    test(
      'keeps the answer on the phone and serves it when the server is down',
      () async {
        final (api, offline, server, _) = await _setUpSimple({
          'GET /api/v1/wedding-plans/p1/funding-sources': [
            {'id': 'f1', 'weddingPlanId': 'p1', 'kind': 'SALARY'},
          ],
        });
        final reads = OfflineReads(api, offline);

        final first = await reads.list(
          '/api/v1/wedding-plans/p1/funding-sources',
          table: OfflineTables.cachedFundingSources,
          parentColumn: 'planId',
          parentId: 'p1',
        );
        expect(first.single['id'], 'f1');

        server.down = true;
        final served = OfflineReads.copiesServed;
        final again = await reads.list(
          '/api/v1/wedding-plans/p1/funding-sources',
          table: OfflineTables.cachedFundingSources,
          parentColumn: 'planId',
          parentId: 'p1',
        );
        expect(again.single['id'], 'f1');
        // D87: a copy served is counted, so a screen can say it is old.
        expect(OfflineReads.copiesServed, served + 1);
        // The failure is measured, not swallowed (D84).
        expect(offline.state, SyncState.offline);
      },
    );

    test('with no copy on the phone the failure is reported', () async {
      final (api, offline, server, _) = await _setUpSimple({});
      server.down = true;
      final reads = OfflineReads(api, offline);
      await expectLater(
        reads.list(
          '/api/v1/wedding-plans/p1/funding-sources',
          table: OfflineTables.cachedFundingSources,
          parentColumn: 'planId',
          parentId: 'p1',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('a blob keeps a whole payload under its key', () async {
      final (api, offline, server, _) = await _setUpSimple({
        'GET /api/v1/wedding-plans/p1/events': {
          'items': [
            {'id': 'e1'},
          ],
          'canEdit': true,
        },
      });
      final reads = OfflineReads(api, offline);
      await reads.blob('/api/v1/wedding-plans/p1/events', metaKey: 'events:p1');
      server.down = true;
      final cached = await reads.blob(
        '/api/v1/wedding-plans/p1/events',
        metaKey: 'events:p1',
      );
      expect(cached['canEdit'], isTrue);
      expect(await reads.cachedBlob('events:p1'), isNotNull);
    });
  });

  group('loan repayments while the server is out of reach', () {
    Map<String, dynamic> loan({String id = 'f1', List<Object> repayments = const []}) => {
      'id': id,
      'weddingPlanId': 'p1',
      'kind': 'LOAN',
      'sourceName': 'خالي',
      'amount': '1000000',
      'status': 'RECEIVED',
      'repayments': repayments,
    };
    const planned = {
      'id': 'r1',
      'fundingSourceId': 'f1',
      'amount': '300000',
      'status': 'PLANNED',
    };

    // RA-MO-87: it was written on the phone's copy alone, looked saved, and
    // the loan's answer wiped it.
    test('a repayment of a loan the server has not named yet is refused '
        'with its reason, and nothing is written', () async {
      final (api, offline, server, _) = await _setUpSimple({});
      server.down = true;
      final funding = FundingApi(api, offline: offline);

      final created = await funding.createFundingSource(
        weddingPlanId: 'p1',
        kind: 'LOAN',
        sourceName: 'خالي',
        amount: '1000000',
        status: 'RECEIVED',
      );
      expect(OfflineWrites.isLocalId(created.id), isTrue);

      await expectLater(
        funding.addRepayment(created, amount: '300000'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('السلفة لسا ما وصلت حسابك'),
          ),
        ),
      );
      final kept = (await funding.cachedFundingSources('p1')).single;
      expect(kept.repayments, isEmpty);
      expect(await offline.database.pendingSyncCount(), 1);
    });

    // RA-MO-88: keyed by the repayment, the first answer (the loan) read as
    // an id swap and re-pointed the second change at the loan's id (404).
    test('two waiting changes of one repayment both reach its own path', () async {
      final (api, offline, server, reachability) = await _setUpSimple({
        'PATCH /api/v1/loan-repayments/r1': loan(
          repayments: [
            {...planned, 'status': 'PAID'},
          ],
        ),
        'DELETE /api/v1/loan-repayments/r1': loan(),
      });
      await offline.database.saveCachedItem(
        table: OfflineTables.cachedFundingSources,
        json: loan(repayments: [planned]),
      );
      server.down = true;
      final funding = FundingApi(api, offline: offline);
      final repayment = LoanRepayment.fromJson(planned);

      await funding.setRepaymentStatus(repayment, 'PAID');
      await funding.deleteRepayment(repayment);
      final waiting = await offline.database.pendingSyncItems();
      expect(waiting, hasLength(2));
      expect(waiting.map((item) => item.localEntityId).toSet(), {'f1'});

      server.down = false;
      reachability.noteReached();
      await offline.syncPendingChanges();

      expect(await offline.database.pendingSyncCount(), 0);
      expect(await offline.database.blockedSyncItems(), isEmpty);
      expect(
        server.calls.where((call) => !call.startsWith('GET')).skip(2),
        [
          'PATCH /api/v1/loan-repayments/r1',
          'DELETE /api/v1/loan-repayments/r1',
        ],
      );
    });
  });

  group('OfflineWrites.queued', () {
    test('sends now when the server answers and keeps the row', () async {
      final (api, offline, server, _) = await _setUpSimple({
        'POST /api/v1/wedding-plans/p1/guest-groups': {
          'id': 'g-server',
          'weddingPlanId': 'p1',
          'name': 'آل الحمدي',
        },
      });
      final writes = OfflineWrites(api, offline);
      final localId = OfflineWrites.localId('guest-group');

      final row = await writes.queued(
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

      expect(row['id'], 'g-server');
      expect(await offline.database.pendingSyncCount(), 0);
      final cached = await offline.database.readCachedList(
        table: OfflineTables.cachedGuestGroups,
        parentColumn: 'planId',
        parentId: 'p1',
      );
      expect(cached.single['id'], 'g-server');
    });

    test(
      'keeps the row on the phone and queues it when the server is down',
      () async {
        final (api, offline, server, reachability) = await _setUpSimple({
          'POST /api/v1/wedding-plans/p1/guest-groups': {
            'id': 'g-server',
            'weddingPlanId': 'p1',
            'name': 'آل الحمدي',
          },
        });
        server.down = true;
        final writes = OfflineWrites(api, offline);
        final localId = OfflineWrites.localId('guest-group');

        final row = await writes.queued(
          entityType: 'guest_group',
          operation: 'create',
          method: 'POST',
          endpoint: '/api/v1/wedding-plans/p1/guest-groups',
          payload: {'name': 'آل الحمدي'},
          table: OfflineTables.cachedGuestGroups,
          localJson: {
            'id': localId,
            'weddingPlanId': 'p1',
            'name': 'آل الحمدي',
          },
          planId: 'p1',
          localEntityId: localId,
        );

        expect(row['id'], localId);
        expect(await offline.database.pendingSyncCount(), 1);
        expect(offline.state, SyncState.offline);
        final cached = await offline.database.readCachedList(
          table: OfflineTables.cachedGuestGroups,
          parentColumn: 'planId',
          parentId: 'p1',
        );
        expect(cached.single['id'], localId);

        // The server answers again: the queue sends it and the server's id
        // replaces the phone's.
        server.down = false;
        reachability.noteReached();
        await offline.syncPendingChanges();
        expect(await offline.database.pendingSyncCount(), 0);
        final synced = await offline.database.readCachedList(
          table: OfflineTables.cachedGuestGroups,
          parentColumn: 'planId',
          parentId: 'p1',
        );
        expect(synced.single['id'], 'g-server');
        expect(server.calls.where((c) => c.startsWith('POST')).length, 2);
      },
    );

    // RA-MO-86: the server may have done a write whose answer was lost. It
    // knows the resend only by its request id, so the queue must send the
    // id the first try carried: a new one made «دعم الأهل 500 ألف» twice.
    test('a write whose answer was lost is resent under the same request '
        'id', () async {
      final (api, offline, server, reachability) = await _setUpSimple({
        'POST /api/v1/wedding-plans/p1/funding-sources': {
          'id': 'f-server',
          'weddingPlanId': 'p1',
          'kind': 'FAMILY_SUPPORT',
          'amount': '500000',
        },
      });
      server.losesAnswers = true;
      final writes = OfflineWrites(api, offline);
      final localId = OfflineWrites.localId('funding');

      final row = await writes.queued(
        entityType: 'funding_source',
        operation: 'create',
        method: 'POST',
        endpoint: '/api/v1/wedding-plans/p1/funding-sources',
        payload: {'kind': 'FAMILY_SUPPORT', 'amount': '500000'},
        table: OfflineTables.cachedFundingSources,
        localJson: {
          'id': localId,
          'weddingPlanId': 'p1',
          'kind': 'FAMILY_SUPPORT',
          'amount': '500000',
        },
        planId: 'p1',
        localEntityId: localId,
      );
      expect(row['id'], localId, reason: 'kept on the phone meanwhile');
      expect(await offline.database.pendingSyncCount(), 1);

      server.losesAnswers = false;
      reachability.noteReached();
      await offline.syncPendingChanges();

      expect(await offline.database.pendingSyncCount(), 0);
      expect(server.writeRequestIds, hasLength(2));
      expect(
        server.writeRequestIds.last,
        server.writeRequestIds.first,
        reason: 'the resend is the same request to the server',
      );
    });

    // RA-MO-31 still holds: an edit merged with a waiting edit is another
    // body, so it is another request.
    test('an edit that takes a waiting edit\'s fields goes under its own '
        'request id', () async {
      final (api, offline, server, _) = await _setUpSimple({});
      server.down = true;
      final writes = OfflineWrites(api, offline);
      Future<void> edit(Map<String, dynamic> payload) => writes.queued(
        entityType: 'guest_group',
        operation: 'update',
        method: 'PATCH',
        endpoint: '/api/v1/guest-groups/g1',
        payload: payload,
        table: OfflineTables.cachedGuestGroups,
        localJson: {'id': 'g1', 'weddingPlanId': 'p1', ...payload},
        planId: 'p1',
        localEntityId: 'g1',
        replacePendingForEntity: true,
      );

      await edit({'name': 'آل الحمدي'});
      final first = (await offline.database.pendingSyncItems()).single;
      await edit({'note': 'من جهة العريس'});
      final merged = (await offline.database.pendingSyncItems()).single;

      expect(merged.payload, {'name': 'آل الحمدي', 'note': 'من جهة العريس'});
      expect(merged.id, isNot(first.id));
    });

    test('serverOnly names the cause and why it cannot wait', () async {
      final (api, offline, server, _) = await _setUpSimple({});
      server.down = true;
      final writes = OfflineWrites(api, offline);
      await expectLater(
        writes.serverOnly(
          reason: 'الدعوة تحتاج الخادم عشان توصل.',
          method: 'POST',
          path: '/api/v1/wedding-plans/p1/invites',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetworkFailure, 'network', isTrue)
              .having(
                (e) => e.transportCause,
                'cause',
                ReachabilityCause.noNetwork,
              )
              .having((e) => e.message, 'message', contains('تحتاج الخادم')),
        ),
      );
    });
  });

  group('readCachedFirst', () {
    test(
      'shows the copy at once, then the server; a down server marks stale',
      () async {
        final states = <String>[];
        final applied = <List<String>>[];
        await readCachedFirst<List<String>>(
          cached: () async => ['copy'],
          remote: () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return ['fresh'];
          },
          apply: applied.add,
          state: ({required loading, required stale, error}) =>
              states.add('$loading/$stale/$error'),
          describe: (e) => 'x',
        );
        expect(applied, [
          ['copy'],
          ['fresh'],
        ]);
        expect(states, ['false/false/null', 'false/false/null']);

        states.clear();
        await readCachedFirst<List<String>>(
          cached: () async => ['copy'],
          remote: () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            throw const ApiException('down', isNetworkFailure: true);
          },
          apply: (_) {},
          state: ({required loading, required stale, error}) =>
              states.add('$loading/$stale/$error'),
          describe: (e) => 'x',
        );
        expect(states.last, 'false/true/null');
      },
    );

    test('a copy the contract served marks stale although the remote '
        'returned', () async {
      final states = <String>[];
      await readCachedFirst<List<String>>(
        cached: () async => ['copy'],
        remote: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          // What OfflineReads does when the server is out of reach.
          OfflineReads.noteCopyServed();
          return ['copy'];
        },
        apply: (_) {},
        state: ({required loading, required stale, error}) =>
            states.add('$loading/$stale/$error'),
        describe: (e) => 'x',
      );
      expect(states.last, 'false/true/null');
    });

    test('with no copy it loads, and a failure is the only error', () async {
      final states = <String>[];
      await readCachedFirst<List<String>>(
        cached: () async => null,
        remote: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          throw const ApiException('down');
        },
        apply: (_) {},
        state: ({required loading, required stale, error}) =>
            states.add('$loading/$stale/$error'),
        describe: (e) => 'ما وصلنا',
      );
      expect(states, ['true/false/null', 'false/false/ما وصلنا']);
    });
  });
}

Future<(ApiClient, OfflineSyncService, _Server, ServerReachability)>
_setUpSimple(Map<String, Object?> routes) async {
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
  return (api, offline, server, reachability);
}
