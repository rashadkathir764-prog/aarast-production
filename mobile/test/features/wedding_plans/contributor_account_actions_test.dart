import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'exit workspace preserves account session and opens path choice',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await tester.tap(find.byKey(const Key('contributor-account-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contributor-exit-workspace')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(harness.contexts.selectedContext, isNull);
      expect(harness.storage.readAccountContextKey(), isNull);
      expect(await harness.storage.readAccessToken(), 'session-token');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account logout clears session and opens login', (tester) async {
    final harness = await _ContributorActionHarness.create();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('contributor-account-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contributor-logout-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contributor-logout-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-destination')), findsOneWidget);
    expect(harness.storage.readAccountContextKey(), isNull);
    expect(await harness.storage.readAccessToken(), isNull);
    expect(await harness.storage.readRefreshToken(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resuming the contributor workspace refreshes account-context authority',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);
      final callsBeforeResume = harness.contextsGateway.listCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(harness.contextsGateway.listCalls, greaterThan(callsBeforeResume));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guarded contributor center refreshes once without a remount loop',
    (tester) async {
      final harness = await _ContributorActionHarness.create(
        initialLocation: '/guarded-workspace',
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      final callsBeforeResume = harness.contextsGateway.listCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(harness.contextsGateway.listCalls, callsBeforeResume + 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ContributorActionHarness {
  _ContributorActionHarness({
    required this.storage,
    required this.contextsGateway,
    required this.contexts,
    required this.auth,
    required this.weddingPlans,
    required this.dashboard,
    required this.router,
  });

  final AuthStorage storage;
  final _ContextsGateway contextsGateway;
  final AccountContextController contexts;
  final AuthController auth;
  final WeddingPlansProvider weddingPlans;
  final DashboardSummaryProvider dashboard;
  final GoRouter router;

  static Future<_ContributorActionHarness> create({
    String initialLocation = '/workspace',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    await storage.saveSession(
      accessToken: 'session-token',
      refreshToken: 'refresh-token',
      user: const SafeUser(
        id: 'contributor-user',
        name: 'مساهم',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );

    final contributor = accountContext(
      role: AccountContextRole.contributor,
      planId: 'shared-plan',
    );
    final owner = accountContext(
      role: AccountContextRole.owner,
      planId: 'owner-plan',
    );
    final contextsGateway = _ContextsGateway([owner, contributor]);
    final contexts = AccountContextController(
      contextsApi: contextsGateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    await contexts.refresh();
    expect(await contexts.select(contributor.contextKey), isTrue);

    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'controlled contributor action test failure',
          ),
        ),
      ),
    );
    final weddingPlansApi = WeddingPlansApi(apiClient);
    final auth = AuthController(_ContributorAuthRepository(apiClient, storage));
    await auth.restoreSession();
    final weddingPlans = WeddingPlansProvider(weddingPlansApi);
    final dashboard = DashboardSummaryProvider(
      weddingPlansApi: weddingPlansApi,
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/workspace', builder: (_, _) => const MainShell()),
        GoRoute(
          path: '/guarded-workspace',
          builder: (_, _) => const WeddingPlanContextGate(
            weddingPlanId: 'shared-plan',
            child: PlanCenterScreen(weddingPlanId: 'shared-plan'),
          ),
        ),
        GoRoute(
          path: AppRouter.home,
          builder: (_, _) =>
              const SizedBox(key: Key('path-choice-destination')),
        ),
        GoRoute(
          path: AppRouter.login,
          builder: (_, _) => const SizedBox(key: Key('login-destination')),
        ),
      ],
    );

    return _ContributorActionHarness(
      storage: storage,
      contextsGateway: contextsGateway,
      contexts: contexts,
      auth: auth,
      weddingPlans: weddingPlans,
      dashboard: dashboard,
      router: router,
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountContextController>.value(
            value: contexts,
          ),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<WeddingPlansProvider>.value(
            value: weddingPlans,
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => AarastAuthFlowRedirector(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    router.dispose();
    dashboard.dispose();
    weddingPlans.dispose();
    auth.dispose();
    contexts.dispose();
  }
}

class _ContextsGateway implements AccountContextsGateway {
  _ContextsGateway(this.contexts);

  final List<AccountContext> contexts;
  int listCalls = 0;

  @override
  Future<List<AccountContext>> listContexts() async {
    listCalls += 1;
    return contexts;
  }

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.singleWhere((context) => context.contextKey == contextKey);
  }
}

class _ContributorAuthRepository extends AuthRepository {
  _ContributorAuthRepository(super.apiClient, super.authStorage);

  static const _user = SafeUser(
    id: 'contributor-user',
    name: 'مساهم',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<String?> readAccessToken() async => 'session-token';

  @override
  Future<SafeUser> me() async => _user;

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {}
}
