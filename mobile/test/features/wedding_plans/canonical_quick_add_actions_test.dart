// Canonical quick-add actions.
//
// Locks the labels + routes emitted by [buildCanonicalQuickAddActions]
// so duplicate shortcuts (MainShell, LocalGuestDashboardScreen) cannot
// drift from the navigation blueprint.

import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/quick_add_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

void main() {
  group('buildCanonicalQuickAddActions', () {
    test('keeps quick-add visibility aligned across both shells', () {
      expect(shouldShowPlanQuickAdd(tabIndex: 0), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 1), isFalse);
      expect(shouldShowPlanQuickAdd(tabIndex: 1, canManageMoney: true), isTrue);
      expect(
        shouldShowPlanQuickAdd(
          tabIndex: 1,
          canManageMoney: true,
          hasConfiguredMoney: false,
        ),
        isFalse,
      );
      expect(
        shouldShowPlanQuickAdd(tabIndex: 1, canManageMoney: false),
        isFalse,
      );
      expect(
        shouldShowPlanQuickAdd(tabIndex: 1, isRootDestination: false),
        isFalse,
      );
      expect(shouldShowPlanQuickAdd(tabIndex: 2), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 3), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 4), isFalse);
    });

    test('emits the canonical dashboard actions with stable labels', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-1',
        canManageMoney: true,
        openRoute: open,
      );

      expect(actions.length, 4);
      expect(actions.map((a) => a.label).toList(), <String>[
        'إضافة تكلفة',
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
        canManageMoney: true,
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      expect(calls, <String>[
        AppRouter.moneyCostCreate('plan-7'),
        AppRouter.createTask('plan-7'),
        AppRouter.guestListAdd('plan-7'),
        AppRouter.planProviders('plan-7'),
      ]);
    });

    test('keeps budget setup as a first-time money route', () {
      expect(
        AppRouter.moneyBudget('plan-7'),
        '/wedding-plans/plan-7/money/budget',
      );
    });

    test(
      'money context exposes additions but never duplicates budget management',
      () {
        final calls = <String>[];
        Future<void> open(String route, {bool refreshDashboard = false}) async {
          calls.add(route);
        }

        final actions = buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-money',
          canManageMoney: true,
          contextOrder: QuickAddContext.money,
          openRoute: open,
        );

        expect(actions.map((a) => a.label).toList(), <String>[
          'إضافة تكلفة',
          'إضافة تصنيف',
        ]);

        for (final action in actions) {
          action.onTap();
        }

        expect(calls, <String>[
          AppRouter.moneyCostCreate('plan-money'),
          AppRouter.moneyCategoryCreate('plan-money'),
        ]);
      },
    );

    test('forwards refreshDashboardOnMoney to money-changing opens', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-r',
        canManageMoney: true,
        refreshDashboardOnMoney: true,
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      // The single dashboard money action propagates refreshDashboard=true.
      expect(calls.first.endsWith('|rf=true'), isTrue, reason: calls.first);
      for (var i = 1; i < calls.length; i++) {
        expect(calls[i].endsWith('|rf=false'), isTrue, reason: calls[i]);
      }
    });

    test('orders the first action by the active tab context', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          canManageMoney: true,
          contextOrder: QuickAddContext.money,
          openRoute: open,
        ).first.label,
        'إضافة تكلفة',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          canManageMoney: true,
          contextOrder: QuickAddContext.tasks,
          openRoute: open,
        ).first.label,
        'إضافة مهمة',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          canManageMoney: true,
          contextOrder: QuickAddContext.guests,
          openRoute: open,
        ).first.label,
        'إضافة ضيف',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          canManageMoney: true,
          contextOrder: QuickAddContext.providers,
          openRoute: open,
        ).first.label,
        'طلب عرض سعر',
      );
    });

    test('never exposes financial actions without money management', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      for (final contextOrder in QuickAddContext.values) {
        final actions = buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'shared-plan',
          canManageMoney: false,
          contextOrder: contextOrder,
          openRoute: open,
        );
        final labels = actions.map((action) => action.label);
        expect(
          labels,
          isNot(contains('إضافة تكلفة')),
          reason: contextOrder.name,
        );
        expect(
          labels,
          isNot(contains('إضافة تصنيف')),
          reason: contextOrder.name,
        );
        expect(
          labels,
          isNot(contains('إدارة الميزانية')),
          reason: contextOrder.name,
        );
      }
    });
  });

  group('WeddingPlanShell routing', () {
    test('both production shells use one canonical chrome implementation', () {
      final chrome = File('lib/features/shell/widgets/plan_shell_chrome.dart');
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
        expect(source, isNot(contains('child: Scaffold(')), reason: path);
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
    });

    testWidgets('money subpages hide the root money smart FAB', (tester) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.moneyCosts('plan-7'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.text('costs'), findsOneWidget);
      expect(find.byKey(const ValueKey('royal-smart-fab')), findsNothing);
    });

    testWidgets(
      'money root has one setup entry before budget and add-only FAB after it',
      (tester) async {
        Future<void> pumpWith({required bool hasBudget}) async {
          final router = _buildPlanShellRouter(
            initialLocation: AppRouter.money('plan-7'),
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ChangeNotifierProvider<FinanceProvider>.value(
              value: _ShellFinanceProvider(hasBudget: hasBudget),
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pump();
        }

        await pumpWith(hasBudget: false);
        expect(find.byKey(const ValueKey('royal-smart-fab')), findsNothing);

        await pumpWith(hasBudget: true);
        final fab = find.byKey(const ValueKey('royal-smart-fab'));
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('إضافة تكلفة'), findsOneWidget);
        expect(find.text('إضافة تصنيف'), findsOneWidget);
        expect(find.text('إدارة الميزانية'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

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
      expect(router.state.uri.path, AppRouter.money('plan-7'));
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

      expect(source, isNot(contains('context.push(AppRouter.money')));
      expect(source, isNot(contains('context.push(AppRouter.tasks')));
      expect(source, isNot(contains('context.push(AppRouter.guestList')));
      expect(source, isNot(contains('context.push(AppRouter.planProviders')));
      expect(source, contains('context.go(AppRouter.money'));
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
            path: '/wedding-plans/:id/money',
            builder: (context, state) => const Scaffold(body: Text('money')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/money/costs',
            builder: (context, state) => const Scaffold(body: Text('costs')),
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

class _ShellFinanceProvider extends FinanceProvider {
  _ShellFinanceProvider({required bool hasBudget})
    : _summary = MoneySummary(
        planId: 'plan-7',
        budget: MoneyBudgetSummary(total: hasBudget ? '1000' : null),
        permissions: const MoneyPermissions(
          canViewMoney: true,
          canManageMoney: true,
        ),
      ),
      super(FinanceApi(ApiClient(tokenProvider: () async => null)));

  final MoneySummary _summary;

  @override
  String? get loadedPlanId => 'plan-7';

  @override
  bool get canManageMoney => true;

  @override
  MoneySummary get summary => _summary;
}
