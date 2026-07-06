import 'package:aarast_mobile/core/routing/aarast_back_button_dispatcher.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/routing/root_tab_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('system back restores locations replaced by go', (tester) async {
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

  test('deep-link routes have a logical back fallback', () {
    expect(
      AarastBackButtonDispatcher.fallbackLocationFor(
        Uri.parse('/wedding-plans/plan-1/expenses/create'),
      ),
      AppRouter.finance('plan-1'),
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

class _RouterHarness {
  _RouterHarness()
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
        ],
      ) {
    dispatcher = AarastBackButtonDispatcher(router);
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
