import 'dart:async';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('logout/login cannot replay user A queue with user B token', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    var token = 'token-user-a';
    final apiClient = ApiClient(tokenProvider: () async => token);
    final adapter = _SessionRaceAdapter();
    apiClient.dio.httpClientAdapter = adapter;
    final service = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );

    await service.ensureCacheOwner('user-a');
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/user-a-private-write',
      method: 'POST',
      payload: {'title': 'private A'},
    );

    final oldSync = service.syncPendingChanges();
    await adapter.firstStarted.future.timeout(const Duration(seconds: 2));

    await service.clearLocalData();
    token = 'token-user-b';
    await service.ensureCacheOwner('user-b');
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/user-b-private-write',
      method: 'POST',
      payload: {'title': 'private B'},
    );

    adapter.releaseFirst.complete();
    await oldSync;
    await adapter.secondStarted.future.timeout(const Duration(seconds: 2));
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (await database.pendingSyncCount() == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(adapter.received, hasLength(2));
    expect(adapter.received[0].path, '/user-a-private-write');
    expect(adapter.received[0].headers['Authorization'], 'Bearer token-user-a');
    expect(adapter.received[1].path, '/user-b-private-write');
    expect(adapter.received[1].headers['Authorization'], 'Bearer token-user-b');
    expect(await database.pendingSyncCount(), 0);
  });

  test('a stale-token 401 cannot expire the replacement session', () async {
    var token = 'token-user-b';
    var refreshCalls = 0;
    var expiryCalls = 0;
    final apiClient = ApiClient(tokenProvider: () async => token)
      ..refreshSession = () async {
        refreshCalls += 1;
        return false;
      }
      ..onSessionExpired = () => expiryCalls += 1;
    final adapter = _UnauthorizedAdapter();
    apiClient.dio.httpClientAdapter = adapter;

    await expectLater(
      apiClient.dio.get<Object?>(
        '/old-session-request',
        options: Options(headers: {'Authorization': 'Bearer token-user-a'}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(token, 'token-user-b');
    expect(adapter.authorization, 'Bearer token-user-a');
    expect(refreshCalls, 0);
    expect(expiryCalls, 0);
  });

  test(
    'a request waiting for a token is cancelled when account changes',
    () async {
      final tokenReadStarted = Completer<void>();
      final tokenResult = Completer<String?>();
      final apiClient = ApiClient(
        tokenProvider: () async {
          tokenReadStarted.complete();
          return tokenResult.future;
        },
      );
      final adapter = _RecordingOkAdapter();
      apiClient.dio.httpClientAdapter = adapter;
      apiClient.bindSessionIdentity('user-a');

      final request = apiClient.dio.get<Object?>('/private-write');
      await tokenReadStarted.future;
      apiClient.bindSessionIdentity('user-b');
      tokenResult.complete('token-user-a');

      await expectLater(
        request,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(adapter.requestCount, 0);
    },
  );

  test(
    'an in-flight response is cancelled when selected context changes',
    () async {
      final apiClient = ApiClient(tokenProvider: () async => 'account-token');
      final adapter = _DelayedOkAdapter();
      apiClient.dio.httpClientAdapter = adapter;
      apiClient.bindSessionIdentity('user-a');
      apiClient.bindContextIdentity('plan:one:owner');

      final request = apiClient.dio.get<Object?>('/plan-one-private-read');
      await adapter.started.future;
      apiClient.bindContextIdentity('plan:two:owner');
      adapter.release.complete();

      await expectLater(
        request,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    },
  );
}

class _SessionRaceAdapter implements HttpClientAdapter {
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  final secondStarted = Completer<void>();
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    if (received.length == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    } else {
      secondStarted.complete();
    }
    return ResponseBody.fromString(
      '{"id":"remote-${received.length}"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorization = options.headers['Authorization']?.toString();
    return ResponseBody.fromString(
      '{"message":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingOkAdapter implements HttpClientAdapter {
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

class _DelayedOkAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await release.future;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
