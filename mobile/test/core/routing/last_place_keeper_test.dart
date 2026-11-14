import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/routing/last_place_keeper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// RA-MO-312: Android closes an app left in the background when it needs the
// memory (a person in WhatsApp sending invitations, say). Coming back, the
// app started from its opening screen, the night sky with the fireworks,
// for a second and then the home: a celebration nobody asked for, and the
// place the person was in lost. Android hands the app what it saved when it
// closes it this way, and only then; the place is kept there.

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  // As the real app: one router per app lifetime, starting at the opening.
  late final GoRouter router = GoRouter(
    initialLocation: AppRouter.splash,
    routes: [
      for (final path in [
        AppRouter.splash,
        AppRouter.home,
        AppRouter.login,
        '/wedding-plans/:id/guests',
        '/wedding-plans/:id/guests/invite',
        '/wedding-plans/:id/dashboard',
        '/wedding-plans/:id/moments/:moment',
        '/wedding-plans/:id/money',
        '/wedding-plans/:id/money/mahr/moment',
        '/wedding-plans/:id/providers',
        '/wedding-plans/:id/providers/booked/:quoteId',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Text('at ${state.uri}'),
        ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          LastPlaceKeeper(router: router, child: child ?? const SizedBox()),
    );
  }
}

GoRouter _router(WidgetTester tester) =>
    tester.state<_AppState>(find.byType(_App)).router;

void main() {
  testWidgets('an app the system closed comes back where it was', (
    tester,
  ) async {
    await tester.pumpWidget(const _App());
    _router(tester).go('/wedding-plans/plan-1/guests/invite?reminder=1');
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(
      _router(tester).state.uri.toString(),
      '/wedding-plans/plan-1/guests/invite?reminder=1',
    );
    expect(find.text('at ${AppRouter.splash}'), findsNothing);
  });

  testWidgets('an app opened anew starts from its opening screen', (
    tester,
  ) async {
    await tester.pumpWidget(const _App());
    await tester.pumpAndSettle();

    expect(_router(tester).state.uri.path, AppRouter.splash);
  });

  testWidgets('the doors are not a place to come back to', (tester) async {
    await tester.pumpWidget(const _App());
    _router(tester).go('${AppRouter.login}?phone=777123456');
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_router(tester).state.uri.path, AppRouter.splash);
  });

  testWidgets('a celebration is not shown a second time: its page opens', (
    tester,
  ) async {
    await tester.pumpWidget(const _App());
    for (final (moment, parent) in [
      ('/wedding-plans/plan-1/moments/week', '/wedding-plans/plan-1/dashboard'),
      (
        '/wedding-plans/plan-1/money/mahr/moment',
        '/wedding-plans/plan-1/money',
      ),
      (
        '/wedding-plans/plan-1/providers/booked/quote-1',
        '/wedding-plans/plan-1/dashboard',
      ),
    ]) {
      _router(tester).go(moment);
      await tester.pumpAndSettle();

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(_router(tester).state.uri.toString(), parent, reason: moment);
    }
  });

  testWidgets('the place follows the person, not the first page kept', (
    tester,
  ) async {
    await tester.pumpWidget(const _App());
    _router(tester).go('/wedding-plans/plan-1/guests');
    await tester.pumpAndSettle();
    _router(tester).go(AppRouter.home);
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_router(tester).state.uri.path, AppRouter.home);
  });

  test('only a page inside the app is a place', () {
    expect(placeToReturnTo('/wedding-plans/p/guests'), isNotNull);
    expect(placeToReturnTo(AppRouter.splash), isNull);
    expect(placeToReturnTo(AppRouter.welcome), isNull);
    expect(placeToReturnTo(AppRouter.otp), isNull);
    expect(placeToReturnTo('https://example.com/x'), isNull);
    expect(placeToReturnTo('//example.com/x'), isNull);
    expect(placeToReturnTo(null), isNull);
  });
}
