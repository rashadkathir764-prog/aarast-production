import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:go_router/go_router.dart';

// RA-TS-25: a test that builds its own GoRouter must not invent plan paths.
// The paths the app answers are the ones in `AppRouter.create`; this reads
// them from there, so a path a test repeats is checked against the app's own
// table instead of against the test's memory of it.

/// A route's full pattern with its parameter names dropped: `:id` and
/// `:planId` are the same place, `/wedding-plans/:/money`.
String normalizeRoutePattern(String pattern) {
  final segments = Uri.parse(pattern).path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map((segment) => segment.startsWith(':') ? ':' : segment);
  return '/${segments.join('/')}';
}

Set<String>? _patterns;

/// Every full path pattern `AppRouter.create` serves, normalized.
Set<String> appRoutePatterns() {
  final cached = _patterns;
  if (cached != null) return cached;
  final router = AppRouter.create();
  try {
    final found = <String>{};
    void walk(List<RouteBase> routes, String parent) {
      for (final route in routes) {
        if (route is GoRoute) {
          final full = route.path.startsWith('/')
              ? route.path
              : '$parent/${route.path}';
          found.add(normalizeRoutePattern(full));
          walk(route.routes, full);
        } else {
          // A shell adds no path of its own.
          walk(route.routes, parent);
        }
      }
    }

    walk(router.configuration.routes, '');
    return _patterns = found;
  } finally {
    router.dispose();
  }
}

/// The first path segments the app serves: `wedding-plans`, `providers`, ...
Set<String> appRouteRoots() => {
  for (final pattern in appRoutePatterns())
    pattern.split('/').where((s) => s.isNotEmpty).firstOrNull ?? '',
};

/// True when [pattern] (`/wedding-plans/:id/money`, any parameter name) is a
/// route of `AppRouter.create`.
bool isAppRoute(String pattern) =>
    appRoutePatterns().contains(normalizeRoutePattern(pattern));

/// [pattern] as a route of the app, or a failure naming it. A test writes
/// `GoRoute(path: appRoute('/wedding-plans/:id/money'), ...)` so the path it
/// stubs is one the app really has.
String appRoute(String pattern) {
  if (!isAppRoute(pattern)) {
    throw StateError(
      'No route "$pattern" in AppRouter.create. '
      'A test router repeats the app\'s own paths; fix the path or the app.',
    );
  }
  return pattern;
}
