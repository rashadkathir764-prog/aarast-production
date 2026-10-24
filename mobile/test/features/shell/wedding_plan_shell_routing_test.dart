// The plan shell around the five tabs: canonical chrome, opaque surface,
// tab switching without page key reuse, and no floating add button (the
// design draws none; each tab adds from its own header).

import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeddingPlanShell routing', () {
    test(
      'owner shells use canonical chrome while contributor shell stays isolated',
      () {
        final chrome = File(
          'lib/features/shell/widgets/plan_shell_chrome.dart',
        );
        expect(
          chrome.existsSync(),
          isTrue,
          reason: 'PlanShellChrome must be the only production shell frame.',
        );

        for (final path in <String>[
          'lib/features/shell/main_shell.dart',
          'lib/features/shell/screens/wedding_plan_shell.dart',
        ]) {
          final source = File(path).readAsStringSync();
          expect(source, contains('PlanShellChrome('), reason: path);
          expect(
            source,
            isNot(contains('RoyalSmartFloatingActionButton(')),
            reason: path,
          );
          expect(
            source,
            isNot(contains('RoyalDashboardBottomNav(')),
            reason: path,
          );
        }

        final routeShell = File(
          'lib/features/shell/screens/wedding_plan_shell.dart',
        ).readAsStringSync();
        expect(routeShell, isNot(contains('child: Scaffold(')));

        final mainShell = File(
          'lib/features/shell/main_shell.dart',
        ).readAsStringSync();
        expect(mainShell, contains('class _ContributorMainShell'));
        expect(mainShell, contains('contributor-workspace-'));
        expect(mainShell, isNot(contains('contributor-indexed-stack-')));
        expect(mainShell, isNot(contains('contributor-navigation-')));
        expect(mainShell, isNot(contains('contributor-tab-')));
      },
    );

    testWidgets(
      'route-owned plan shell keeps an opaque semantic canvas during tab changes',
      (tester) async {
        final router = _buildPlanShellRouter(
          initialLocation: AppRouter.planProviders('plan-7'),
        );
        addTearDown(router.dispose);

        await _pumpPlanShellRouter(tester, router);
        await tester.pump();

        void expectOpaqueShellSurface() {
          final shellScaffold = tester
              .widgetList<Scaffold>(find.byType(Scaffold))
              .singleWhere((scaffold) => scaffold.bottomNavigationBar != null);
          expect(shellScaffold.backgroundColor, AppTheme.canvas);
          expect(shellScaffold.backgroundColor?.a, 1);
        }

        expectOpaqueShellSurface();
        await _tapNavIcon(tester, LucideIcons.home);
        expectOpaqueShellSurface();
        await _tapNavIcon(tester, LucideIcons.store);
        expectOpaqueShellSurface();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('money subpages own the viewport without the tabs', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.moneyBudget('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.text('budget'), findsOneWidget);
      expect(find.byIcon(LucideIcons.listChecks), findsNothing);
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
    });

    testWidgets('bottom tabs switch without duplicate shell page keys', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.weddingPlanDashboard('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      void expectNoFloatingAdd() {
        final shellScaffold = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .singleWhere((scaffold) => scaffold.bottomNavigationBar != null);
        expect(shellScaffold.floatingActionButton, isNull);
        expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
      }

      expectNoFloatingAdd();
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await _tapNavIcon(tester, LucideIcons.wallet);
      expect(router.state.uri.path, AppRouter.money('plan-7'));
      expectNoFloatingAdd();
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.listChecks);
      expect(router.state.uri.path, AppRouter.tasks('plan-7'));
      expectNoFloatingAdd();
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.users);
      expect(router.state.uri.path, AppRouter.guestList('plan-7'));
      expectNoFloatingAdd();
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.store);
      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expectNoFloatingAdd();
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.home);
      expect(router.state.uri.path, AppRouter.weddingPlanDashboard('plan-7'));
      expectNoFloatingAdd();
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacked plan center returns to shell tabs without key reuse', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.weddingPlanDashboard('plan-7'),
        extraRootRoutes: [
          GoRoute(
            path: '/wedding-plans/:id/plan-center',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return Scaffold(
                body: Column(
                  children: [
                    const Text('plan-center'),
                    TextButton(
                      key: const ValueKey('pc-to-tasks'),
                      onPressed: () => context.go(AppRouter.tasks(id)),
                      child: const Text('tasks-tab'),
                    ),
                    TextButton(
                      key: const ValueKey('pc-to-providers'),
                      onPressed: () => context.go(AppRouter.planProviders(id)),
                      child: const Text('providers-tab'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();
      unawaited(router.push(AppRouter.planCenter('plan-7')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('plan-center'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pc-to-tasks')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('tasks'), findsOneWidget);
      expect(router.state.uri.path, AppRouter.tasks('plan-7'));
      expect(tester.takeException(), isNull);

      unawaited(router.push(AppRouter.planCenter('plan-7')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('pc-to-providers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('providers'), findsOneWidget);
      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expect(tester.takeException(), isNull);
    });

    test('plan center does not push routes owned by the plan shell', () {
      final source = File(
        'lib/features/wedding_plans/screens/plan_management_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('context.push(AppRouter.money')));
      expect(source, isNot(contains('context.push(AppRouter.tasks')));
      expect(source, isNot(contains('context.push(AppRouter.guestList')));
      expect(source, isNot(contains('context.push(AppRouter.planProviders')));
      // w10 is a sub screen of «حسابي» with no tab bar (D27).
      expect(source, isNot(contains('AarastPlanNavigationBar')));
    });
  });
}

Future<void> _pumpPlanShellRouter(WidgetTester tester, GoRouter router) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final context = accountContext(
    role: AccountContextRole.owner,
    planId: 'plan-7',
  );
  final controller = AccountContextController(
    contextsApi: _StaticAccountContextsGateway(context),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh();
  expect(await controller.select(context.contextKey), isTrue);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccountContextController>.value(
      value: controller,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

GoRouter _buildPlanShellRouter({
  required String initialLocation,
  List<RouteBase> extraRootRoutes = const [],
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return WeddingPlanShell(
            weddingPlanId: state.pathParameters['id'] ?? '',
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/wedding-plans/:id/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Text('dashboard')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/money',
            builder: (context, state) => const Scaffold(body: Text('money')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/money/budget',
            builder: (context, state) => const Scaffold(body: Text('budget')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/tasks',
            builder: (context, state) => const Scaffold(body: Text('tasks')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/guests',
            builder: (context, state) => const Scaffold(body: Text('guests')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/guests/add',
            builder: (context, state) =>
                const Scaffold(body: Text('guest-add')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/providers',
            builder: (context, state) =>
                const Scaffold(body: Text('providers')),
          ),
        ],
      ),
      ...extraRootRoutes,
    ],
  );
}

class _StaticAccountContextsGateway implements AccountContextsGateway {
  const _StaticAccountContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    if (context.contextKey != contextKey) {
      throw StateError('Unknown context');
    }
    return context;
  }
}

Future<void> _tapNavIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
