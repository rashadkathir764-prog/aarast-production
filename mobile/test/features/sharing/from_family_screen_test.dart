import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/sharing/screens/from_family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _token = List.filled(43, 'b').join();

void main() {
  test('an invite token is read from a link, a custom link or alone', () {
    expect(
      inviteTokenFromText('https://aarast.shadowgardn.com/invites/$_token'),
      _token,
    );
    expect(inviteTokenFromText('aarast://open/invites/$_token'), _token);
    expect(inviteTokenFromText('  $_token  '), _token);
    expect(inviteTokenFromText('https://example.com/invites/short'), isNull);
    expect(inviteTokenFromText('مرحبا'), isNull);
    expect(inviteTokenFromText(''), isNull);
  });

  testWidgets('x04 draws the ask, the link field and the way back to a plan', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('تساعد في عرس أحد؟'), findsOneWidget);
    expect(
      find.text('العريس أو العروسة يضيفونك من خطتهم،\nويوصلك رابط على واتساب.'),
      findsOneWidget,
    );
    expect(find.text('الصق رابط الدعوة'), findsOneWidget);
    expect(find.text('ما عندك رابط؟'), findsOneWidget);
    expect(find.text('اطلب منه يضيفك'), findsOneWidget);
    expect(find.text('نجهز لك رسالة ترسلها له'), findsOneWidget);
    expect(find.text('أو أنت عريس؟ ابدأ خطتك'), findsOneWidget);
    // Nothing found on the clipboard: no note.
    expect(find.byKey(const ValueKey('from-family-clipboard')), findsNothing);
    final open = tester.widget<JourneyButton>(
      find.byKey(const ValueKey('from-family-open')),
    );
    expect(open.onPressed, isNull);
  });

  testWidgets('a pasted link opens its invite', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('from-family-link')),
      'https://aarast.shadowgardn.com/invites/$_token',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('from-family-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-route')), findsOneWidget);
    expect(find.text(_token), findsOneWidget);
  });

  testWidgets('text that is not an invite says so and stays', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('from-family-link')),
      'aarast.app/j/7KQ2',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('from-family-open')));
    await tester.pumpAndSettle();

    expect(
      find.text('هذا مو رابط دعوة. انسخ الرابط كامل من رسالة واتساب.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invite-route')), findsNothing);
  });

  testWidgets('an invite link on the clipboard is offered and opens', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'https://aarast.shadowgardn.com/invites/$_token'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);

    expect(find.text('لقينا رابط في الحافظة. نفتحه؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('from-family-clipboard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-route')), findsOneWidget);
  });

  testWidgets('a groom without a link goes back to start his own plan', (
    tester,
  ) async {
    await _pump(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('from-family-own-plan')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('from-family-own-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-route')), findsOneWidget);
  });

  testWidgets('x04 fits 320px at 1.3 text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, {double textScale = 1}) async {
  final router = GoRouter(
    initialLocation: '/invites',
    routes: [
      GoRoute(
        path: '/invites',
        builder: (context, state) => const FromFamilyScreen(),
      ),
      GoRoute(
        path: '/invites/:token',
        builder: (context, state) => Scaffold(
          key: const ValueKey('invite-route'),
          body: Text(state.pathParameters['token'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) =>
            const Scaffold(key: ValueKey('welcome-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
