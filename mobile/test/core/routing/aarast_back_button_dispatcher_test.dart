import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/routing/aarast_back_button_dispatcher.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/routing/root_tab_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('system back restores locations replaced by go', (tester) async {
    final logSink = _CollectingLogSink();
    AppLogger.installGlobal(
      AppLogger(
        redactor: LogRedactor(installationSalt: 'navigation-test'),
        sinks: [logSink],
      ),
    );
    addTearDown(AppLogger.clearGlobal);
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.go('/first');
    await tester.pumpAndSettle();
    harness.router.go('/second');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/first');

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRouter.home);

    final transitions = logSink.events
        .where(
          (event) =>
              event.name == 'navigation_effective_transition' &&
              event.category == AppLogCategory.navigation,
        )
        .toList();
    expect(transitions, hasLength(4));
    expect(transitions.map((event) => event.attributes['targetRoute']), [
      '/first',
      '/second',
      '/first',
      AppRouter.home,
    ]);
    expect(transitions.first.attributes['currentRoute'], AppRouter.home);
  });

  // RA-MO-120: the code page lives on what it was opened with; back from
  // «نسيت كلمة المرور» reopened it empty by its address.
  testWidgets('back from the password reset skips the code page', (
    tester,
  ) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.go(AppRouter.otp);
    await tester.pumpAndSettle();
    harness.router.go('${AppRouter.resetPassword}?phone=777123456');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, isNot(AppRouter.otp));
  });

  testWidgets('ordinary pushed routes still pop through Navigator', (
    tester,
  ) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.push('/first');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRouter.home);
  });

  testWidgets('root back remains available for platform app exit', (
    tester,
  ) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    expect(await harness.dispatcher.didPopRoute(), isFalse);
    expect(harness.router.state.uri.path, AppRouter.home);
  });

  testWidgets('context change discards routes from the previous context', (
    tester,
  ) async {
    final harness = _RouterHarness();
    final contextKey = ValueNotifier<String?>('plan:one:owner');
    harness.dispatcher.bindContext(
      listenable: contextKey,
      readContextKey: () => contextKey.value,
    );
    addTearDown(() {
      contextKey.dispose();
      harness.dispose();
    });
    await tester.pumpWidget(harness.app);

    harness.router.go('/first');
    await tester.pumpAndSettle();
    harness.router.go('/second');
    await tester.pumpAndSettle();

    contextKey.value = 'plan:two:owner';
    await tester.pump();
    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRouter.home);
  });

  testWidgets(
    'context mismatch never restores a fallback route for the previous plan',
    (tester) async {
      final harness = _RouterHarness();
      final selectedContext =
          ValueNotifier<({String contextKey, String weddingPlanId})>((
            contextKey: 'plan:one:owner',
            weddingPlanId: 'plan-one',
          ));
      harness.dispatcher.bindContext(
        listenable: selectedContext,
        readContextKey: () => selectedContext.value.contextKey,
        readWeddingPlanId: () => selectedContext.value.weddingPlanId,
      );
      addTearDown(() {
        selectedContext.dispose();
        harness.dispose();
      });
      await tester.pumpWidget(harness.app);

      harness.router.go(AppRouter.moneyCostCreate('plan-one'));
      await tester.pumpAndSettle();
      expect(
        harness.router.state.uri.path,
        AppRouter.moneyCostCreate('plan-one'),
      );

      selectedContext.value = (
        contextKey: 'plan:two:owner',
        weddingPlanId: 'plan-two',
      );
      await tester.pump();

      expect(await harness.dispatcher.didPopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, AppRouter.home);
      expect(harness.router.state.uri.path, isNot(AppRouter.money('plan-one')));
    },
  );

  testWidgets('contributor fallback never re-enters the owner dashboard', (
    tester,
  ) async {
    final harness = _RouterHarness();
    final selectedContext =
        ValueNotifier<({String contextKey, String weddingPlanId})>((
          contextKey: 'plan:plan-one:owner',
          weddingPlanId: 'plan-one',
        ));
    harness.dispatcher.bindContext(
      listenable: selectedContext,
      readContextKey: () => selectedContext.value.contextKey,
      readWeddingPlanId: () => selectedContext.value.weddingPlanId,
    );
    addTearDown(() {
      selectedContext.dispose();
      harness.dispose();
    });
    await tester.pumpWidget(harness.app);

    harness.router.go(AppRouter.money('plan-one'));
    await tester.pumpAndSettle();
    selectedContext.value = (
      contextKey: 'plan:plan-one:contributor',
      weddingPlanId: 'plan-one',
    );
    await tester.pump();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRouter.home);
    expect(
      harness.router.state.uri.path,
      isNot(AppRouter.weddingPlanDashboard('plan-one')),
    );
  });

  // RA-MO-13: a tab of the route-owned plan shell is a place, not a step.
  // However many taps, back goes to the plan's first tab, then to where the
  // plan was opened from.
  testWidgets('tab taps in a route-owned plan shell never stack', (
    tester,
  ) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.go('/first');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/plan-1/dashboard');
    await tester.pumpAndSettle();
    const tabs = ['money', 'tasks', 'guests', 'providers'];
    for (var tap = 0; tap < 30; tap++) {
      harness.router.go('/wedding-plans/plan-1/${tabs[tap % tabs.length]}');
      await tester.pumpAndSettle();
    }
    expect(harness.router.state.uri.path, '/wedding-plans/plan-1/tasks');

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/wedding-plans/plan-1/dashboard');

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/first');
  });

  testWidgets('a plan opened on a later tab still backs to its first tab', (
    tester,
  ) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.go('/first');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/plan-1/providers');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/plan-1/tasks');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/wedding-plans/plan-1/dashboard');

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/first');
  });

  testWidgets('a plan kept on the phone backs to its one home, then exits', (
    tester,
  ) async {
    final harness = _RouterHarness(
      keptOnPhone: (planId) => planId.startsWith('guest-plan-'),
    );
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    // Opened from another screen: /home is still the end of back, as when
    // it is reached going forward.
    harness.router.go('/first');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/guest-plan-1/money');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/guest-plan-1/tasks');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/guest-plan-1/guests');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRouter.home);

    expect(await harness.dispatcher.didPopRoute(), isFalse);
  });

  testWidgets('a step inside a tab is still one back away', (tester) async {
    final harness = _RouterHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.router.go('/wedding-plans/plan-1/dashboard');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/plan-1/money');
    await tester.pumpAndSettle();
    harness.router.go('/wedding-plans/plan-1/money/costs/create');
    await tester.pumpAndSettle();

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/wedding-plans/plan-1/money');

    expect(await harness.dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/wedding-plans/plan-1/dashboard');
  });

  test('deep-link routes have a logical back fallback', () {
    expect(
      AarastBackButtonDispatcher.fallbackLocationFor(
        Uri.parse('/wedding-plans/plan-1/money/costs/create'),
      ),
      AppRouter.money('plan-1'),
    );
    expect(
      AarastBackButtonDispatcher.fallbackLocationFor(
        Uri.parse('/providers/provider-1/quote'),
      ),
      AppRouter.providerDetails('provider-1'),
    );
    expect(
      AarastBackButtonDispatcher.fallbackLocationFor(
        Uri.parse(AppRouter.providerProfileEdit),
      ),
      AppRouter.providerDashboard,
    );
  });

  testWidgets('back returns an in-route tab shell to its first tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _TabBackHarness()));

    await tester.tap(find.text('open tab'));
    await tester.pump();
    expect(find.text('tab 2'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('tab 0'), findsOneWidget);
  });
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}

