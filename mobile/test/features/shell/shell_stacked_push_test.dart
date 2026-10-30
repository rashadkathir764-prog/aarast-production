import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/routing/pop_or_go.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The route shape behind the plan shell: tabs in a ShellRoute, and a root page
// (a chat, a provider page) that can open a tab again. Pushing that tab put a
// second copy of the shell on the stack (R2).
GoRouter _router() => GoRouter(
  initialLocation: '/plan/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        appBar: AppBar(title: const Text('shell')),
        body: child,
      ),
      routes: [
        GoRoute(
          path: '/plan/home',
          builder: (context, state) => TextButton(
            onPressed: () => context.pushPlanPage('/plan/providers'),
            child: const Text('home'),
          ),
        ),
        GoRoute(
          path: '/plan/providers',
          builder: (context, state) => const Text('providers'),
        ),
      ],
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => Scaffold(
        body: TextButton(
          onPressed: () => context.pushPlanPage('/plan/providers'),
          child: const Text('chat'),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('a page above the shell opens a tab with one shell', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    unawaited(router.push('/chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chat'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('providers'), findsOneWidget);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('a page inside the shell still pushes, so back returns to it', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('providers'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('home'), findsOneWidget);
  });

  test('the pages above the shell open plan pages through pushPlanPage', () {
    const pages = [
      'lib/features/chat/screens/chat_screen.dart',
      'lib/features/marketplace/screens/provider_details_screen.dart',
      'lib/features/marketplace/screens/booking_moment_screen.dart',
      'lib/features/notifications/screens/notifications_screen.dart',
    ];
    final direct = RegExp(
      r'(context\.push|_pushOnce|context\.pushReplacement)(<\w+>)?\(\s*'
      r'AppRouter\.(planProviders|money|tasks|guestList)',
    );
    for (final page in pages) {
      final source = File(page).readAsStringSync();
      expect(direct.hasMatch(source), isFalse, reason: page);
    }
  });
}
