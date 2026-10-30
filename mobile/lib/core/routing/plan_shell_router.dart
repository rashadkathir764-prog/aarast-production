import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// A [GoRouter] that never puts the plan's shell on the stack twice.
///
/// go_router merges a pushed shell page into the shell only when that shell is
/// on top. A page above the shell (a chat, a service's requests, a provider's
/// page) that pushes a shell page adds a second copy with the same navigator
/// key: a debug build asserts, a release build shows a black screen and leaves
/// the navigator broken for every screen after it, until the app is closed.
///
/// Every push passes here, so no screen has to know which pages sit in the
/// shell. Such a push goes to the page instead, and the shell's own back leads
/// out of it.
class PlanShellRouter extends GoRouter {
  PlanShellRouter({
    required List<RouteBase> routes,
    super.initialLocation,
    super.errorBuilder,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(RoutingConfig(routes: routes)),
       );

  bool _wouldDoubleTheShell(String location, Object? extra) {
    final stack = routerDelegate.currentConfiguration.matches;
    if (stack.isEmpty || stack.last is ShellRouteMatch) return false;
    final shellBelow = stack.whereType<ShellRouteMatch>().map(
      (match) => match.route,
    );
    if (shellBelow.isEmpty) return false;
    final target = configuration
        .findMatch(Uri.parse(location), extra: extra)
        .matches;
    return target.isNotEmpty && shellBelow.contains(target.last.route);
  }

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    if (_wouldDoubleTheShell(location, extra)) {
      go(location, extra: extra);
      return null;
    }
    return super.push<T>(location, extra: extra);
  }

  @override
  Future<T?> pushReplacement<T extends Object?>(
    String location, {
    Object? extra,
  }) async {
    if (_wouldDoubleTheShell(location, extra)) {
      go(location, extra: extra);
      return null;
    }
    return super.pushReplacement<T>(location, extra: extra);
  }

  @override
  Future<T?> replace<T>(String location, {Object? extra}) async {
    if (_wouldDoubleTheShell(location, extra)) {
      go(location, extra: extra);
      return null;
    }
    return super.replace<T>(location, extra: extra);
  }
}
