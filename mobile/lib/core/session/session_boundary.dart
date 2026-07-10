import 'package:flutter/widgets.dart';

/// Recreates and disposes its complete subtree whenever [identity] changes.
/// Account-scoped and plan-scoped providers live below this boundary so no
/// in-memory model can cross into a different user or wedding plan.
class AarastSessionBoundary extends StatelessWidget {
  const AarastSessionBoundary({
    required this.identity,
    required this.builder,
    super.key,
  });

  final Object identity;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<Object>(identity),
      child: Builder(builder: builder),
    );
  }
}
