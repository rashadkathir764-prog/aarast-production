import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_boundary.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/account_context_entry_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  testWidgets(
    'provider logout then same-user groom login never rebuilds provider dashboard',
    runProviderToGroomSessionScenario,
  );
}

Future<void> runProviderToGroomSessionScenario(WidgetTester tester) async {
  final harness = await _ScenarioHarness.create();
  addTearDown(harness.controller.dispose);
  await tester.pumpWidget(harness.app);

  expect(
    await harness.controller.login(
      phone: '+967700000001',
      password: 'password',
    ),
    isTrue,
  );
  await _flushAsyncFrames(tester);

  expect(find.byKey(const Key('provider-dashboard')), findsOneWidget);
  expect(harness.providerDashboardBuilds, 1);

  final localClear = harness.blockNextLocalClear();
  final logout = harness.controller.logout();
  await tester.pump();

  expect(harness.controller.status, AuthStatus.terminating);
  expect(find.byKey(const Key('provider-dashboard')), findsNothing);
  expect(find.byKey(const Key('session-terminating-screen')), findsOneWidget);

  localClear.complete();
  await logout;
  await _flushAsyncFrames(tester);
  expect(find.byKey(const Key('signed-out-surface')), findsOneWidget);

  expect(
    await harness.controller.login(
      phone: '+967700000001',
      password: 'password',
    ),
    isTrue,
  );
  await _flushAsyncFrames(tester);

  expect(find.byKey(const Key('role-chooser')), findsOneWidget);
  expect(find.byKey(const Key('provider-dashboard')), findsNothing);
  expect(harness.providerDashboardBuilds, 1);

  final selected = await harness.currentContexts!.select(
    harness.ownerContext.contextKey,
  );
  expect(selected, isTrue);
  await _flushAsyncFrames(tester);

  expect(find.byKey(const Key('groom-dashboard')), findsOneWidget);
  expect(find.byKey(const Key('provider-dashboard')), findsNothing);
  expect(harness.providerDashboardBuilds, 1);
  expect(harness.groomDashboardBuilds, 1);
}

Future<void> _flushAsyncFrames(WidgetTester tester) async {
  for (var index = 0; index < 12; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

class _ScenarioHarness {
  _ScenarioHarness._({
    required this.controller,
    required this.storage,
    required this.repository,
    required this.providerContext,
    required this.ownerContext,
  });

  final AuthController controller;
  final AuthStorage storage;
  final _ScenarioAuthRepository repository;
  final AccountContext providerContext;
  final AccountContext ownerContext;
  AccountContextController? currentContexts;
  int providerDashboardBuilds = 0;
  int groomDashboardBuilds = 0;

  static Future<_ScenarioHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _ScenarioAuthRepository(apiClient, storage);
    final coordinator = SessionTeardownCoordinator(
      auth: repository,
      clearLocalAccountData: () async {},
      clearGuestDraft: () async {},
    );
    final controller = AuthController(
      repository,
      sessionTeardownCoordinator: coordinator,
    );
    await controller.restoreSession();
    return _ScenarioHarness._(
      controller: controller,
      storage: storage,
      repository: repository,
      providerContext: accountContext(role: AccountContextRole.provider),
      ownerContext: accountContext(role: AccountContextRole.owner),
    );
  }

  Completer<void> blockNextLocalClear() => repository.blockNextLocalClear();

  Widget get app {
    return ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp(
        home: AarastSessionTransitionGate(
          child: _ScenarioSessionBoundary(harness: this),
        ),
      ),
    );
  }

  List<AccountContext> contextsForCurrentLogin() {
    return repository.loginCalls == 1
        ? [providerContext]
        : [providerContext, ownerContext];
  }
}

class _ScenarioSessionBoundary extends StatelessWidget {
  const _ScenarioSessionBoundary({required this.harness});

  final _ScenarioHarness harness;

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthController, String?>(
      (auth) => auth.user?.id,
    );
    if (userId == null) {
      return const SizedBox(key: Key('signed-out-surface'));
    }

    return AarastSessionBoundary(
      identity: 'account:$userId',
      builder: (_) => ChangeNotifierProvider<AccountContextController>(
        create: (_) {
          final controller = AccountContextController(
            contextsApi: _ScenarioContextsGateway(
              harness.contextsForCurrentLogin(),
            ),
            authStorage: harness.storage,
            userId: userId,
            setActiveWeddingPlan: (_) async {},
          );
          harness.currentContexts = controller;
          unawaited(controller.refresh(allowInitialSingleContext: true));
          return controller;
        },
        child: _ScenarioRoleSurface(harness: harness),
      ),
    );
  }
}

class _ScenarioRoleSurface extends StatelessWidget {
  const _ScenarioRoleSurface({required this.harness});

  final _ScenarioHarness harness;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    return switch (resolveAccountContextEntry(controller)) {
      AccountContextEntryState.providerDashboard => _BuildCounter(
        key: const Key('provider-dashboard'),
        onBuilt: () => harness.providerDashboardBuilds += 1,
      ),
      AccountContextEntryState.planDashboard => _BuildCounter(
        key: const Key('groom-dashboard'),
        onBuilt: () => harness.groomDashboardBuilds += 1,
      ),
      AccountContextEntryState.choosePath => const SizedBox(
        key: Key('role-chooser'),
      ),
      _ => const SizedBox(key: Key('role-loading')),
    };
  }
}

class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.onBuilt, super.key});

  final VoidCallback onBuilt;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  void initState() {
    super.initState();
    widget.onBuilt();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _ScenarioContextsGateway implements AccountContextsGateway {
  const _ScenarioContextsGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}

class _ScenarioAuthRepository extends AuthRepository {
  _ScenarioAuthRepository(ApiClient apiClient, this.storage)
    : super(apiClient, storage);

  static const user = SafeUser(
    id: 'shared-user',
    name: 'Shared User',
    role: 'USER',
    status: 'ACTIVE',
  );

  final AuthStorage storage;
  Completer<void>? _localClearBlocker;
  int loginCalls = 0;

  Completer<void> blockNextLocalClear() {
    final blocker = Completer<void>();
    _localClearBlocker = blocker;
    return blocker;
  }

  @override
  SafeUser? readCachedUser() => null;

  @override
  Future<String?> readAccessToken() => storage.readAccessToken();

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    loginCalls += 1;
    await storage.saveSession(
      accessToken: 'access-$loginCalls',
      refreshToken: 'refresh-$loginCalls',
      user: user,
    );
    return const AuthResponse(accessToken: 'access', user: user);
  }

  @override
  SessionAuthTeardownLease beginSessionTeardown(String userId) {
    return SessionAuthTeardownLease(
      userId: userId,
      storageEpoch: storage.beginSessionInvalidation(),
    );
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {
    lease.captureCredentials(
      accessToken: await storage.readAccessTokenIfEpoch(lease.storageEpoch),
      refreshToken: await storage.readRefreshTokenIfEpoch(lease.storageEpoch),
    );
  }

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    final blocker = _localClearBlocker;
    _localClearBlocker = null;
    if (blocker != null) await blocker.future;
    final cleared = await storage.clearTerminatingSessionAtEpoch(
      lease.storageEpoch,
    );
    if (!cleared) throw StateError('stale teardown epoch');
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {}
}
