import 'package:aarast_mobile/features/settings/settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D75: a password is a second way in, added from «حسابي»; changing one
// needs the current one.
void main() {
  var codeRequests = 0;
  Future<List<(String, String?, String?)>> pump(
    WidgetTester tester, {
    required bool hasPassword,
    String? error,
  }) async {
    codeRequests = 0;
    final saved = <(String, String?, String?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSetPasswordSheet(
                  context,
                  hasPassword: hasPassword,
                  requestCode: () async {
                    codeRequests += 1;
                    return (error: null, notice: null);
                  },
                  save: (next, current, code) async {
                    saved.add((next, current, code));
                    return error;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return saved;
  }

  // RA-BE-141: the first password comes with a code sent to the number.
  testWidgets('an account without one adds a password with a code to its '
      'number', (tester) async {
    final saved = await pump(tester, hasPassword: false);
    expect(find.text('إضافة كلمة مرور'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-password-current')), findsNothing);
    expect(find.byKey(const ValueKey('set-password-code')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abc',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(codeRequests, 0);
    expect(find.text('8 أحرف أو أكثر'), findsWidgets);

    // RA-BE-149: the server takes 8 or more, so 7 are refused here first.
    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abcdefg',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(codeRequests, 0);

    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abcdefgh',
    );
    expect(find.text('أرسل رمز لرقمك'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(codeRequests, 1);
    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('set-password-code')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty, reason: 'no code typed yet');

    await tester.enterText(
      find.byKey(const ValueKey('set-password-code')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, [('abcdefgh', null, '123456')]);
    expect(codeRequests, 1);
    expect(find.text('إضافة كلمة مرور'), findsNothing);
  });

  testWidgets('a change needs the current one and says when it is wrong', (
    tester,
  ) async {
    final saved = await pump(
      tester,
      hasPassword: true,
      error: 'كلمة المرور الحالية غلط.',
    );
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abcdefgh',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('set-password-current')),
      'old-one',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, [('abcdefgh', 'old-one', null)]);
    expect(find.text('كلمة المرور الحالية غلط.'), findsOneWidget);
  });
}
