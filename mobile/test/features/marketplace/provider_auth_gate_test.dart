import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'providers marketplace route is public for guest users (Phase 3)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = AuthController(authRepository)..restoreSession();
      final router = GoRouter(
        initialLocation: AppRouter.providerMarketplace,
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
          // Phase 3 contract: browsing /providers is public — no auth gate.
          GoRoute(
            path: AppRouter.providerMarketplace,
            builder: (context, state) =>
                const Scaffold(body: Text('providers-opened')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provider-auth-gate')), findsNothing);
      expect(find.text('providers-opened'), findsOneWidget);
      expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
      expect(find.text('login'), findsNothing);
    },
  );

  testWidgets('provider details route remains public for guest users', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/providers/p-1',
      routes: [
        GoRoute(
          path: AppRouter.login,
          builder: (context, state) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/providers/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('provider-details-opened')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('provider-details-opened'), findsOneWidget);
    expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
    expect(find.text('login'), findsNothing);
  });

  testWidgets('providers quote-request route requires an account by default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final authRepository = AuthRepository(apiClient, authStorage);
    final authController = AuthController(authRepository)..restoreSession();
    final router = GoRouter(
      initialLocation: '/providers/p-1/quote',
      routes: [
        GoRoute(
          path: AppRouter.login,
          builder: (context, state) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/providers/:id/quote',
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            child: const Text('quote-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<AuthRepository>.value(value: authRepository),
          ChangeNotifierProvider<AuthController>.value(value: authController),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider-auth-gate')), findsOneWidget);
    expect(find.text('quote-opened'), findsNothing);
    expect(find.byKey(const Key('provider-auth-gate-login')), findsOneWidget);
    expect(
      find.byKey(const Key('provider-auth-gate-register')),
      findsOneWidget,
    );
    expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
    expect(find.text('login'), findsNothing);
  });

  testWidgets(
    'providers quote route opens when an authenticated session exists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = _AuthenticatedAuthController(authRepository);
      final router = GoRouter(
        initialLocation: '/providers/p-1/quote',
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
          GoRoute(
            path: '/providers/:id/quote',
            builder: (context, state) => ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              child: const Text('quote-opened'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('quote-opened'), findsOneWidget);
      expect(find.byKey(const Key('provider-auth-gate')), findsNothing);
      expect(find.text('login'), findsNothing);
    },
  );

  testWidgets('provider dashboard blocks an authenticated wedding user', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final authRepository = AuthRepository(apiClient, authStorage);
    final authController = _AuthenticatedAuthController(
      authRepository,
      user: const SafeUser(
        id: 'user-1',
        name: 'Wedding User',
        role: 'USER',
        appRole: 'WEDDING_USER',
        status: 'ACTIVE',
      ),
    );
    final accountContexts = await _accountContexts(authStorage, [
      _context(AccountContextRole.owner),
    ]);
    final router = GoRouter(
      initialLocation: AppRouter.providerDashboard,
      routes: [
        GoRoute(
          path: AppRouter.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppRouter.providerApply,
          builder: (context, state) => const Scaffold(body: Text('apply')),
        ),
        GoRoute(
          path: AppRouter.providerDashboard,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            providerAccountRequired: true,
            child: const Text('provider-dashboard-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<AuthRepository>.value(value: authRepository),
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('provider-account-required-gate')),
      findsOneWidget,
    );
    expect(find.text('provider-dashboard-opened'), findsNothing);
  });

  testWidgets(
    'provider dashboard opens from the selected active provider context',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = _AuthenticatedAuthController(
        authRepository,
        user: const SafeUser(
          id: 'provider-user',
          name: 'Provider User',
          role: 'USER',
          appRole: 'WEDDING_USER',
          status: 'ACTIVE',
        ),
      );
      final accountContexts = await _accountContexts(authStorage, [
        _context(AccountContextRole.provider),
      ]);
      final router = GoRouter(
        initialLocation: AppRouter.providerDashboard,
        routes: [
          GoRoute(
            path: AppRouter.providerDashboard,
            builder: (context, state) => ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              providerAccountRequired: true,
              child: const Text('provider-dashboard-opened'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<AccountContextController>.value(
              value: accountContexts,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('provider-dashboard-opened'), findsOneWidget);
      expect(
        find.byKey(const Key('provider-account-required-gate')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'legacy provider role cannot open provider dashboard without a live context',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = _AuthenticatedAuthController(
        authRepository,
        user: const SafeUser(
          id: 'legacy-provider-user',
          name: 'Legacy Provider',
          role: 'PROVIDER',
          appRole: 'PROVIDER',
          status: 'ACTIVE',
        ),
      );
      final accountContexts = await _accountContexts(authStorage, const []);
      final router = GoRouter(
        initialLocation: AppRouter.providerDashboard,
        routes: [
          GoRoute(
            path: AppRouter.providerDashboard,
            builder: (context, state) => ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              providerAccountRequired: true,
              child: const Text('provider-dashboard-opened'),
            ),
          ),
          GoRoute(
            path: AppRouter.providerApply,
            builder: (context, state) => const Text('apply'),
          ),
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) => const Text('home'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<AccountContextController>.value(
              value: accountContexts,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('provider-account-required-gate')),
        findsOneWidget,
      );
      expect(find.text('provider-dashboard-opened'), findsNothing);
    },
  );

  testWidgets(
    'pending provider context cannot open operational provider routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = _AuthenticatedAuthController(authRepository);
      final accountContexts = await _accountContexts(authStorage, [
        _context(AccountContextRole.provider, lifecycle: 'PENDING'),
      ]);
      final router = GoRouter(
        initialLocation: AppRouter.providerServiceNew,
        routes: [
          GoRoute(
            path: AppRouter.providerServiceNew,
            builder: (context, state) => ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              providerAccountRequired: true,
              providerOperationsRequired: true,
              child: const Text('service-form-opened'),
            ),
          ),
          GoRoute(
            path: AppRouter.providerApply,
            builder: (context, state) => const Text('apply'),
          ),
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) => const Text('home'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<AccountContextController>.value(
              value: accountContexts,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('provider-account-required-gate')),
        findsOneWidget,
      );
      expect(find.text('service-form-opened'), findsNothing);
    },
  );
}

class _AuthenticatedAuthController extends AuthController {
  _AuthenticatedAuthController(super.authRepository, {SafeUser? user})
    : _user = user;

  final SafeUser? _user;

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  SafeUser? get user => _user;
}

Future<AccountContextController> _accountContexts(
  AuthStorage storage,
  List<AccountContext> contexts,
) async {
  final controller = AccountContextController(
    contextsApi: _StaticContextsGateway(contexts),
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh();
  if (contexts.length == 1) {
    final selected = await controller.select(contexts.single.contextKey);
    if (!selected) {
      throw StateError('The test context must be selected explicitly');
    }
  }
  return controller;
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}

AccountContext _context(
  AccountContextRole role, {
  String lifecycle = 'ACTIVE',
}) {
  final isProvider = role == AccountContextRole.provider;
  final planId = isProvider ? null : 'plan-1';
  final providerId = isProvider ? 'provider-1' : null;
  final providerCanManage =
      isProvider && lifecycle != 'SUSPENDED' && lifecycle != 'REJECTED';
  final providerCanOperate = isProvider && lifecycle == 'ACTIVE';
  final accessMode = isProvider && lifecycle != 'ACTIVE' ? 'LIMITED' : 'FULL';
  return AccountContext.fromJson({
    'contextKey': isProvider
        ? 'provider:$providerId'
        : 'plan:$planId:${role == AccountContextRole.owner ? 'owner' : 'contributor'}',
    'role': role.name.toUpperCase(),
    'weddingPlanId': planId,
    'providerId': providerId,
    'persona': null,
    'displayName': isProvider ? 'مزود الاختبار' : 'خطة الاختبار',
    'lifecycle': isProvider ? lifecycle : 'PLANNING',
    'accessMode': accessMode,
    'capabilities': {
      'canViewProviderProfile': isProvider,
      'canManageProviderProfile': providerCanManage,
      'canUseProviderOperations': providerCanOperate,
    },
    'permissions': {
      'canViewPlan': !isProvider,
      'canEditPlan': !isProvider,
      'canManageTasks': !isProvider,
      'canManageGuests': !isProvider,
      'canManageProviders': !isProvider,
      'canInviteMembers': !isProvider,
      'canViewMoney': !isProvider,
      'canManageMoney': !isProvider,
      'canManageProviderProfile': providerCanManage,
    },
    'isAvailable': true,
    'unavailableReason': null,
  });
}
