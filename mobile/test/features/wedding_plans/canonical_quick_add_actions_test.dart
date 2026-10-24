// Canonical quick-add actions.
//
// Locks the labels + routes emitted by [buildCanonicalQuickAddActions]
// so duplicate shortcuts (MainShell, LocalGuestDashboardScreen) cannot
// drift from the navigation blueprint.

import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan_stage.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/quick_add_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildCanonicalQuickAddActions', () {
    test('keeps quick-add visibility aligned across both shells', () {
      expect(shouldShowPlanQuickAdd(tabIndex: 0), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 1), isFalse);
      expect(shouldShowPlanQuickAdd(tabIndex: 1, canManageMoney: true), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 1, canManageMoney: true), isTrue);
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

    test('w29 guests hide quick add while an account plan is offline', () {
      expect(
        shouldShowPlanQuickAdd(tabIndex: 3, guestsWaitForConnection: true),
        isFalse,
      );
      // The other tabs queue their writes, so they keep it.
      expect(
        shouldShowPlanQuickAdd(tabIndex: 2, guestsWaitForConnection: true),
        isTrue,
      );
      expect(
        shouldShowPlanQuickAdd(tabIndex: 0, guestsWaitForConnection: true),
        isTrue,
      );
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

    test('money context exposes contextual payment and schedule actions', () {
      var paymentCalls = 0;
      var scheduleCalls = 0;
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-money-actions',
        canManageMoney: true,
        contextOrder: QuickAddContext.money,
        onRecordPayment: () => paymentCalls += 1,
        onAddPaymentSchedule: () => scheduleCalls += 1,
        openRoute: open,
      );

      expect(actions.map((action) => action.label), <String>[
        'إضافة تكلفة',
        'تسجيل دفعة',
        'إضافة موعد دفع',
        'إضافة تصنيف',
      ]);

      actions.singleWhere((action) => action.id == 'payment').onTap();
      actions.singleWhere((action) => action.id == 'schedule').onTap();
      expect(paymentCalls, 1);
      expect(scheduleCalls, 1);
    });

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

    test('state urgency wins, then the last useful action is remembered', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      final urgent = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'smart-plan',
        canManageMoney: true,
        signals: const QuickAddSignals(overdueTasks: 2, providerCount: 1),
        openRoute: open,
      );
      expect(urgent.first.label, 'إضافة مهمة');
      expect(urgent.first.recommended, isTrue);

      final neutral = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'recent-plan',
        canManageMoney: true,
        signals: const QuickAddSignals(providerCount: 1),
        openRoute: open,
      );
      neutral.singleWhere((action) => action.id == 'quote').onTap();

      final reordered = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'recent-plan',
        canManageMoney: true,
        signals: const QuickAddSignals(providerCount: 1),
        openRoute: open,
      );
      expect(reordered.first.id, 'quote');
      expect(reordered.first.recommended, isTrue);
    });

    test('wedding stage adapts the recommended creation action', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      final foundation = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'stage-foundation',
        canManageMoney: true,
        signals: const QuickAddSignals(
          stage: WeddingPlanStage.foundation,
          providerCount: 1,
        ),
        openRoute: open,
      );
      final finalMonth = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'stage-final-month',
        canManageMoney: true,
        signals: const QuickAddSignals(
          stage: WeddingPlanStage.finalMonth,
          providerCount: 1,
        ),
        openRoute: open,
      );
      final weddingDay = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'stage-wedding-day',
        canManageMoney: true,
        signals: const QuickAddSignals(
          stage: WeddingPlanStage.weddingDay,
          providerCount: 0,
        ),
        openRoute: open,
      );

      expect(foundation.first.id, 'task');
      expect(finalMonth.first.id, 'guest');
      expect(weddingDay.first.id, 'task');
      expect(foundation.first.recommended, isTrue);
    });

    test(
      'remembers a real action even when dashboard signals are unavailable',
      () {
        Future<void> open(
          String route, {
          bool refreshDashboard = false,
        }) async {}

        final actions = buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'offline-plan',
          canManageMoney: false,
          openRoute: open,
        );
        actions.singleWhere((action) => action.id == 'guest').onTap();

        expect(lastCanonicalQuickAddActionId('offline-plan'), 'guest');
        expect(
          lastCanonicalQuickAddAction('offline-plan', actions)?.id,
          'guest',
        );
      },
    );

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

    testWidgets('money subpages hide the root money smart FAB', (tester) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.moneyCosts('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.text('costs'), findsOneWidget);
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
    });

    testWidgets(
      'money root hides the competing FAB during setup and restores it afterward',
      (tester) async {
        Future<void> pumpWith({required bool setUp}) async {
          final router = _buildPlanShellRouter(
            initialLocation: AppRouter.money('plan-7'),
          );
          addTearDown(router.dispose);
          await _pumpPlanShellRouter(
            tester,
            router,
            financeProvider: _ShellFinanceProvider(setUp: setUp),
          );
          await tester.pump();
        }

        await pumpWith(setUp: false);
        var fab = find.byKey(const ValueKey('aarast-quick-action'));
        expect(fab, findsNothing);

        await pumpWith(setUp: true);
        fab = find.byKey(const ValueKey('aarast-quick-action'));
        expect(fab, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('guest smart FAB opens the add route without page key reuse', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.guestList('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.text('guests'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
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

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.byKey(const ValueKey('aarast-quick-action')), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await _tapNavIcon(tester, LucideIcons.wallet);
      expect(router.state.uri.path, AppRouter.money('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.listChecks);
      expect(router.state.uri.path, AppRouter.tasks('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.users);
      expect(router.state.uri.path, AppRouter.guestList('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.store);
      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.home);
      expect(router.state.uri.path, AppRouter.weddingPlanDashboard('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsOneWidget);
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

Future<void> _pumpPlanShellRouter(
  WidgetTester tester,
  GoRouter router, {
  FinanceProvider? financeProvider,
}) async {
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

  Widget app = MaterialApp.router(routerConfig: router);
  if (financeProvider != null) {
    app = ChangeNotifierProvider<FinanceProvider>.value(
      value: financeProvider,
      child: app,
    );
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AccountContextController>.value(
      value: controller,
      child: app,
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

class _DummyContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Money set up means a budget split into categories; a bare budget still gets
/// the starter (field test Q02).
class _ShellFinanceProvider extends FinanceProvider {
  _ShellFinanceProvider({required bool setUp})
    : _summary = MoneySummary(
        planId: 'plan-7',
        budget: MoneyBudgetSummary(total: setUp ? '1000' : null),
        permissions: const MoneyPermissions(
          canViewMoney: true,
          canManageMoney: true,
        ),
      ),
      _categories = setUp
          ? const [
              BudgetCategory(
                id: 'category-1',
                weddingPlanId: 'plan-7',
                name: 'القاعة',
              ),
            ]
          : const [],
      super(FinanceApi(ApiClient(tokenProvider: () async => null)));

  final MoneySummary _summary;
  final List<BudgetCategory> _categories;

  @override
  List<BudgetCategory> get categories => _categories;

  @override
  String? get loadedPlanId => 'plan-7';

  @override
  bool get hasLoadedMoney => true;

  @override
  bool get canManageMoney => true;

  @override
  MoneySummary get summary => _summary;
}
