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

  test(
    'an account context change does not discard a successful session restore response',
    () async {
      final adapter = _DelayedSuccessAdapter();
      final client = ApiClient(tokenProvider: () async => 'account-token');
      client.dio.httpClientAdapter = adapter;
      client.bindSessionIdentity('user-a');

      final restore = client.getJson('/api/v1/auth/me');
      await adapter.started.future.timeout(const Duration(seconds: 2));

      client.bindContextIdentity('plan:one:owner');
      adapter.release.complete();

      expect(await restore, {'id': 'user-a'});
    },
  );

  test(
    'an expired session refreshes for the signed-in auth writes too',
    () async {
      for (final path in const [
        '/api/v1/auth/password',
        '/api/v1/auth/phone-change/request',
        '/api/v1/auth/phone-change/confirm',
      ]) {
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

        final result = await client.postJson(path, const {});

        expect(result['ok'], true, reason: path);
        expect(refreshCalls, 1, reason: path);
        expect(adapter.calls, 2, reason: path);
      }
    },
  );

  // RA-MO-100: opening the app on a weak network, the refresh never reached
  // the server, and the first 401 was passed on as a refusal: the session
  // ended. A refresh that did not reach an answer is the connection.
  test('a refresh that cannot reach the server is a network failure', () async {
    var expired = 0;
    final adapter = _RefreshAdapter();
    final client = ApiClient(tokenProvider: () async => 'old-access');
    client.dio.httpClientAdapter = adapter;
    client.onSessionExpired = () => expired += 1;
    client.refreshSession = () async =>
        throw const ApiException('ما وصلنا', isNetworkFailure: true);

    await expectLater(
      client.getJson('/api/v1/auth/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isNetworkFailure, 'network', isTrue)
            .having((e) => e.isUnauthorized, 'unauthorized', isFalse),
      ),
    );
    expect(expired, 0);
  });

  test(
    'a wrong current password is an answer, not an expired session',
    () async {
      var refreshCalls = 0;
      var expired = 0;
      final adapter = _WrongPasswordAdapter();
      final client = ApiClient(tokenProvider: () async => 'access');
      client.dio.httpClientAdapter = adapter;
      client.onSessionExpired = () => expired += 1;
      client.refreshSession = () async {
        refreshCalls += 1;
        return true;
      };

      await expectLater(
        client.postJson('/api/v1/auth/password', const {}),
        throwsA(isA<ApiException>()),
      );

      expect(refreshCalls, 0);
      expect(expired, 0);
      expect(adapter.calls, 1);
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

class _WrongPasswordAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return ResponseBody.fromString(
      '{"code":"INVALID_CREDENTIALS","message":"Invalid credentials"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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

class _DelayedSuccessAdapter implements HttpClientAdapter {
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
      '{"id":"user-a"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
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
