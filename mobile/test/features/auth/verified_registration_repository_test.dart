import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('registration stores no session before OTP completion', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final api = ApiClient(tokenProvider: storage.readAccessToken);
    final adapter = _RegistrationAdapter();
    api.dio.httpClientAdapter = adapter;
    final repository = AuthRepository(api, storage);

    final pending = await repository.startRegistration(
      name: 'مستخدم جديد',
      phone: '777123456',
      password: 'secret123',
    );

    expect(pending.purpose, 'REGISTER');
    expect(adapter.requests.single.path, '/api/v1/auth/register');
    expect(adapter.requests.single.data, isNot(contains('otpCode')));
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);

    final completed = await repository.register(
      name: 'مستخدم جديد',
      phone: '777123456',
      password: 'secret123',
      otpCode: '123456',
    );

    expect(adapter.requests.last.path, '/api/v1/auth/register/complete');
    expect(adapter.requests.last.data['otpCode'], '123456');
    expect(completed.user.phoneVerifiedAt, isNotNull);
    expect(await storage.readAccessToken(), 'access-token');
    expect(await storage.readRefreshToken(), 'refresh-token');
  });
}

class _RegistrationAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/v1/auth/register') {
      return _jsonResponse({
        'registrationPending': true,
        'phone': '+967777123456',
        'purpose': 'REGISTER',
        'expiresAt': '2026-07-10T12:00:00.000Z',
        'delivery': 'LOCAL_DEV',
        'code': '123456',
      });
    }
    if (options.path == '/api/v1/auth/register/complete') {
      return _jsonResponse({
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'refreshTokenExpiresAt': '2026-08-10T12:00:00.000Z',
        'user': {
          'id': 'user-1',
          'name': 'مستخدم جديد',
          'phone': '+967777123456',
          'email': null,
          'role': 'USER',
          'appRole': 'WEDDING_USER',
          'status': 'ACTIVE',
          'phoneVerifiedAt': '2026-07-10T12:00:00.000Z',
          'lastLoginAt': '2026-07-10T12:00:00.000Z',
          'avatarUrl': null,
          'locale': 'ar',
          'activeWeddingPlanId': null,
          'onboardingPath': null,
          'persona': null,
          'onboardingCompletedAt': null,
          'createdAt': '2026-07-10T12:00:00.000Z',
          'updatedAt': '2026-07-10T12:00:00.000Z',
        },
      });
    }
    return ResponseBody.fromString('Not found', 404);
  }

  ResponseBody _jsonResponse(Map<String, Object?> value) {
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
