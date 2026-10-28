import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checking state never builds an account dashboard', (
    tester,
  ) async {
    final harness = await _Harness.create();

    await tester.pumpWidget(_app(harness.controller));

    expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
    expect(find.byKey(const Key('session-checking-screen')), findsOneWidget);
  });

  testWidgets('removes the old dashboard in the first terminating frame', (
    tester,
  ) async {
    final harness = await _Harness.create();
    final localClear = Completer<void>();
    harness.repository.localClear = () => localClear.future;
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);

    final logout = harness.controller.logout();
    await tester.pump();

    expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
    expect(find.byKey(const Key('session-terminating-screen')), findsOneWidget);

    localClear.complete();
    await logout;
    await tester.pump();
  });

  testWidgets('explicit logout preserves the installation guest draft', (
    tester,
  ) async {
    final harness = await _Harness.create();
    var guestDraftClearCalls = 0;
    final controller = AuthController(
      harness.repository,
      sessionTeardownCoordinator: SessionTeardownCoordinator(
        auth: harness.repository,
        clearLocalAccountData: () async {},
        clearGuestDraft: () async {
          guestDraftClearCalls += 1;
        },
      ),
    );
    await controller.restoreSession();

    await controller.logout();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(guestDraftClearCalls, 0);
  });

  testWidgets(
    'confirmed session expiry preserves the installation guest draft',
    (tester) async {
      final harness = await _Harness.create();
      var guestDraftClearCalls = 0;
      final controller = AuthController(
        harness.repository,
        sessionTeardownCoordinator: SessionTeardownCoordinator(
          auth: harness.repository,
          clearLocalAccountData: () async {},
          clearGuestDraft: () async {
            guestDraftClearCalls += 1;
          },
        ),
      );
      await controller.restoreSession();

      await controller.handleSessionExpired();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.sessionExpired, isTrue);
      expect(guestDraftClearCalls, 0);
    },
  );

  testWidgets('restore rejection preserves the installation guest draft', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.repository.meFailure = const ApiException(
      'session rejected',
      statusCode: 401,
    );
    var guestDraftClearCalls = 0;
    final controller = AuthController(
      harness.repository,
      sessionTeardownCoordinator: SessionTeardownCoordinator(
        auth: harness.repository,
        clearLocalAccountData: () async {},
        clearGuestDraft: () async {
          guestDraftClearCalls += 1;
        },
      ),
    );

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(guestDraftClearCalls, 0);
  });

  testWidgets('local cleanup failure exposes a safe retry action', (
    tester,
  ) async {
    final harness = await _Harness.create();
    var shouldFail = true;
    final coordinator = SessionTeardownCoordinator(
      auth: harness.repository,
      clearLocalAccountData: () async {
        if (shouldFail) throw StateError('database locked');
      },
      clearGuestDraft: () async {},
    );
    final controller = AuthController(
      harness.repository,
      sessionTeardownCoordinator: coordinator,
    );
    await controller.restoreSession();
    await tester.pumpWidget(_app(controller));

    await controller.logout();
    await tester.pump();

    expect(
      find.byKey(const Key('session-termination-failed-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);

    shouldFail = false;
    await tester.tap(find.byKey(const Key('session-termination-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('session-termination-failed-screen')),
      findsNothing,
    );
    expect(controller.status, AuthStatus.unauthenticated);
  });

  // D63: deleting the account asks for it; the session stays and only w06
  // shows until the request is taken back or the account is erased.
  testWidgets('w05: the request keeps the session and shows only w06', (
    tester,
  ) async {
    final harness = await _Harness.create();
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);

    expect(await harness.controller.requestAccountDeletion(), isNull);
    await tester.pumpAndSettle();

    expect(harness.repository.requestCalls, 1);
    expect(harness.repository.remoteRevokeCalls, 0);
    expect(harness.controller.status, AuthStatus.authenticated);
    expect(harness.controller.deletionPending, isTrue);
    expect(
      harness.controller.user?.deletionScheduledFor,
      _SessionRepository.scheduledFor,
    );
    expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
    expect(find.byKey(const Key('deletion-pending-screen')), findsOneWidget);
    expect(find.text('حسابك ينحذف بعد 30 يوم'), findsOneWidget);
  });

  testWidgets('w06 «تراجعت، رجّع حسابي» brings the account back', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.repository.pending = true;
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));
    expect(find.byKey(const Key('deletion-pending-screen')), findsOneWidget);

    harness.repository.pending = false;
    await tester.tap(find.byKey(const Key('deletion-pending-restore')));
    await tester.pumpAndSettle();

    expect(harness.repository.cancelCalls, 1);
    expect(harness.controller.deletionPending, isFalse);
    expect(find.byKey(const Key('deletion-pending-screen')), findsNothing);
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);
  });

  testWidgets('a refused take-back stays on w06 and says why', (tester) async {
    final harness = await _Harness.create();
    harness.repository
      ..pending = true
      ..cancelFailure = const ApiException(
        'ما قدرنا نوصل للسيرفر.',
        isNetworkFailure: true,
      );
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));

    await tester.tap(find.byKey(const Key('deletion-pending-restore')));
    await tester.pumpAndSettle();

    expect(harness.controller.deletionPending, isTrue);
    expect(find.byKey(const Key('deletion-pending-error')), findsOneWidget);
    expect(find.text('ما قدرنا نوصل للسيرفر.'), findsOneWidget);
  });

  testWidgets('B-33: a refused request keeps the account as it was', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.repository.requestFailure = const ApiException(
      'عندك حجوزات مؤكدة جاية. الغها أو سلّمها قبل ما تحذف حسابك.',
      statusCode: 409,
      serverCode: 'PROVIDER_HAS_UPCOMING_BOOKINGS',
    );
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));

    final error = await harness.controller.requestAccountDeletion();
    await tester.pump();

    expect(error, contains('حجوزات'));
    expect(harness.controller.deletionPending, isFalse);
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);
  });

  testWidgets(
    'a01: signing in to a waiting account lands on w06 and sends nothing',
    (tester) async {
      final harness = await _Harness.create();
      harness.repository.pending = true;

      await harness.controller.restoreSession();
      await tester.pumpWidget(_app(harness.controller));

      expect(harness.controller.status, AuthStatus.authenticated);
      expect(find.byKey(const Key('deletion-pending-screen')), findsOneWidget);
      expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
    },
  );

  testWidgets('a 403 ACCOUNT_DELETION_PENDING from another phone shows w06', (
    tester,
  ) async {
    final harness = await _Harness.create();
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);

    harness.repository.pending = true;
    await harness.controller.handleAccountDeletionPending();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deletion-pending-screen')), findsOneWidget);
  });
}

