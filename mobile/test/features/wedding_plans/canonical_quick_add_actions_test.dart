// Canonical quick-add actions.
//
// Locks the labels + routes emitted by [buildCanonicalQuickAddActions]
// so duplicate shortcuts (MainShell, LocalGuestDashboardScreen) cannot
// drift from the navigation blueprint.

import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/quick_add_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('buildCanonicalQuickAddActions', () {
    test('emits the canonical dashboard actions with stable labels', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-1',
        openRoute: open,
      );

      expect(actions.length, 5);
      expect(actions.map((a) => a.label).toList(), <String>[
        'حجز مورد / تكلفة خدمة',
        'تسجيل دفعة',
        'إضافة مهمة',
        'إضافة ضيف',
        'طلب عرض سعر',
      ]);
    });

    test('routes every action through the canonical AppRouter paths', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add(route);
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-7',
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      expect(calls, <String>[
        AppRouter.createFinancialCommitment(
          'plan-7',
          sourceType: 'PROVIDER_SERVICE',
        ),
        AppRouter.recordPayment('plan-7'),
        AppRouter.createTask('plan-7'),
        AppRouter.guestListAdd('plan-7'),
        AppRouter.planProviders('plan-7'),
      ]);
    });

    test('keeps budget setup as a first-time money route', () {
      expect(
        AppRouter.budgetSetup('plan-7'),
        '/wedding-plans/plan-7/budget/setup',
      );
    });

    test('money context exposes the financial backbone actions only', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add(route);
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-money',
        contextOrder: QuickAddContext.money,
        openRoute: open,
      );

      expect(actions.map((a) => a.label).toList(), <String>[
        'إضافة بند ميزانية',
        'حجز مورد / تكلفة خدمة',
        'تسجيل دفعة',
        'إضافة دين يدوي',
      ]);

      for (final action in actions) {
        action.onTap();
      }

      expect(calls, <String>[
        AppRouter.createBudgetCategory('plan-money'),
        AppRouter.createFinancialCommitment(
          'plan-money',
          sourceType: 'PROVIDER_SERVICE',
        ),
        AppRouter.recordPayment('plan-money'),
        AppRouter.createFinancialCommitment(
          'plan-money',
          sourceType: 'MANUAL_DEBT',
        ),
      ]);
    });

    test('forwards refreshDashboardOnExpense to money-changing opens', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-r',
        refreshDashboardOnExpense: true,
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      // The dashboard finance actions propagate refreshDashboard=true.
      for (var i = 0; i < 2; i++) {
        expect(calls[i].endsWith('|rf=true'), isTrue, reason: calls[i]);
      }
      for (var i = 2; i < calls.length; i++) {
        expect(calls[i].endsWith('|rf=false'), isTrue, reason: calls[i]);
      }
    });

    test('orders the first action by the active tab context', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.money,
          openRoute: open,
        ).first.label,
        'إضافة بند ميزانية',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.tasks,
          openRoute: open,
        ).first.label,
        'إضافة مهمة',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.guests,
          openRoute: open,
        ).first.label,
        'إضافة ضيف',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.providers,
          openRoute: open,
        ).first.label,
        'طلب عرض سعر',
      );
    });
  });

  group('WeddingPlanShell routing', () {
    testWidgets('guest smart FAB opens the add route without page key reuse', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.guestList('plan-7'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.text('guests'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('royal-smart-fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('guest-add'), findsOneWidget);
      expect(router.state.uri.path, AppRouter.guestListAdd('plan-7'));
    });

    testWidgets('bottom tabs switch without duplicate shell page keys', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.weddingPlanDashboard('plan-7'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.byKey(const ValueKey('royal-smart-fab')), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await _tapNavIcon(tester, LucideIcons.wallet);
      expect(router.state.uri.path, AppRouter.finance('plan-7'));
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.listChecks);
      expect(router.state.uri.path, AppRouter.tasks('plan-7'));
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.users);
      expect(router.state.uri.path, AppRouter.guestList('plan-7'));
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.store);
      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.home);
      expect(router.state.uri.path, AppRouter.weddingPlanDashboard('plan-7'));
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsOneWidget);
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

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
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

      expect(source, isNot(contains('context.push(AppRouter.finance')));
      expect(source, isNot(contains('context.push(AppRouter.tasks')));
      expect(source, isNot(contains('context.push(AppRouter.guestList')));
      expect(source, isNot(contains('context.push(AppRouter.planProviders')));
      expect(source, contains('context.go(AppRouter.finance'));
      expect(source, contains('context.go(AppRouter.tasks'));
      expect(source, contains('context.go(AppRouter.guestList'));
      expect(source, contains('context.go(AppRouter.planProviders'));
    });
  });
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
            path: '/wedding-plans/:id/finance',
            builder: (context, state) => const Scaffold(body: Text('finance')),
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

Future<void> _tapNavIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _DummyContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
