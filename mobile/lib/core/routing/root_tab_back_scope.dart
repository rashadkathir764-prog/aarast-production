import 'package:flutter/material.dart';

/// Makes Android back return an in-route tab shell to its first tab before
/// allowing the route itself to pop or the app root to exit.
class RootTabBackScope extends StatelessWidget {
  const RootTabBackScope({
    required this.activeIndex,
    required this.onReturnToRoot,
    required this.child,
    super.key,
  });

  final int activeIndex;
  final VoidCallback onReturnToRoot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: activeIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && activeIndex != 0) onReturnToRoot();
      },
      child: child,
    );
  }
}
