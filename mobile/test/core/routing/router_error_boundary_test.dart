import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
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
    'structured navigation logs hash context data and remove route secrets',
    () {
      final sink = _CollectingLogSink();
      AppLogger.installGlobal(
        AppLogger(
          redactor: LogRedactor(installationSalt: 'router-boundary-test'),
          sinks: [sink],
        ),
      );
      addTearDown(AppLogger.clearGlobal);

      appLogEvent(
        'ROUTE_BLOCKED',
        category: AppLogCategory.navigation,
        userId: 'user-1',
        activeContextKey: 'provider:provider-1',
        targetRoute: '/invites/private-token?resume=/wedding-plans/secret',
        reason: 'context_mismatch',
        source: 'test',
      );

      final event = sink.events.single;
      expect(event.attributes['userIdHash'], isA<String>());
      expect(event.attributes['activeContextKeyHash'], isA<String>());
      expect(event.attributes['targetRoute'], '/invites/:invite');
      expect(event.category, AppLogCategory.navigation);
      expect(event.toJson().toString(), isNot(contains('user-1')));
      expect(event.toJson().toString(), isNot(contains('provider-1')));
      expect(event.toJson().toString(), isNot(contains('private-token')));
      expect(event.toJson().toString(), isNot(contains('secret')));
    },
  );
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}

class _ThrowingRoute extends StatelessWidget {
  const _ThrowingRoute();

  @override
  Widget build(BuildContext context) {
    throw StateError('forced route build failure');
  }
}
