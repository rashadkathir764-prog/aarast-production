import 'dart:async';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('401 refreshes once and retries with the new access token', () async {
    var token = 'old-access';
    var refreshCalls = 0;
    final adapter = _RefreshAdapter();
    final client = ApiClient(tokenProvider: () async => token);
    client.dio.httpClientAdapter = adapter;
    client.refreshSession = () async {
      refreshCalls += 1;
      token = 'new-access';
      return true;
    };

    final result = await client.getJson('/protected');

    expect(result['ok'], true);
    expect(refreshCalls, 1);
    expect(adapter.calls, 2);
  });

  test(
    'GET /api/v1/auth/me refreshes once and retries with the new access token',
    () async {
      var token = 'old-access';
      var refreshCalls = 0;
      final adapter = _RefreshAdapter();
      final client = ApiClient(tokenProvider: () async => token);
      client.dio.httpClientAdapter = adapter;
      client.refreshSession = () async {
        refreshCalls += 1;
        token = 'new-access';
        return true;
      };

      final result = await client.getJson('/api/v1/auth/me');

      expect(result['ok'], true);
      expect(refreshCalls, 1);
      expect(adapter.calls, 2);
    },
  );

  test('POST /api/v1/auth/refresh never triggers session refresh', () async {
    var refreshCalls = 0;
    final adapter = _RefreshAdapter();
    final client = ApiClient(tokenProvider: () async => 'old-access');
    client.dio.httpClientAdapter = adapter;
    client.refreshSession = () async {
      refreshCalls += 1;
      return true;
    };

    await expectLater(
      client.postJson('/api/v1/auth/refresh', const {}),
      throwsA(isA<ApiException>()),
    );

    expect(refreshCalls, 0);
    expect(adapter.calls, 1);
  });

  test('POST /api/v1/auth/login never triggers session refresh', () async {
    var refreshCalls = 0;
    final adapter = _RefreshAdapter();
    final client = ApiClient(tokenProvider: () async => 'old-access');
    client.dio.httpClientAdapter = adapter;
    client.refreshSession = () async {
      refreshCalls += 1;
      return true;
    };

    await expectLater(
      client.postJson('/api/v1/auth/login', const {}),
      throwsA(isA<ApiException>()),
    );

    expect(refreshCalls, 0);
    expect(adapter.calls, 1);
  });

  test(
    'an old request waiting for refresh cannot retry or expire the replacement session',
    () async {
      var token = 'token-user-a';
      var expiryCalls = 0;
      final refreshStarted = Completer<void>();
      final refreshResult = Completer<bool>();
      final adapter = _AlwaysUnauthorizedAdapter();
      final client = ApiClient(tokenProvider: () async => token);
      client.dio.httpClientAdapter = adapter;
      client.bindSessionIdentity('user-a');
      client.refreshSession = () {
        refreshStarted.complete();
        return refreshResult.future;
      };
      client.onSessionExpired = () => expiryCalls += 1;

      final oldRequest = client.getJson('/protected');
      await refreshStarted.future.timeout(const Duration(seconds: 2));

      token = 'token-user-b';
      client.bindSessionIdentity('user-b');
      refreshResult.complete(true);

      await expectLater(oldRequest, throwsA(isA<ApiException>()));
      expect(adapter.calls, 1);
      expect(expiryCalls, 0);
    },
  );

  test(
    'a replacement session does not join the previous session refresh',
    () async {
      var token = 'token-user-a';
      var tokenReads = 0;
      var refreshCalls = 0;
      final oldRefreshResult = Completer<bool>();
      final oldRefreshStarted = Completer<void>();
      final replacementErrorTokenRead = Completer<void>();
      final adapter = _SessionReplacementAdapter();
      final client = ApiClient(
        tokenProvider: () async {
          tokenReads += 1;
          if (tokenReads == 4) replacementErrorTokenRead.complete();
          return token;
        },
      );
      client.dio.httpClientAdapter = adapter;
      client.bindSessionIdentity('user-a');
      client.refreshSession = () {
        refreshCalls += 1;
        if (refreshCalls == 1) {
          oldRefreshStarted.complete();
          return oldRefreshResult.future;
        }
        token = 'token-user-b-refreshed';
        return Future<bool>.value(true);
      };

      final oldRequest = client.getJson('/old-session-request');
      await oldRefreshStarted.future.timeout(const Duration(seconds: 2));

      token = 'token-user-b-expired';
      client.bindSessionIdentity('user-b');
      final replacementRequest = client.getJson('/replacement-request');

      try {
        await replacementErrorTokenRead.future.timeout(
          const Duration(seconds: 2),
        );
        await Future<void>.delayed(Duration.zero);

        expect(refreshCalls, 2);
        expect(await replacementRequest, {'ok': true});
      } finally {
        if (!oldRefreshResult.isCompleted) oldRefreshResult.complete(false);
        await Future.wait<void>([
          oldRequest.then<void>((_) {}, onError: (_) {}),
          replacementRequest.then<void>((_) {}, onError: (_) {}),
        ]);
      }
    },
  );

  test(
    'an old request cannot retry when the session changes while reading the refreshed token',
    () async {
      var token = 'token-user-a';
      var tokenReads = 0;
      var expiryCalls = 0;
      final retryTokenReadStarted = Completer<void>();
      final retryTokenResult = Completer<String?>();
      final adapter = _AlwaysUnauthorizedAdapter();
      final client = ApiClient(
        tokenProvider: () async {
          tokenReads += 1;
          if (tokenReads == 3) {
            retryTokenReadStarted.complete();
            return retryTokenResult.future;
          }
          return token;
        },
      );
      client.dio.httpClientAdapter = adapter;
      client.bindSessionIdentity('user-a');
      client.refreshSession = () async => true;
      client.onSessionExpired = () => expiryCalls += 1;

      final oldRequest = client.getJson('/protected');
      await retryTokenReadStarted.future.timeout(const Duration(seconds: 2));

      token = 'token-user-b';
      client.bindSessionIdentity('user-b');
      retryTokenResult.complete(token);

      await expectLater(oldRequest, throwsA(isA<ApiException>()));
      expect(adapter.calls, 1);
      expect(expiryCalls, 0);
    },
  );

  test('a refresh retry preserves its original session generation', () async {
    var token = 'token-user-a';
    var expiryCalls = 0;
    var requestEntries = 0;
    final retryReachedInterceptors = Completer<void>();
    final releaseRetry = Completer<void>();
    final adapter = _AlwaysUnauthorizedAdapter();
    final client = ApiClient(tokenProvider: () async => token);
    client.dio.httpClientAdapter = adapter;
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requestEntries += 1;
          if (requestEntries == 2) {
            retryReachedInterceptors.complete();
            await releaseRetry.future;
          }
          handler.next(options);
        },
      ),
    );
    client.bindSessionIdentity('user-a');
    client.refreshSession = () async {
      token = 'token-user-a-refreshed';
      return true;
    };
    client.onSessionExpired = () => expiryCalls += 1;

    final oldRequest = client.getJson('/protected');
    await retryReachedInterceptors.future.timeout(const Duration(seconds: 2));

    token = 'token-user-b';
    client.bindSessionIdentity('user-b');
    releaseRetry.complete();

    await expectLater(oldRequest, throwsA(isA<ApiException>()));
    expect(adapter.calls, 1);
    expect(expiryCalls, 0);
  });

  test('signed byte uploads do not send the app bearer token', () async {
    final uploadDio = Dio();
    final adapter = _CaptureUploadAdapter();
    uploadDio.httpClientAdapter = adapter;
    final client = ApiClient(
      tokenProvider: () async => 'private-access-token',
      uploadDio: uploadDio,
    );

    await client.putBytes(
      'https://uploads.example.com/signed',
      Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );

    expect(adapter.authorizationHeader, isNull);
    expect(adapter.contentTypeHeader, 'image/jpeg');
    expect(adapter.contentLengthHeader, 3);
    expect(adapter.ifNoneMatchHeader, '*');
  });
}

class _RefreshAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (options.headers['Authorization'] == 'Bearer new-access') {
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"message":"expired"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CaptureUploadAdapter implements HttpClientAdapter {
  Object? authorizationHeader;
  Object? contentTypeHeader;
  Object? contentLengthHeader;
  Object? ifNoneMatchHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizationHeader = options.headers['Authorization'];
    contentTypeHeader = options.headers[Headers.contentTypeHeader];
    contentLengthHeader = options.headers[Headers.contentLengthHeader];
    ifNoneMatchHeader = options.headers['If-None-Match'];
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return ResponseBody.fromString(
      '{"message":"expired"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SessionReplacementAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['Authorization'] == 'Bearer token-user-b-refreshed') {
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"message":"expired"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
