import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/diagnostics/context_lifecycle_logger.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('unknown route renders the router error boundary', (
    tester,
  ) async {
    final router = AppRouter.create();
    addTearDown(router.dispose);
    router.go('/route-that-does-not-exist');

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('router-error-boundary')), findsOneWidget);
    expect(find.text('تعذر فتح الصفحة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a route build failure renders the app build-error boundary', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/broken',
      routes: [
        GoRoute(
          path: '/broken',
          builder: (context, state) => const _ThrowingRoute(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      AarastBuildErrorBoundary(child: MaterialApp.router(routerConfig: router)),
    );

    expect(tester.takeException(), isA<StateError>());
    expect(find.byKey(const Key('app-build-error-boundary')), findsOneWidget);
    expect(find.text('تعذر بناء الصفحة'), findsOneWidget);
  });

  test('router error location never exposes identifiers or query values', () {
    final location = safeRouterErrorLocation(
      Uri.parse('/invites/private-token?resume=%2Fwedding-plans%2Fsecret'),
    );

    expect(location, '/invites');
    expect(location, isNot(contains('private-token')));
    expect(location, isNot(contains('secret')));
  });

  test(
    'lifecycle logs include context type without exposing route secrets',
    () {
      final previousDebugPrint = debugPrint;
      final messages = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);

      ContextLifecycleLogger.event(
        'ROUTE_BLOCKED',
        userId: 'user-1',
        activeContextKey: 'provider:provider-1',
        targetRoute: '/invites/private-token?resume=/wedding-plans/secret',
        reason: 'context_mismatch',
        source: 'test',
      );

      final message = messages.single;
      expect(message, contains('userId=user-1'));
      expect(message, contains('activeContextId=provider-1'));
      expect(message, contains('activeContextType=provider'));
      expect(message, contains('targetRoute=/invites/:redacted'));
      expect(message, isNot(contains('private-token')));
      expect(message, isNot(contains('secret')));
    },
  );
}

class _ThrowingRoute extends StatelessWidget {
  const _ThrowingRoute();

  @override
  Widget build(BuildContext context) {
    throw StateError('forced route build failure');
  }
}
