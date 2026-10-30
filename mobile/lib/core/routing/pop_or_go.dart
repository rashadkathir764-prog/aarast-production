import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension PopOrGo on BuildContext {
  /// Back to the page this one was opened from, with [result]; or to
  /// [fallback] when it was opened directly (a link or a notification) and
  /// there is nothing to go back to.
  void popOrGo<T extends Object?>(String fallback, [T? result]) {
    if (canPop()) {
      pop<T>(result);
    } else {
      go(fallback);
    }
  }

  /// This page was pushed above the plan's shell: a chat, a provider page.
  bool get isAbovePlanShell {
    final matches = GoRouter.of(
      this,
    ).routerDelegate.currentConfiguration.matches;
    return matches.last.route is! ShellRouteBase &&
        matches.any((match) => match.route is ShellRouteBase);
  }

  /// Opens [location], a page inside the plan's shell. A page above the shell
  /// must not push it: the shell would enter the stack twice with one
  /// navigator key, which go_router asserts on in a debug build and leaves
  /// undefined in a release build, so it goes there instead.
  Future<void> pushPlanPage(String location) async {
    if (isAbovePlanShell) {
      go(location);
      return;
    }
    await push<void>(location);
  }
}
