import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/screens/account_context_selection_screen.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/account_context_entry_gate.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('01 single owner enters the owner dashboard state', (
    tester,
  ) async {
    final harness = await _Harness.create([_owner()]);
    addTearDown(harness.dispose);

    expect(harness.controller.selectedContext?.role, AccountContextRole.owner);
    expect(
      resolveAccountContextEntry(harness.controller),
      AccountContextEntryState.planDashboard,
    );
  });

  testWidgets('02 single contributor never opens an owner context', (
    tester,
  ) async {
    final harness = await _Harness.create([_contributor()]);
    addTearDown(harness.dispose);

    expect(
      harness.controller.selectedContext?.role,
      AccountContextRole.contributor,
    );
    expect(
      resolveAccountContextEntry(harness.controller),
      AccountContextEntryState.planDashboard,
    );
  });

  testWidgets(
    '02b contributor shell builds one workspace without tabs on Android',
    (tester) async {
      final contributor = _restrictedContributor();
      final harness = await _Harness.create([contributor]);
      addTearDown(harness.dispose);
      final apiClient = ApiClient(tokenProvider: () async => 'test-token');
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'controlled Android integration network failure',
            ),
          ),
        ),
      );
      final weddingPlansApi = WeddingPlansApi(apiClient);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountContextController>.value(
              value: harness.controller,
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  AuthController(AuthRepository(apiClient, harness.storage)),
            ),
            ChangeNotifierProvider(
              create: (_) => WeddingPlansProvider(weddingPlansApi),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  DashboardSummaryProvider(weddingPlansApi: weddingPlansApi),
            ),
          ],
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        harness.controller.selectedContext?.contextKey,
        contributor.contextKey,
      );
      expect(
        find.byKey(ValueKey('contributor-workspace-${contributor.contextKey}')),
        findsOneWidget,
      );
      expect(find.byType(PlanCenterScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(IndexedStack), findsNothing);
      expect(find.byKey(const ValueKey('contributor-tab-money')), findsNothing);
      expect(
        find.byKey(const ValueKey('contributor-tab-guests')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('contributor-tab-providers')),
        findsNothing,
      );
      expect(find.byType(WeddingPlanDashboardScreen), findsNothing);
      expect(find.byType(PlanShellChrome), findsNothing);
      expect(find.byType(TaskTimelineScreen), findsNothing);

      await tester.tap(find.byKey(const Key('contributor-account-action')));
      await tester.pumpAndSettle();

      expect(find.text('الخروج من المساحة'), findsOneWidget);
      expect(find.text('تسجيل الخروج من الحساب'), findsOneWidget);
      expect(
        harness.controller.selectedContext?.contextKey,
        contributor.contextKey,
      );
      expect(find.byType(WeddingPlanDashboardScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('03 multiple paths require explicit contributor selection', (
    tester,
  ) async {
    final harness = await _Harness.create([
      _owner(),
      _contributor(),
    ], allowInitialSingleContext: false);
    addTearDown(harness.dispose);

    expect(
      resolveAccountContextEntry(harness.controller),
      AccountContextEntryState.choosePath,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AccountContextController>.value(
          value: harness.controller,
          child: const AccountContextSelectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('account-path-option-plan:shared:contributor')),
    );
    await tester.pumpAndSettle();

    expect(
      harness.controller.selectedContext?.role,
      AccountContextRole.contributor,
    );
  });

  testWidgets('04 exiting contributor returns to path selection', (
    tester,
  ) async {
    final harness = await _Harness.create([
      _owner(),
      _contributor(),
    ], allowInitialSingleContext: false);
    addTearDown(harness.dispose);
    await harness.storage.saveSession(
      accessToken: 'session-token',
      refreshToken: 'refresh-token',
      user: _user('user-1'),
    );
    expect(await harness.controller.select(_contributor().contextKey), isTrue);

    await harness.controller.exitWorkspace();
    await harness.controller.refresh();

    expect(harness.controller.selectedContext, isNull);
    expect(harness.storage.readAccountContextKey(), isNull);
    expect(await harness.storage.readAccessToken(), 'session-token');
    expect(
      resolveAccountContextEntry(harness.controller),
      AccountContextEntryState.choosePath,
    );
  });

  testWidgets('05 a 403 preserves the contributor context', (tester) async {
    final harness = await _Harness.create([
      _owner(),
      _contributor(),
    ], allowInitialSingleContext: false);
    addTearDown(harness.dispose);
    await harness.controller.select(_contributor().contextKey);
    harness.gateway.onValidate = (_) async => throw const ApiException(
      'Forbidden',
      statusCode: 403,
      serverCode: 'FORBIDDEN',
    );

    final selected = await harness.controller.select(_owner().contextKey);

    expect(selected, isFalse);
    expect(
      harness.controller.selectedContext?.role,
      AccountContextRole.contributor,
    );
    expect(harness.controller.errorMessage, isNotNull);
  });

  testWidgets('06 restart restores the valid saved session and context', (
    tester,
  ) async {
    final storage = await _storage();
    await storage.saveSession(
      accessToken: 'session-token',
      refreshToken: 'refresh-token',
      user: _user('user-1'),
    );
    final first = await _Harness.create(
      [_owner(), _contributor()],
      storage: storage,
      allowInitialSingleContext: false,
    );
    await first.controller.select(_contributor().contextKey);
    first.dispose();

    final restarted = await _Harness.create(
      [_owner(), _contributor()],
      storage: storage,
      allowInitialSingleContext: false,
    );
    addTearDown(restarted.dispose);

    expect(await storage.readAccessToken(), 'session-token');
    expect(
      restarted.controller.selectedContext?.contextKey,
      _contributor().contextKey,
    );
  });

  testWidgets('07 revoked saved context is cleared without fallback', (
    tester,
  ) async {
    final harness = await _Harness.create([
      _owner(),
      _contributor(),
    ], allowInitialSingleContext: false);
    addTearDown(harness.dispose);
    await harness.controller.select(_contributor().contextKey);
    harness.gateway.contexts = [_owner()];

    await harness.controller.refresh();

    expect(harness.controller.selectedContext, isNull);
    expect(harness.storage.readAccountContextKey(), isNull);
    expect(harness.controller.selectionRequired, isTrue);
  });

  testWidgets('08 account logout clears session and selected context', (
    tester,
  ) async {
    final storage = await _storage();
    await storage.saveSession(
      accessToken: 'session-token',
      refreshToken: 'refresh-token',
      user: _user('user-1'),
    );
    final harness = await _Harness.create(
      [_owner(), _contributor()],
      storage: storage,
      allowInitialSingleContext: false,
    );
    addTearDown(harness.dispose);
    await harness.controller.select(_contributor().contextKey);

    await harness.controller.clearForLogout();
    await storage.clear();

    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
    expect(storage.readUser(), isNull);
    expect(storage.readAccountContextKey(), isNull);
    expect(harness.controller.selectedContext, isNull);
  });

  testWidgets('09 mismatched owner route is visibly blocked', (tester) async {
    final harness = await _Harness.create([
      _owner(),
      _contributor(),
    ], allowInitialSingleContext: false);
    addTearDown(harness.dispose);
    await harness.controller.select(_contributor().contextKey);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AccountContextController>.value(
          value: harness.controller,
          child: const WeddingPlanContextGate(
            weddingPlanId: 'owner',
            child: SizedBox(key: Key('forbidden-owner-content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('wedding-plan-context-mismatch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forbidden-owner-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('10 rapid reload and stale logout cannot win races', (
    tester,
  ) async {
    final storage = await _storage();
    await storage.saveSession(
      accessToken: 'old-token',
      refreshToken: 'old-refresh',
      user: _user('old-user'),
    );
    final harness = await _Harness.create(
      [_owner(), _contributor()],
      storage: storage,
      allowInitialSingleContext: false,
    );
    addTearDown(harness.dispose);
    await harness.controller.select(_owner().contextKey);

    final pendingReload = Completer<List<AccountContext>>();
    harness.gateway.onList = () => pendingReload.future;
    final staleReload = harness.controller.refresh();
    final latestSelection = harness.controller.select(
      _contributor().contextKey,
    );
    expect(await latestSelection, isTrue);
    pendingReload.complete([_owner(), _contributor()]);
    await staleReload;
    expect(
      harness.controller.selectedContext?.contextKey,
      _contributor().contextKey,
    );

    final staleLogoutEpoch = storage.beginSessionInvalidation();
    final newLoginEpoch = storage.beginSessionEstablishment();
    expect(
      await storage.saveSessionAtEpoch(
        expectedEpoch: newLoginEpoch,
        accessToken: 'new-token',
        refreshToken: 'new-refresh',
        user: _user('new-user'),
      ),
      isTrue,
    );
    expect(await storage.clearIfEpoch(staleLogoutEpoch), isFalse);
    expect(await storage.readAccessToken(), 'new-token');
    expect(storage.readUser()?.id, 'new-user');
  });
}

class _Harness {
  _Harness(this.storage, this.gateway, this.controller);

  final AuthStorage storage;
  final _MutableGateway gateway;
  final AccountContextController controller;

  static Future<_Harness> create(
    List<AccountContext> contexts, {
    AuthStorage? storage,
    bool allowInitialSingleContext = true,
  }) async {
    final resolvedStorage = storage ?? await _storage();
    final gateway = _MutableGateway(contexts);
    final controller = AccountContextController(
      contextsApi: gateway,
      authStorage: resolvedStorage,
      setActiveWeddingPlan: (_) async {},
    );
    await controller.refresh(
      allowInitialSingleContext: allowInitialSingleContext,
    );
    return _Harness(resolvedStorage, gateway, controller);
  }

  void dispose() => controller.dispose();
}

class _MutableGateway implements AccountContextsGateway {
  _MutableGateway(this.contexts);

  List<AccountContext> contexts;
  Future<List<AccountContext>> Function()? onList;
  Future<AccountContext> Function(String contextKey)? onValidate;

  @override
  Future<List<AccountContext>> listContexts() {
    return onList?.call() ?? Future.value(List.of(contexts));
  }

  @override
  Future<AccountContext> validateContext(String contextKey) {
    final handler = onValidate;
    if (handler != null) return handler(contextKey);
    return Future.value(
      contexts.firstWhere((context) => context.contextKey == contextKey),
    );
  }
}

Future<AuthStorage> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return AuthStorage(await SharedPreferences.getInstance());
}

SafeUser _user(String id) =>
    SafeUser(id: id, name: 'Smoke User', role: 'CUSTOMER', status: 'ACTIVE');

AccountContext _owner() => _context(
  contextKey: 'plan:owner:owner',
  role: AccountContextRole.owner,
  weddingPlanId: 'owner',
  displayName: 'عرسي',
);

AccountContext _contributor() => _context(
  contextKey: 'plan:shared:contributor',
  role: AccountContextRole.contributor,
  weddingPlanId: 'shared',
  displayName: 'عرس صديق',
);

AccountContext _restrictedContributor() => _context(
  contextKey: 'plan:shared-restricted:contributor',
  role: AccountContextRole.contributor,
  weddingPlanId: 'shared-restricted',
  displayName: 'مساحة مساهم محدودة',
  canManageGuests: false,
  canManageProviders: false,
  canInviteMembers: false,
  canViewMoney: false,
  canManageMoney: false,
);

AccountContext _context({
  required String contextKey,
  required AccountContextRole role,
  required String weddingPlanId,
  required String displayName,
  bool canManageGuests = true,
  bool canManageProviders = true,
  bool canInviteMembers = true,
  bool canViewMoney = true,
  bool canManageMoney = true,
}) {
  return AccountContext(
    contextKey: contextKey,
    role: role,
    weddingPlanId: weddingPlanId,
    providerId: null,
    persona: null,
    displayName: displayName,
    lifecycle: 'PLANNING',
    accessMode: AccountContextAccessMode.full,
    capabilities: const AccountContextCapabilities(
      canViewProviderProfile: false,
      canManageProviderProfile: false,
      canUseProviderOperations: false,
    ),
    permissions: AccountContextPermissions(
      canViewPlan: true,
      canEditPlan: true,
      canManageTasks: true,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canViewMoney: canViewMoney,
      canManageMoney: canManageMoney,
      canManageProviderProfile: false,
    ),
    isAvailable: true,
    unavailableReason: null,
  );
}
