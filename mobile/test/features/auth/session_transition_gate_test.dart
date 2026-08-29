import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/pending_account_deletion.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
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
      pendingAccountDeletionStore: harness.deletionStore,
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
        pendingAccountDeletionStore: harness.deletionStore,
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
      pendingAccountDeletionStore: harness.deletionStore,
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
      pendingAccountDeletionStore: harness.deletionStore,
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

  testWidgets(
    'server-confirmed account deletion enters teardown boundary before local clear',
    (tester) async {
      final harness = await _Harness.create();
      final localAccountClear = Completer<void>();
      var guestDraftClearCalls = 0;
      final coordinator = SessionTeardownCoordinator(
        auth: harness.repository,
        clearLocalAccountData: () => localAccountClear.future,
        clearGuestDraft: () async {
          guestDraftClearCalls += 1;
        },
        clearDeletedAccountState: harness.deletionStore.removeForDeletedUser,
      );
      final controller = AuthController(
        harness.repository,
        sessionTeardownCoordinator: coordinator,
        pendingAccountDeletionStore: harness.deletionStore,
      );
      await controller.restoreSession();
      await tester.pumpWidget(_app(controller));

      final deletion = controller.deleteAccount();
      await tester.pump();

      expect(harness.repository.deleteAccountCalls, 1);
      expect(controller.user, isNull);
      expect(controller.status, AuthStatus.terminating);
      expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
      expect(find.byKey(const Key('session-terminating-screen')), findsOne);

      localAccountClear.complete();
      expect(await deletion, isTrue);
      await tester.pumpAndSettle();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(harness.repository.remoteRevokeCalls, 0);
      expect(guestDraftClearCalls, 1);
    },
  );

  testWidgets(
    'account deletion local failure stays gated and retry never deletes twice',
    (tester) async {
      final harness = await _Harness.create();
      var shouldFailLocalClear = true;
      final coordinator = SessionTeardownCoordinator(
        auth: harness.repository,
        clearLocalAccountData: () async {
          if (shouldFailLocalClear) {
            throw StateError('controlled account-cache clear failure');
          }
        },
        clearGuestDraft: () async {},
        clearDeletedAccountState: harness.deletionStore.removeForDeletedUser,
      );
      final controller = AuthController(
        harness.repository,
        sessionTeardownCoordinator: coordinator,
        pendingAccountDeletionStore: harness.deletionStore,
      );
      await controller.restoreSession();
      await tester.pumpWidget(_app(controller));

      expect(await controller.deleteAccount(), isFalse);
      await tester.pump();

      expect(harness.repository.deleteAccountCalls, 1);
      expect(harness.repository.remoteRevokeCalls, 0);
      expect(controller.user, isNull);
      expect(controller.status, AuthStatus.terminationFailed);
      expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
      expect(
        find.byKey(const Key('session-termination-failed-screen')),
        findsOneWidget,
      );

      shouldFailLocalClear = false;
      await tester.tap(find.byKey(const Key('session-termination-retry')));
      await tester.pumpAndSettle();

      expect(harness.repository.deleteAccountCalls, 1);
      expect(harness.repository.remoteRevokeCalls, 0);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(
        find.byKey(const Key('session-termination-failed-screen')),
        findsNothing,
      );
    },
  );

  testWidgets('definitive NOT_STARTED rejection restores the same session', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.repository.deleteAccountFailure = const ApiException(
      'تعذر حذف الحساب الآن.',
      statusCode: 403,
      serverCode: 'ACCOUNT_DELETE_UNAVAILABLE',
    );
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));

    expect(await harness.controller.deleteAccount(), isFalse);
    await tester.pump();

    expect(harness.repository.deleteAccountCalls, 1);
    expect(harness.controller.status, AuthStatus.authenticated);
    expect(harness.controller.user, _SessionRepository.user);
    expect(find.byKey(const Key('old-provider-dashboard')), findsOneWidget);
    expect(harness.controller.errorCode, 'ACCOUNT_DELETE_UNAVAILABLE');
  });

  testWidgets('lost deletion response stays gated and retries the same id', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.repository
      ..deleteAccountFailure = const ApiException(
        'network lost',
        isNetworkFailure: true,
      )
      ..deletionStatus = AccountDeletionServerStatus.pending;
    await harness.controller.restoreSession();
    await tester.pumpWidget(_app(harness.controller));

    expect(await harness.controller.deleteAccount(), isFalse);
    await tester.pump();

    expect(harness.controller.user, isNull);
    expect(harness.controller.status, AuthStatus.terminationFailed);
    expect(find.byKey(const Key('old-provider-dashboard')), findsNothing);
    expect(find.text('جارٍ التحقق من حذف الحساب'), findsOneWidget);
    final firstId = harness.repository.deletionRequestIds.first;
    expect(harness.repository.deletionRequestIds, [firstId]);
    expect(await harness.deletionStore.read(), isNotNull);

    await harness.controller.logout();
    expect(harness.repository.deletionRequestIds, [firstId]);
    expect(await harness.deletionStore.read(), isNotNull);

    harness.repository
      ..deleteAccountFailure = null
      ..deletionStatus = AccountDeletionServerStatus.notStarted;
    await harness.controller.logout();
    expect(harness.repository.deletionRequestIds, [firstId, firstId]);
    expect(await harness.deletionStore.read(), isNull);
    expect(harness.controller.status, AuthStatus.unauthenticated);
  });

  test(
    'restart reconciles DELETED receipt before restoring a dashboard',
    () async {
      final harness = await _Harness.create();
      await harness.deletionStore.putIfAbsent(_SessionRepository.user.id);
      harness.repository.deletionStatus = AccountDeletionServerStatus.deleted;

      await harness.controller.restoreSession();

      expect(harness.controller.user, isNull);
      expect(harness.controller.status, AuthStatus.unauthenticated);
      expect(await harness.deletionStore.read(), isNull);
      expect(harness.repository.deleteAccountCalls, 0);
    },
  );
}

