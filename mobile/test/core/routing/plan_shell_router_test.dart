import 'dart:async';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/routing/plan_shell_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The owner's video: from a provider's page into the providers tab, a
// service's requests above it, then «شوف البند في المال». The shell went on the
// stack twice, the screen went black, and every screen after it broke (R2).
GoRouter _router({String initial = '/home'}) => PlanShellRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        appBar: AppBar(title: const Text('shell')),
        body: child,
      ),
      routes: [
        GoRoute(path: '/plan/tab', builder: (_, _) => const Text('tab')),
        GoRoute(path: '/plan/cost', builder: (_, _) => const Text('cost')),
        GoRoute(path: '/plan/pay', builder: (_, _) => const Text('pay')),
      ],
    ),
    GoRoute(
      path: '/requests',
      builder: (_, _) => const Scaffold(body: Text('requests')),
    ),
    GoRoute(
      path: '/chat',
      builder: (_, _) => const Scaffold(body: Text('chat')),
    ),
  ],
);

Future<void> _open(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _step(WidgetTester tester, void Function() move) async {
  move();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the video: a pushed shell, a page above it, a shell page', (
    tester,
  ) async {
    final router = _router();
    await _open(tester, router);

    await _step(tester, () => router.push('/plan/tab'));
    await _step(tester, () => router.push('/requests'));
    await _step(tester, () => router.push('/plan/cost'));

    expect(find.text('cost'), findsOneWidget);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('every screen after it still opens', (tester) async {
    final router = _router(initial: '/plan/tab');
    await _open(tester, router);

    await _step(tester, () => router.push('/requests'));
    await _step(tester, () => router.push('/plan/cost'));
    await _step(tester, () => router.push('/chat'));
    await _step(tester, () => router.push('/plan/pay'));
    await _step(tester, () => router.go('/plan/tab'));
    await _step(tester, () => router.push('/requests'));

    expect(find.text('requests'), findsOneWidget);
  });

  testWidgets('a page inside the shell still pushes, so back returns', (
    tester,
  ) async {
    final router = _router(initial: '/plan/tab');
    await _open(tester, router);

    await _step(tester, () => router.push('/plan/cost'));
    expect(find.text('cost'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('tab'), findsOneWidget);
  });

  testWidgets('a page above the shell still opens another outside page', (
    tester,
  ) async {
    final router = _router(initial: '/plan/tab');
    await _open(tester, router);

    await _step(tester, () => router.push('/requests'));
    await _step(tester, () => router.push('/chat'));
    expect(find.text('chat'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('requests'), findsOneWidget);
  });

  testWidgets('no shell on the stack pushes as before', (tester) async {
    final router = _router();
    await _open(tester, router);

    unawaited(router.push('/requests'));
    await tester.pumpAndSettle();
    await _step(tester, () => router.push('/plan/cost'));

    expect(find.text('cost'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('requests'), findsOneWidget);
  });

  testWidgets('pushReplacement and replace above the shell keep one shell', (
    tester,
  ) async {
    final router = _router(initial: '/plan/tab');
    await _open(tester, router);

    await _step(tester, () => router.push('/requests'));
    await _step(tester, () => router.pushReplacement('/plan/cost'));
    expect(find.text('cost'), findsOneWidget);

    await _step(tester, () => router.push('/requests'));
    await _step(tester, () => router.replace('/plan/pay'));
    expect(find.text('pay'), findsOneWidget);
    expect(find.text('shell'), findsOneWidget);
  });

  test('the app runs on the router that keeps one shell', () {
    final router = AppRouter.create();
    addTearDown(router.dispose);
    expect(router, isA<PlanShellRouter>());
  });
}
