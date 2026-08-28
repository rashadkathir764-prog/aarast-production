import 'dart:async';
import 'dart:convert';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthController session establishment guard', () {
    late _CollectingLogSink logSink;

    setUp(() {
      logSink = _CollectingLogSink();
      AppLogger.installGlobal(
        AppLogger(
          redactor: LogRedactor(installationSalt: 'auth-controller-test'),
          sinks: [logSink],
        ),
      );
    });

    tearDown(AppLogger.clearGlobal);

    test(
      'rejects every session-establishing API while logout is terminating',
      () async {
        final harness = await _AuthHarness.authenticated(
          remoteBehavior: _RemoteBehavior.blockUntilReleased,
        );
        addTearDown(harness.dispose);

        final logout = harness.controller.logout();

        expect(harness.controller.status, AuthStatus.terminating);
        expect(harness.controller.user, isNull);

        expect(
          await harness.controller.login(
            phone: '+967700000001',
            password: 'secret',
            successLocation: '/after-login',
          ),
          isFalse,
        );
        expect(
          await harness.controller.register(
            name: 'New User',
            phone: '+967700000002',
            password: 'secret',
            otpCode: '123456',
            successLocation: '/after-register',
          ),
          isFalse,
        );
        expect(
          await harness.controller.verifyOtp(
            phone: '+967700000003',
            purpose: 'LOGIN',
            code: '123456',
            successLocation: '/after-login-otp',
          ),
          isFalse,
        );
        expect(
          await harness.controller.verifyOtp(
            phone: '+967700000004',
            purpose: 'LOGIN',
            code: '123456',
            resumeInviteToken: List.filled(43, 'a').join(),
            successLocation: '/after-invite-otp',
          ),
          isFalse,
        );

        expect(harness.repository.loginCalls, 0);
        expect(harness.repository.registerCalls, 0);
        expect(harness.repository.loginOtpVerifyCalls, 0);
        expect(harness.repository.inviteOtpVerifyCalls, 0);
        expect(harness.controller.hasPendingAuthenticatedEntry, isFalse);

        harness.repository.releaseRemoteTeardown();
        await logout;
        expect(harness.controller.status, AuthStatus.unauthenticated);
        expect(
          logSink.events.where((event) => event.name == 'logout_started'),
          hasLength(1),
        );
        expect(
          logSink.events.where((event) => event.name == 'logout_completed'),
          hasLength(1),
        );
      },
    );

    test(
      'post-auth intent preserves successLocation and can be claimed once',
      () async {
        final harness = await _AuthHarness.unauthenticated();
        addTearDown(harness.dispose);
        const successLocation = '/settings/support?source=auth';

        final success = await harness.controller.login(
          phone: '+967700000001',
          password: 'secret',
          successLocation: successLocation,
        );

        expect(success, isTrue);
        expect(harness.controller.status, AuthStatus.authenticated);
        expect(harness.controller.hasPendingAuthenticatedEntry, isTrue);
        expect(
          harness.controller.claimPendingAuthenticatedEntry(),
          successLocation,
        );
        expect(harness.controller.hasPendingAuthenticatedEntry, isFalse);
        expect(harness.controller.claimPendingAuthenticatedEntry(), isNull);
        expect(
          logSink.events.map((event) => event.name),
          containsAllInOrder(['login_started', 'login_succeeded']),
        );
        expect(
          logSink.events
              .singleWhere((event) => event.name == 'login_succeeded')
              .attributes['userIdHash'],
          isA<String>(),
        );
      },
    );

    test('failed login emits one redacted failure event', () async {
      final harness = await _AuthHarness.unauthenticated();
      addTearDown(harness.dispose);
      harness.repository.loginFailure = const ApiException(
        'Invalid credentials for +967700000001 using raw-password',
        statusCode: 401,
        serverCode: 'INVALID_CREDENTIALS',
      );

      expect(
        await harness.controller.login(
          phone: '+967700000001',
          password: 'raw-password',
        ),
        isFalse,
      );

      expect(
        logSink.events.map((event) => event.name),
        containsAllInOrder(['login_started', 'login_failed']),
      );
      final encoded = jsonEncode(
        logSink.events
            .singleWhere((event) => event.name == 'login_failed')
            .toJson(),
      );
      expect(encoded, isNot(contains('967700000001')));
      expect(encoded, isNot(contains('raw-password')));
      expect(encoded, isNot(contains('Invalid credentials')));
    });

    test('remote teardown timeout leaves the local session ended', () async {
      final harness = await _AuthHarness.authenticated(
        remoteBehavior: _RemoteBehavior.waitForCancellation,
        remoteTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(harness.dispose);

      await harness.controller.logout();

      expect(harness.repository.localSessionCleared, isTrue);
      expect(harness.repository.remoteCancellationObserved, isTrue);
      expect(harness.controller.user, isNull);
      expect(harness.controller.status, AuthStatus.unauthenticated);
      expect(harness.controller.loginRequestedAfterLogout, isTrue);
      expect(
        logSink.events.where((event) => event.name == 'logout_completed'),
        hasLength(1),
      );
    });

    test(
      'session expiry enters the same safe teardown boundary immediately',
      () async {
        final harness = await _AuthHarness.authenticated(
          remoteBehavior: _RemoteBehavior.blockUntilReleased,
        );
        addTearDown(harness.dispose);

        final expiry = harness.controller.handleSessionExpired();

        expect(harness.controller.user, isNull);
        expect(harness.controller.status, AuthStatus.terminating);
        expect(harness.controller.sessionExpired, isTrue);

        harness.repository.releaseRemoteTeardown();
        await expiry;

        expect(harness.controller.status, AuthStatus.unauthenticated);
        expect(harness.controller.loginRequestedAfterLogout, isFalse);
      },
    );
  });
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}