class _RouterHarness {
  _RouterHarness({bool Function(String planId)? keptOnPhone})
    : router = GoRouter(
        initialLocation: AppRouter.home,
        routes: [
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) => const _Screen('home'),
          ),
          GoRoute(
            path: '/first',
            builder: (context, state) => const _Screen('first'),
          ),
          GoRoute(
            path: '/second',
            builder: (context, state) => const _Screen('second'),
          ),
          for (final tab in const [
            'dashboard',
            'money',
            'tasks',
            'guests',
            'providers',
          ])
            GoRoute(
              path: '/wedding-plans/:id/$tab',
              builder: (context, state) => _Screen(tab),
            ),
          GoRoute(
            path: '/wedding-plans/:id/money/costs/create',
            builder: (context, state) => const _Screen('create cost'),
          ),
          for (final path in [
            AppRouter.login,
            AppRouter.otp,
            AppRouter.resetPassword,
          ])
            GoRoute(path: path, builder: (context, state) => _Screen(path)),
        ],
      ) {
    dispatcher = AarastBackButtonDispatcher(router, keptOnPhone: keptOnPhone);
  }

  final GoRouter router;
  late final AarastBackButtonDispatcher dispatcher;

  Widget get app {
    return MaterialApp.router(
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: dispatcher,
    );
  }

  void dispose() {
    dispatcher.dispose();
    router.dispose();
  }
}

class _Screen extends StatelessWidget {
  const _Screen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Text(label));
  }
}

class _TabBackHarness extends StatefulWidget {
  const _TabBackHarness();

  @override
  State<_TabBackHarness> createState() => _TabBackHarnessState();
}

class _TabBackHarnessState extends State<_TabBackHarness> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return RootTabBackScope(
      activeIndex: _index,
      onReturnToRoot: () => setState(() => _index = 0),
      child: Scaffold(
        body: Column(
          children: [
            Text('tab $_index'),
            TextButton(
              onPressed: () => setState(() => _index = 2),
              child: const Text('open tab'),
            ),
          ],
        ),
      ),
    );
  }
}
