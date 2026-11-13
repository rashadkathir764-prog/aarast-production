import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-BE-129: the access token lives 15 minutes. A sign-out after that was
// refused by the server, and the refresh token stayed alive there for 30
// days (and the device's notices stayed registered). An expired token is
// now traded first, in memory, and the sign-out carries the fresh pair.

final _now = DateTime.utc(2026, 11, 13, 12);

String _token(DateTime expiresAt) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': 'u1', 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}'
      '.signature';
}

void main() {
  setUp(() => pinAppClock(_now));

  test('an expired token is read as expired, a live one as live', () {
    expect(
      accessTokenExpired(
        _token(_now.subtract(const Duration(minutes: 1))),
        now: _now,
      ),
      isTrue,
    );
    expect(
      accessTokenExpired(
        _token(_now.add(const Duration(minutes: 10))),
        now: _now,
      ),
      isFalse,
    );
    // Unreadable: taken as live, and the request finds out.
    expect(accessTokenExpired('not-a-token', now: _now), isFalse);
  });

  test('signing out with an expired token trades it, then revokes', () async {
    final adapter = await _signOut(
      _token(_now.subtract(const Duration(minutes: 40))),
    );

    expect(adapter.paths, ['/api/v1/auth/refresh', '/api/v1/auth/logout']);
    expect(adapter.requests.first.data, {'refreshToken': 'old-refresh'});
    final logout = adapter.requests.last;
    expect(logout.headers['Authorization'], 'Bearer fresh-access');
    expect(logout.data, {'refreshToken': 'fresh-refresh'});
  });

  test('a live token signs out at once, without a trade', () async {
    final adapter = await _signOut(
      _token(_now.add(const Duration(minutes: 10))),
    );

    expect(adapter.paths, ['/api/v1/auth/logout']);
    expect(adapter.requests.single.data, {'refreshToken': 'old-refresh'});
  });

  test('a refused trade still signs out on the phone', () async {
    final adapter = await _signOut(
      _token(_now.subtract(const Duration(minutes: 40))),
      refreshStatus: 401,
    );

    expect(adapter.paths.first, '/api/v1/auth/refresh');
    expect(adapter.storage.readUser(), isNull);
    expect(await adapter.storage.readRefreshToken(), isNull);
  });
}

Future<_Adapter> _signOut(String accessToken, {int refreshStatus = 200}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: accessToken,
    refreshToken: 'old-refresh',
    user: const SafeUser(
      id: 'u1',
      name: 'محمد',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
  final api = ApiClient(tokenProvider: storage.readAccessToken);
  final adapter = _Adapter(storage, refreshStatus: refreshStatus);
  api.dio.httpClientAdapter = adapter;
  await AuthRepository(api, storage).logout();
  return adapter;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.storage, {required this.refreshStatus});

  final AuthStorage storage;
  final int refreshStatus;
  final List<RequestOptions> requests = [];

  List<String> get paths => [for (final r in requests) r.path];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/v1/auth/refresh') {
      if (refreshStatus != 200) {
        return _json({'message': 'Unauthorized'}, refreshStatus);
      }
      return _json({
        'accessToken': 'fresh-access',
        'refreshToken': 'fresh-refresh',
        'refreshTokenExpiresAt': '2026-12-13T12:00:00.000Z',
        'user': {
          'id': 'u1',
          'name': 'محمد',
          'phone': '+967777123456',
          'role': 'USER',
          'status': 'ACTIVE',
          'createdAt': '2026-07-10T12:00:00.000Z',
          'updatedAt': '2026-07-10T12:00:00.000Z',
        },
      });
    }
    if (options.path == '/api/v1/auth/logout') {
      return _json({'revoked': 1});
    }
    return ResponseBody.fromString('Not found', 404);
  }

  ResponseBody _json(Map<String, Object?> value, [int status = 200]) {
    return ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
