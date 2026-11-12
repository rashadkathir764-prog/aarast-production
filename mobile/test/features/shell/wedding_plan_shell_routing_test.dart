// The plan shell around the five tabs: canonical chrome, opaque surface,
// tab switching without page key reuse, and the floating «+» the owner kept
// (D33): on the home, money (for whoever manages it), tasks and guests,
// never on the providers or a money subpage.

import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add_sheet.dart';
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
    test('owner and participant shells use the canonical chrome', () {
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
      // D34: a participant gets the plan's five tabs (x06, q05, q07,
      // q08) on the same chrome, never the old one-page workspace. D34 gave
      // them no floating «+»; D112 (Q-19, the owner's word on 2026-11-12)
      // gives the «+» their rights give them, which is the money's for
      // whoever manages it, through the one rule checked below.
      expect(mainShell, contains('class _ContributorMainShell'));
      expect(mainShell, contains('ParticipantPlanShell('));
      expect(mainShell, isNot(contains('contributor-workspace-')));
      final participantShell = File(
        'lib/features/shell/screens/participant_plan_shell.dart',
      ).readAsStringSync();
      expect(participantShell, contains('PlanShellChrome('));
      expect(participantShell, contains('shouldShowParticipantQuickAdd('));
      expect(
        participantShell,
        contains('onQuickAdd: showQuickAdd ? () => _quickAdd().open(context)'),
      );
      expect(routeShell, contains('participant-route-shell-'));
    });

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

    testWidgets(
      'a participant plan route gets the tabs without the «+» (D34)',
      (tester) async {
        final router = _buildPlanShellRouter(
          initialLocation: AppRouter.money('plan-7'),
        );
        addTearDown(router.dispose);
        await _pumpPlanShellRouter(
          tester,
          router,
          role: AccountContextRole.contributor,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('participant-route-shell-plan-7')),
          findsOneWidget,
        );
        expect(find.byType(PlanQuickAddButton), findsNothing);
        expect(find.text('money'), findsOneWidget);

        await _tapNavIcon(tester, LucideIcons.listChecks);
        expect(router.state.uri.path, AppRouter.tasks('plan-7'));
        expect(find.text('tasks'), findsOneWidget);

        // A page inside a tab owns the screen, as for the owner.
        router.go(AppRouter.moneyBudget('plan-7'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('participant-route-shell-plan-7')),
          findsNothing,
        );
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

      void expectQuickAdd({required bool shown}) {
        final shellScaffold = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .singleWhere((scaffold) => scaffold.bottomNavigationBar != null);
        expect(shellScaffold.floatingActionButton != null, shown);
        expect(
          find.byKey(const ValueKey('aarast-quick-action')),
          shown ? findsOneWidget : findsNothing,
        );
      }

      expectQuickAdd(shown: true);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      // No money loaded here, so nobody is known to manage it.
      await _tapNavIcon(tester, LucideIcons.wallet);
      expect(router.state.uri.path, AppRouter.money('plan-7'));
      expectQuickAdd(shown: false);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.listChecks);
      expect(router.state.uri.path, AppRouter.tasks('plan-7'));
      expectQuickAdd(shown: true);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.users);
      expect(router.state.uri.path, AppRouter.guestList('plan-7'));
      expectQuickAdd(shown: true);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.store);
      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expectQuickAdd(shown: false);
      expect(tester.takeException(), isNull);

      await _tapNavIcon(tester, LucideIcons.home);
      expect(router.state.uri.path, AppRouter.weddingPlanDashboard('plan-7'));
      expectQuickAdd(shown: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money root shows the «+» only to whoever manages the money', (
      tester,
    ) async {
      for (final canManage in [true, false]) {
        final router = _buildPlanShellRouter(
          initialLocation: AppRouter.money('plan-7'),
        );
        addTearDown(router.dispose);
        await _pumpPlanShellRouter(
          tester,
          router,
          finance: _ShellFinance(canManage: canManage),
        );
        await tester.pump();

        expect(find.text('money'), findsOneWidget);
        expect(
          find.bySemanticsLabel('إضافة اتفاق'),
          canManage ? findsOneWidget : findsNothing,
          reason: 'canManage: $canManage',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('guest «+» opens the add route without page key reuse', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.guestList('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.text('guests'), findsOneWidget);
      expect(find.bySemanticsLabel('إضافة ضيف'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(JourneySheetBody), findsNothing);
      expect(find.text('guest-add'), findsOneWidget);
      expect(router.state.uri.path, AppRouter.guestListAdd('plan-7'));
    });

    testWidgets('tasks «+» opens the new task form straight away', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.tasks('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();

      expect(find.bySemanticsLabel('إضافة مهمة'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
      await tester.pumpAndSettle();

      expect(find.byType(JourneySheetBody), findsNothing);
      expect(find.text('task-create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'home «+» opens the journey sheet; a choice opens its form and a long press repeats it',
      (tester) async {
        final router = _buildPlanShellRouter(
          initialLocation: AppRouter.weddingPlanDashboard('plan-7'),
        );

        await _pumpPlanShellRouter(tester, router);
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
        await tester.pumpAndSettle();

        expect(find.byType(JourneySheetBody), findsOneWidget);
        expect(find.text('ايش تضيف؟'), findsOneWidget);
        expect(find.text('الأنسب الآن'), findsOneWidget);
        expect(find.text('إضافة مهمة'), findsOneWidget);
        expect(find.text('إضافة ضيف'), findsOneWidget);
        expect(find.text('طلب عرض سعر'), findsOneWidget);
        // Nobody is known to manage the money, so nothing adds to it.
        expect(find.text('إضافة اتفاق'), findsNothing);
        expect(find.text('إضافة بند'), findsNothing);

        await tester.tap(find.text('إضافة مهمة'));
        await tester.pumpAndSettle();
        expect(find.byType(JourneySheetBody), findsNothing);
        expect(find.text('task-create'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('dashboard'), findsOneWidget);

        await tester.longPress(
          find.byKey(const ValueKey('aarast-quick-action')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(JourneySheetBody), findsNothing);
        expect(find.text('task-create'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('home «+» quote choice opens the providers tab', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.weddingPlanDashboard('plan-7'),
      );

      await _pumpPlanShellRouter(tester, router);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('طلب عرض سعر'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRouter.planProviders('plan-7'));
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money «+» offers the agreement, payment, date and item', (
      tester,
    ) async {
      final router = _buildPlanShellRouter(
        initialLocation: AppRouter.money('plan-7'),
      );

      await _pumpPlanShellRouter(
        tester,
        router,
        finance: _ShellFinance(canManage: true),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
      await tester.pumpAndSettle();

      // The «+» itself is also «إضافة اتفاق»; read the sheet's rows.
      Finder row(String label) => find.descendant(
        of: find.byType(JourneySheetBody),
        matching: find.text(label),
      );
      for (final label in [
        'إضافة اتفاق',
        'تسجيل دفعة',
        'إضافة موعد دفع',
        'إضافة بند',
      ]) {
        expect(row(label), findsOneWidget, reason: label);
      }
      expect(row('إضافة مهمة'), findsNothing);

      await tester.tap(row('إضافة اتفاق'));
      await tester.pumpAndSettle();
      expect(find.text('cost-create'), findsOneWidget);
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
  FinanceProvider? finance,
  AccountContextRole role = AccountContextRole.owner,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final context = accountContext(role: role, planId: 'plan-7');
  final controller = AccountContextController(
    contextsApi: _StaticAccountContextsGateway(context),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh();
  expect(await controller.select(context.contextKey), isTrue);
  addTearDown(controller.dispose);

  Widget app = MaterialApp.router(routerConfig: router);
  if (finance != null) {
    app = ChangeNotifierProvider<FinanceProvider>.value(
      value: finance,
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
            path: '/wedding-plans/:id/money/budget',
            builder: (context, state) => const Scaffold(body: Text('budget')),
          ),
          GoRoute(
            path: '/wedding-plans/:id/money/costs/create',
            builder: (context, state) =>
                const Scaffold(body: Text('cost-create')),
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
      GoRoute(
        path: '/wedding-plans/:id/tasks/create',
        builder: (context, state) => const Scaffold(body: Text('task-create')),
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

/// The plan's money, loaded, with or without the right to manage it.
class _ShellFinance extends FinanceProvider {
  _ShellFinance({required this.canManage})
    : super(FinanceApi(ApiClient(tokenProvider: () async => null)));

  final bool canManage;

  @override
  String? get loadedPlanId => 'plan-7';

  @override
  bool get hasLoadedMoney => true;

  @override
  bool get canManageMoney => canManage;

  @override
  bool get canManageBudget => canManage;
}
