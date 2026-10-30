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
}
