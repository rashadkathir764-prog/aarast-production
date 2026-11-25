import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-TS-24: a route's guard is asked of the real router. This opens
// `AppRouter.create` for a visitor with no session and goes to [path], so a
// test says what a signed-out person meets there instead of reading the
// router's source for the gate's name.

/// The real router, a signed-out [AuthController], and the screen at [path].
Future<GoRouter> openSignedOutAt(WidgetTester tester, String path) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final auth = AuthController(
    AuthRepository(ApiClient(tokenProvider: storage.readAccessToken), storage),
  )..restoreSession();
  final router = AppRouter.create();
  addTearDown(auth.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  // restoreSession reads the (empty) storage: let it answer.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  router.go(path);
  await tester.pump();
  await tester.pump();
  return router;
}

/// The widget `AppRouter.create`'s own route for [location] builds, with the
/// path parameters and query the router would hand it, and nothing pumped
/// under it. A test says what a route hands its screen (a link's `quoteId`,
/// the plan's id) instead of reading the router's source for it.
Future<Widget> routeScreenAt(WidgetTester tester, String location) async {
  final router = AppRouter.create();
  addTearDown(router.dispose);
  final uri = Uri.parse(location);
  final matches = router.configuration.findMatch(uri);
  // A shell wraps the route it holds: go down to the route itself.
  var match = matches.matches.last;
  while (match is ShellRouteMatch) {
    match = match.matches.last;
  }
  final route = match.route;
  if (route is! GoRoute || route.builder == null) {
    throw StateError('$location is served by no GoRoute with a builder');
  }
  final state = GoRouterState(
    router.configuration,
    uri: uri,
    matchedLocation: uri.path,
    fullPath: matches.fullPath,
    pathParameters: matches.pathParameters,
    pageKey: const ValueKey('route-screen-at'),
  );
  late Widget screen;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        screen = route.builder!(context, state);
        return const SizedBox();
      },
    ),
  );
  return screen;
}
