import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invite OTP request rejects a missing account-setup contract', () async {
    final harness = await _Harness.create(
      _InviteAuthAdapter(includeAccountSetupRequired: false),
    );

    await expectLater(
      harness.repository.requestInviteOtp(
        token: _inviteToken,
        phone: '777123456',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(await harness.storage.readAccessToken(), isNull);
    expect(await harness.storage.readRefreshToken(), isNull);
  });

  test('invite verification never persists an incomplete session', () async {
    final harness = await _Harness.create(
      _InviteAuthAdapter(completeVerifySession: false),
    );

    await expectLater(
      harness.repository.verifyInviteOtp(
        token: _inviteToken,
        phone: '777123456',
        code: '123456',
        name: 'مساهم',
        password: 'contributor-secret',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(await harness.storage.readAccessToken(), isNull);
    expect(await harness.storage.readRefreshToken(), isNull);
    expect(harness.storage.readUser(), isNull);
  });

  test(
    'durable invite session restores without OTP then supports password login after logout',
    () async {
      final adapter = _InviteAuthAdapter();
      final harness = await _Harness.create(adapter);
      final verified = await harness.repository.verifyInviteOtp(
        token: _inviteToken,
        phone: '777123456',
        code: '123456',
        name: 'مساهم',
        password: 'contributor-secret',
      );

      expect(verified.hasDurableSession, isTrue);
      expect(await harness.storage.readAccessToken(), 'invite-access-token');
      expect(await harness.storage.readRefreshToken(), 'invite-refresh-token');
      expect(harness.storage.readUser()?.id, 'contributor-1');

      final restartedClient = ApiClient(
        tokenProvider: harness.storage.readAccessToken,
      )..dio.httpClientAdapter = adapter;
      final restartedRepository = AuthRepository(
        restartedClient,
        harness.storage,
      );
      final restartedController = AuthController(restartedRepository);
      await restartedController.restoreSession();

      expect(restartedController.status, AuthStatus.authenticated);
      expect(restartedController.user?.id, 'contributor-1');
      expect(
        adapter.paths.where((path) => path.endsWith('/verify-otp')).length,
        1,
      );
      expect(
        adapter.paths.where((path) => path == '/api/v1/auth/me').length,
        1,
      );

      await restartedController.logout();
      expect(await harness.storage.readAccessToken(), isNull);
      expect(await harness.storage.readRefreshToken(), isNull);
      expect(restartedController.status, AuthStatus.unauthenticated);

      expect(
        await restartedController.login(
          phone: '777123456',
          password: 'contributor-secret',
        ),
        isTrue,
      );
      expect(restartedController.status, AuthStatus.authenticated);
      expect(await harness.storage.readAccessToken(), 'password-access-token');
      expect(
        await harness.storage.readRefreshToken(),
        'password-refresh-token',
      );
      final loginRequest = adapter.requests.lastWhere(
        (request) => request.path == '/api/v1/auth/login',
      );
      expect(loginRequest.data['password'], 'contributor-secret');
    },
  );
}

const _inviteToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Harness {
  const _Harness(this.storage, this.repository);

  final AuthStorage storage;
  final AuthRepository repository;

  static Future<_Harness> create(HttpClientAdapter adapter) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final client = ApiClient(tokenProvider: storage.readAccessToken)
      ..dio.httpClientAdapter = adapter;
    return _Harness(storage, AuthRepository(client, storage));
  }
}

class _InviteAuthAdapter implements HttpClientAdapter {
  _InviteAuthAdapter({
    this.includeAccountSetupRequired = true,
    this.completeVerifySession = true,
  });

  final bool includeAccountSetupRequired;
  final bool completeVerifySession;
  final List<RequestOptions> requests = [];

  List<String> get paths => requests.map((request) => request.path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path.endsWith('/request-otp')) {
      return _json({
        'phone': '+967777123456',
        'purpose': 'LOGIN',
        'expiresAt': '2026-07-29T12:05:00.000Z',
        'delivery': 'WHATSAPP',
        'deliveryStatus': 'SENT',
        if (includeAccountSetupRequired) 'accountSetupRequired': true,
      });
    }
    if (options.path.endsWith('/verify-otp')) {
      return _json({
        'verified': true,
        'phone': '+967777123456',
        'purpose': 'LOGIN',
        'accessToken': 'invite-access-token',
        if (completeVerifySession) ...{
          'refreshToken': 'invite-refresh-token',
          'refreshTokenExpiresAt': '2026-08-29T12:00:00.000Z',
        },
        'user': _userJson(),
      });
    }
    if (options.path == '/api/v1/auth/me') {
      return _json(_userJson());
    }
    if (options.path == '/api/v1/auth/logout') {
      return _json({'loggedOut': true});
    }
    if (options.path == '/api/v1/auth/login') {
      return _json({
        'accessToken': 'password-access-token',
        'refreshToken': 'password-refresh-token',
        'refreshTokenExpiresAt': '2026-08-29T12:00:00.000Z',
        'user': _userJson(),
      });
    }
    return ResponseBody.fromString('Not found', 404);
  }

  ResponseBody _json(Map<String, Object?> value) {
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, Object?> _userJson() {
    return {
      'id': 'contributor-1',
      'name': 'مساهم',
      'phone': '+967777123456',
      'email': null,
      'role': 'USER',
      'appRole': 'WEDDING_USER',
      'status': 'ACTIVE',
      'phoneVerifiedAt': '2026-07-29T12:00:00.000Z',
      'lastLoginAt': '2026-07-29T12:00:00.000Z',
      'avatarUrl': null,
      'locale': 'ar',
      'activeWeddingPlanId': null,
      'onboardingPath': null,
      'persona': null,
      'onboardingCompletedAt': null,
      'createdAt': '2026-07-29T12:00:00.000Z',
      'updatedAt': '2026-07-29T12:00:00.000Z',
    };
  }

  @override
  void close({bool force = false}) {}
}
