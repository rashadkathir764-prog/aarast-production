import 'dart:async';
import 'dart:convert';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
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

    // RA-MO-99: «نسيت الرمز» on the app lock was a chosen sign-out, which
    // wipes what was not sent, under a sheet that says «بياناتك محفوظة».
    test('forgetting the app lock code signs out and keeps what was not '
        'sent', () async {
      final harness = await _AuthHarness.authenticated();
      addTearDown(harness.dispose);

      await harness.controller.signOutForgottenAppLockCode();

      expect(harness.localClears, ['keeping unsent']);
      expect(harness.controller.status, AuthStatus.unauthenticated);
      expect(harness.controller.user, isNull);
      // Not an expired session: no «انتهت جلستك», and the door asks to
      // sign in.
      expect(harness.controller.sessionExpired, isFalse);
      expect(harness.controller.errorMessage, isNull);
      expect(harness.controller.loginRequestedAfterLogout, isTrue);
    });

    // RA-MO-134: the account moves to a new number and stays the same
    // account, under a sheet that says «خطتك ومشاركينك يبقون مثل ما هم».
    // The sign-out it forces was wiping what had not been sent.
    test('changing the number signs out and keeps what was not sent', () async {
      final harness = await _AuthHarness.authenticated(unsentChanges: 2);
      addTearDown(harness.dispose);

      final error = await harness.controller.confirmPhoneChange(
        '777000999',
        '123456',
      );

      expect(error, isNull);
      expect(harness.localClears, ['keeping unsent']);
      expect(harness.controller.status, AuthStatus.unauthenticated);
      expect(harness.controller.loginRequestedAfterLogout, isTrue);
      expect(harness.controller.sessionExpired, isFalse);
    });

    // RA-MO-98: an invite opened with another number signs the phone in as
    // that account, and the phone then drops the first account's unsent
    // changes without a word.
    test('an invite with another number is refused while this account has '
        'unsent changes, before any code is sent or checked', () async {
      final harness = await _AuthHarness.authenticated(unsentChanges: 1);
      addTearDown(harness.dispose);
      final token = List.filled(43, 'a').join();

      final sent = await harness.controller.requestInviteOtp(
        token: token,
        phone: '+967700000009',
      );
      expect(sent, isNull);
      expect(harness.repository.inviteOtpRequestCalls, 0);
      expect(harness.controller.errorCode, 'INVITE_SWITCH_WOULD_DROP_UNSENT');
      expect(harness.controller.errorMessage, contains('لسا ما انرسلت'));

      final verified = await harness.controller.verifyOtp(
        phone: '+967700000009',
        purpose: 'LOGIN',
        code: '123456',
        resumeInviteToken: token,
      );
      expect(verified, isFalse);
      expect(harness.repository.inviteOtpVerifyCalls, 0);
      expect(harness.controller.user?.id, 'user-a', reason: 'still signed in');
    });

    test('with nothing unsent the invite goes on as before', () async {
      final harness = await _AuthHarness.authenticated();
      addTearDown(harness.dispose);

      final verified = await harness.controller.verifyOtp(
        phone: '+967700000009',
        purpose: 'LOGIN',
        code: '123456',
        resumeInviteToken: List.filled(43, 'a').join(),
      );

      expect(verified, isTrue);
      expect(harness.repository.inviteOtpVerifyCalls, 1);
    });

    test('a sign-out the person chose still clears everything', () async {
      final harness = await _AuthHarness.authenticated();
      addTearDown(harness.dispose);

      await harness.controller.logout();

      expect(harness.localClears, ['everything']);
    });
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
  _AuthHarness._({
    required this.controller,
    required this.repository,
    required this.localClears,
  });

  final AuthController controller;
  final _ControlledAuthRepository repository;

  /// Which clearing of the phone's account data each sign-out ran.
  final List<String> localClears;

  static Future<_AuthHarness> authenticated({
    _RemoteBehavior remoteBehavior = _RemoteBehavior.completeImmediately,
    Duration remoteTimeout = const Duration(seconds: 2),
    int unsentChanges = 0,
  }) async {
    return _create(
      hasRestoredSession: true,
      remoteBehavior: remoteBehavior,
      remoteTimeout: remoteTimeout,
      unsentChanges: unsentChanges,
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
    int unsentChanges = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    OfflineSyncService? offline;
    if (unsentChanges > 0) {
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      offline = OfflineSyncService(database: database, apiClient: apiClient);
      for (var index = 0; index < unsentChanges; index++) {
        await database.enqueueSync(
          entityType: 'guest',
          operation: 'create',
          endpoint: '/api/v1/wedding-plans/p1/guests',
          method: 'POST',
          payload: {'name': 'ضيف $index'},
          planId: 'p1',
          localEntityId: 'queued-guest-$index',
        );
      }
      await offline.refreshStatus();
    }
    final repository = _ControlledAuthRepository(
      apiClient,
      storage,
      hasRestoredSession: hasRestoredSession,
      remoteBehavior: remoteBehavior,
    );
    final localClears = <String>[];
    final coordinator = SessionTeardownCoordinator(
      auth: repository,
      clearLocalAccountData: () async => localClears.add('everything'),
      clearLocalAccountDataKeepingUnsent: () async =>
          localClears.add('keeping unsent'),
      clearGuestDraft: () async {},
      remoteTimeout: remoteTimeout,
    );
    final controller = AuthController(
      repository,
      sessionTeardownCoordinator: coordinator,
      offlineSyncService: offline,
    );
    await controller.restoreSession();
    expect(
      controller.status,
      hasRestoredSession
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    return _AuthHarness._(
      controller: controller,
      repository: repository,
      localClears: localClears,
    );
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
  int inviteOtpRequestCalls = 0;
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
  Future<void> confirmPhoneChange(String newPhone, String code) async {}

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
    String? otpCode,
    String? phoneProof,
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
  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    inviteOtpRequestCalls += 1;
    throw StateError('no invite code should be requested in this test');
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
