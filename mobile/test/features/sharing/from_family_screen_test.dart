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

    expect(find.text('معك رابط دعوة؟'), findsOneWidget);
    expect(find.text('يوصل على واتساب من صاحب خطة العرس.'), findsOneWidget);
    expect(find.text('رابط الدعوة'), findsOneWidget);
    expect(find.byKey(const ValueKey('from-family-paste')), findsOneWidget);
    expect(find.text('لصق'), findsOneWidget);
    expect(find.text('الدخول بنفس الرقم اللي وصلته الدعوة.'), findsOneWidget);
    expect(find.text('ما في رابط؟'), findsOneWidget);
    expect(
      find.text('رسالة واتساب جاهزة لطلب الدعوة من صاحب الخطة.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('from-family-ask')), findsOneWidget);
    expect(find.text('طلب الدعوة على واتساب'), findsOneWidget);
    expect(find.text('خطة عرس جديدة؟ من هنا'), findsOneWidget);
    final open = tester.widget<JourneyButton>(
      find.byKey(const ValueKey('from-family-open')),
    );
    expect(open.label, 'فتح الرابط');
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

  // D75: the clipboard is private; it is read only when «لصق» is pressed.
  testWidgets('the clipboard is read only on «لصق», then the link opens', (
    tester,
  ) async {
    var clipboardReads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method != 'Clipboard.getData') return null;
        clipboardReads += 1;
        return {'text': 'https://aarast.shadowgardn.com/invites/$_token'};
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);

    expect(clipboardReads, 0);
    expect(find.byKey(const ValueKey('invite-route')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('from-family-paste')));
    await tester.pumpAndSettle();
    expect(clipboardReads, 1);
    expect(
      find.text('https://aarast.shadowgardn.com/invites/$_token'),
      findsOneWidget,
    );
    // Pasting fills the field; opening stays the person's own press.
    expect(find.byKey(const ValueKey('invite-route')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('from-family-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-route')), findsOneWidget);
  });

  testWidgets('«لصق» with nothing copied says what to do', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('from-family-paste')));
    await tester.pumpAndSettle();
    expect(
      find.text('ما في شي منسوخ. انسخ الرابط من رسالة واتساب.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invite-route')), findsNothing);
  });

  testWidgets('without a link, a new plan starts at the door', (tester) async {
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