Widget _app(AuthController controller) {
  return ChangeNotifierProvider<AuthController>.value(
    value: controller,
    child: const MaterialApp(
      home: AarastSessionTransitionGate(
        child: ColoredBox(
          key: Key('old-provider-dashboard'),
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _Harness {
  const _Harness({
    required this.controller,
    required this.repository,
    required this.deletionStore,
  });

  final AuthController controller;
  final _SessionRepository repository;
  final PendingAccountDeletionStore deletionStore;

  static Future<_Harness> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _SessionRepository(apiClient, storage);
    final deletionStore = PendingAccountDeletionStore(_MemoryVault());
    return _Harness(
      controller: AuthController(
        repository,
        pendingAccountDeletionStore: deletionStore,
        sessionTeardownCoordinator: SessionTeardownCoordinator(
          auth: repository,
          clearLocalAccountData: () async {},
          clearGuestDraft: () async {},
          clearDeletedAccountState: deletionStore.removeForDeletedUser,
        ),
      ),
      repository: repository,
      deletionStore: deletionStore,
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

  Future<void> Function() localClear = _completeImmediately;
  int deleteAccountCalls = 0;
  int remoteRevokeCalls = 0;
  Object? deleteAccountFailure;
  Object? meFailure;
  AccountDeletionServerStatus deletionStatus =
      AccountDeletionServerStatus.notStarted;
  final List<String> deletionRequestIds = [];

  @override
  SafeUser? readCachedUser() => user;

  @override
  Future<String?> readAccessToken() async => 'access-a';

  @override
  Future<SafeUser> me() async {
    final failure = meFailure;
    if (failure != null) throw failure;
    return user;
  }

  @override
  Future<void> deleteAccount({required String clientRequestId}) async {
    deleteAccountCalls += 1;
    deletionRequestIds.add(clientRequestId);
    final failure = deleteAccountFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<AccountDeletionServerStatus> accountDeletionStatus({
    required String userId,
    required String clientRequestId,
  }) async => deletionStatus;

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

class _MemoryVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
