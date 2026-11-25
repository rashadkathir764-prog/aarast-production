import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-343: a change kept on the phone waited for something else to send it
// (an app resume, a request that happened to succeed). Now the queue retries
// by itself, with a growing wait, never in a loop, and a resume or the
// first answer from the server tries at once.

/// The server is down until [reachable] is set; every request is counted.
class _Server implements HttpClientAdapter {
  bool reachable = false;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests += 1;
    if (!reachable) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no network',
      );
    }
    return ResponseBody.fromString(
      '{"id":"remote-1"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _tick = Duration(milliseconds: 40);

Future<void> _pause(Duration duration) =>
    Future<void>.delayed(duration + const Duration(milliseconds: 15));

/// Waits, at most a second, for [done] (the timers run in real time).
Future<void> _until(Future<bool> Function() done) async {
  for (var i = 0; i < 100 && !await done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late JsonLocalDatabase database;
  late _Server server;
  late List<int> asked;

  /// [growth] waits: 40ms, 80ms, 160ms... asked by attempt number.
  Future<OfflineSyncService> service({bool retries = true}) async {
    SharedPreferences.setMockInitialValues({});
    database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    server = _Server();
    final mine = asked = [];
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    apiClient.dio.httpClientAdapter = server;
    final sync = OfflineSyncService(
      database: database,
      apiClient: apiClient,
      retryDelay: retries
          ? (attempt) {
              mine.add(attempt);
              return _tick * (1 << attempt);
            }
          : null,
    );
    addTearDown(sync.dispose);
    await sync.ensureCacheOwner('user-A');
    return sync;
  }

  Future<void> queueTask() => database.enqueueSync(
    entityType: 'task',
    operation: 'create',
    endpoint: '/wedding-plans/plan-1/tasks',
    method: 'POST',
    payload: {'title': 'مهمة'},
    planId: 'plan-1',
    localEntityId: 'local-task-1',
  );

  test(
    'a failed send tries again by itself, waiting longer each time',
    () async {
      final sync = await service();
      await queueTask();

      await sync.syncPendingChanges();
      expect(server.requests, 1);
      expect(sync.state, SyncState.offline);

      // First wait 40ms, then 80ms, then 160ms: three more tries in 300ms, not
      // a try every few milliseconds.
      await _pause(const Duration(milliseconds: 300));

      expect(server.requests, inInclusiveRange(3, 4));
      expect(asked.take(3), [0, 1, 2]);
      expect(await database.pendingSyncCount(), 1);
    },
  );

  test('the queue is sent as soon as the server answers, and then stops '
      'trying', () async {
    final sync = await service();
    await queueTask();
    await sync.syncPendingChanges();

    server.reachable = true;
    await _until(() async => await database.pendingSyncCount() == 0);

    expect(await database.pendingSyncCount(), 0);
    expect(sync.state, SyncState.synced);
    final requests = server.requests;
    await _pause(const Duration(milliseconds: 400));
    expect(server.requests, requests, reason: 'nothing left to retry');
  });

  test(
    'a change kept on the phone without a try starts the retries too',
    () async {
      final sync = await service();
      await queueTask();

      // What a write does when the phone knows it is offline: it keeps the
      // change and tells the service, with no sync pass of its own.
      await sync.noteNetworkFailure('no network');
      await _pause(_tick);

      expect(server.requests, greaterThanOrEqualTo(1));
    },
  );

  test('an app resume tries at once and starts the waits over', () async {
    final sync = await service();
    await queueTask();
    await sync.syncPendingChanges();
    await _pause(const Duration(milliseconds: 150));
    expect(asked.last, greaterThanOrEqualTo(1));

    asked.clear();
    final before = server.requests;
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(server.requests, before + 1);
    expect(asked, [0], reason: 'the wait is the first one again');
  });

  test('a refused change is not retried: only waiting ones are', () async {
    await service();
    await queueTask();
    server.reachable = true;
    // A 4xx blocks the item for the person to see; nothing to retry.
    final blocked = ApiClient(tokenProvider: () async => 'token');
    blocked.dio.httpClientAdapter = _Refusing();
    final asked = <int>[];
    final refusing = OfflineSyncService(
      database: database,
      apiClient: blocked,
      retryDelay: (attempt) {
        asked.add(attempt);
        return _tick;
      },
    );
    addTearDown(refusing.dispose);
    await refusing.ensureCacheOwner('user-A');

    await refusing.syncPendingChanges();
    await _pause(_tick * 3);

    expect(asked, isEmpty);
    expect(refusing.blockedCount, 1);
  });

  test('signing out stops the retries', () async {
    final sync = await service();
    await queueTask();
    await sync.syncPendingChanges();
    expect(server.requests, 1);

    await sync.clearLocalData();
    final requests = server.requests;
    await _pause(const Duration(milliseconds: 300));

    expect(server.requests, requests);
  });

  test('the app waits 10 seconds, doubling, to a ceiling of 5 minutes', () {
    expect(
      [
        for (var attempt = 0; attempt < 7; attempt++)
          OfflineSyncService.standardRetryDelay(attempt).inSeconds,
      ],
      [10, 20, 40, 80, 160, 300, 300],
    );
    expect(OfflineSyncService.standardRetryDelay(500).inMinutes, 5);
  });

  test('without a retry policy nothing is scheduled', () async {
    final sync = await service(retries: false);
    await queueTask();

    await sync.syncPendingChanges();
    await _pause(const Duration(milliseconds: 200));

    expect(server.requests, 1);
  });
}

class _Refusing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"bad"}',
    400,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