Widget _app(AuthController controller) {
  return ChangeNotifierProvider<AuthController>.value(
    value: controller,
    child: const MaterialApp(
      home: AarastSessionTransitionGate(
        child: AarastDeletionPendingGate(
          child: ColoredBox(
            key: Key('old-provider-dashboard'),
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

class _Harness {
  const _Harness({required this.controller, required this.repository});

  final AuthController controller;
  final _SessionRepository repository;

  static Future<_Harness> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _SessionRepository(apiClient, storage);
    return _Harness(
      controller: AuthController(
        repository,
        sessionTeardownCoordinator: SessionTeardownCoordinator(
          auth: repository,
          clearLocalAccountData: () async {},
          clearGuestDraft: () async {},
        ),
      ),
      repository: repository,
    );
  }
}

class _SessionRepository extends AuthRepository {
  _SessionRepository(super.apiClient, super.authStorage);

  static const user = SafeUser(
    id: 'user-a',
    name: 'User A',
    role: 'USER',
    status: 'ACTIVE',
  );
  static final requestedAt = DateTime.now();
  static final scheduledFor = requestedAt.add(const Duration(days: 30));

  Future<void> Function() localClear = _completeImmediately;
  int remoteRevokeCalls = 0;
  int requestCalls = 0;
  int cancelCalls = 0;
  bool pending = false;
  Object? meFailure;
  Object? requestFailure;
  Object? cancelFailure;

  SafeUser get _current => pending
      ? user.withDeletion(requestedAt: requestedAt, scheduledFor: scheduledFor)
      : user;

  @override
  SafeUser? readCachedUser() => _current;

  @override
  Future<String?> readAccessToken() async => 'access-a';

  @override
  Future<SafeUser> me() async {
    final failure = meFailure;
    if (failure != null) throw failure;
    return _current;
  }

  @override
  Future<({DateTime requestedAt, DateTime scheduledFor})>
  requestAccountDeletion() async {
    requestCalls += 1;
    final failure = requestFailure;
    if (failure != null) throw failure;
    pending = true;
    return (requestedAt: requestedAt, scheduledFor: scheduledFor);
  }

  @override
  Future<void> cancelAccountDeletion() async {
    cancelCalls += 1;
    final failure = cancelFailure;
    if (failure != null) throw failure;
    pending = false;
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) {
    return localClear();
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {
    remoteRevokeCalls += 1;
  }
}

Future<void> _completeImmediately() async {}
