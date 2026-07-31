import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
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
      controller: AuthController(repository),
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

  Future<void> Function() localClear = _completeImmediately;

  @override
  SafeUser? readCachedUser() => user;

  @override
  Future<String?> readAccessToken() async => 'access-a';

  @override
  Future<SafeUser> me() async => user;

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) {
    return localClear();
  }
}

Future<void> _completeImmediately() async {}