enum _RemoteBehavior {
  completeImmediately,
  blockUntilReleased,
  waitForCancellation,
}

class _AuthHarness {
  _AuthHarness._({required this.controller, required this.repository});

  final AuthController controller;
  final _ControlledAuthRepository repository;

  static Future<_AuthHarness> authenticated({
    _RemoteBehavior remoteBehavior = _RemoteBehavior.completeImmediately,
    Duration remoteTimeout = const Duration(seconds: 2),
  }) async {
    return _create(
      hasRestoredSession: true,
      remoteBehavior: remoteBehavior,
      remoteTimeout: remoteTimeout,
    );
  }

  static Future<_AuthHarness> unauthenticated() {
    return _create(
      hasRestoredSession: false,
      remoteBehavior: _RemoteBehavior.completeImmediately,
      remoteTimeout: const Duration(seconds: 2),
    );
  }

  static Future<_AuthHarness> _create({
    required bool hasRestoredSession,
    required _RemoteBehavior remoteBehavior,
    required Duration remoteTimeout,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _ControlledAuthRepository(
      apiClient,
      storage,
      hasRestoredSession: hasRestoredSession,
      remoteBehavior: remoteBehavior,
    );
    final coordinator = SessionTeardownCoordinator(
      auth: repository,
      clearLocalAccountData: () async {},
      clearGuestDraft: () async {},
      remoteTimeout: remoteTimeout,
    );
    final controller = AuthController(
      repository,
      sessionTeardownCoordinator: coordinator,
    );
    await controller.restoreSession();
    expect(
      controller.status,
      hasRestoredSession
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    return _AuthHarness._(controller: controller, repository: repository);
  }

  void dispose() {
    controller.dispose();
  }
}

class _ControlledAuthRepository extends AuthRepository {
  _ControlledAuthRepository(
    super.apiClient,
    super.authStorage, {
    required this.hasRestoredSession,
    required this.remoteBehavior,
  });

  static const _user = SafeUser(
    id: 'user-a',
    name: 'User A',
    role: 'USER',
    status: 'ACTIVE',
  );

  final bool hasRestoredSession;
  final _RemoteBehavior remoteBehavior;
  final Completer<void> _remoteRelease = Completer<void>();

  int loginCalls = 0;
  int registerCalls = 0;
  int loginOtpVerifyCalls = 0;
  int inviteOtpVerifyCalls = 0;
  bool localSessionCleared = false;
  bool remoteCancellationObserved = false;
  ApiException? loginFailure;

  @override
  SafeUser? readCachedUser() => hasRestoredSession ? _user : null;

  @override
  Future<String?> readAccessToken() async {
    return hasRestoredSession ? 'restored-access-token' : null;
  }

  @override
  Future<SafeUser> me() async => _user;

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    loginCalls += 1;
    final failure = loginFailure;
    if (failure != null) throw failure;
    return const AuthResponse(accessToken: 'access-token', user: _user);
  }

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
  }) async {
    registerCalls += 1;
    return const AuthResponse(accessToken: 'access-token', user: _user);
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    loginOtpVerifyCalls += 1;
    return const OtpVerifyResult(
      verified: true,
      phone: '+967700000003',
      purpose: 'LOGIN',
      user: _user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<OtpVerifyResult> verifyInviteOtp({
    required String token,
    required String phone,
    required String code,
    String? name,
    String? password,
  }) async {
    inviteOtpVerifyCalls += 1;
    return const OtpVerifyResult(
      verified: true,
      phone: '+967700000004',
      purpose: 'LOGIN',
      user: _user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  SessionAuthTeardownLease beginSessionTeardown(String userId) {
    return SessionAuthTeardownLease(userId: userId, storageEpoch: 1);
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {
    lease.captureCredentials(
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
    );
  }

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    localSessionCleared = true;
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {
    switch (remoteBehavior) {
      case _RemoteBehavior.completeImmediately:
        return;
      case _RemoteBehavior.blockUntilReleased:
        await _remoteRelease.future;
      case _RemoteBehavior.waitForCancellation:
        await cancelToken.whenCancel;
        remoteCancellationObserved = true;
    }
  }

  void releaseRemoteTeardown() {
    if (!_remoteRelease.isCompleted) {
      _remoteRelease.complete();
    }
  }
}
