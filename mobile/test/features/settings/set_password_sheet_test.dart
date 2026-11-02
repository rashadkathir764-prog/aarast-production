import 'package:aarast_mobile/features/settings/settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D75: a password is a second way in, added from «حسابي»; changing one
// needs the current one.
void main() {
  Future<List<(String, String?)>> pump(
    WidgetTester tester, {
    required bool hasPassword,
    String? error,
  }) async {
    final saved = <(String, String?)>[];
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
                  save: (next, current) async {
                    saved.add((next, current));
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

  testWidgets('an account without one adds a password', (tester) async {
    final saved = await pump(tester, hasPassword: false);
    expect(find.text('إضافة كلمة مرور'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-password-current')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abc',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.text('6 أحرف أو أكثر'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('set-password-new')),
      'abcdef',
    );
    await tester.tap(find.byKey(const ValueKey('set-password-save')));
    await tester.pumpAndSettle();
    expect(saved, [('abcdef', null)]);
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
      'abcdef',
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
    expect(saved, [('abcdef', 'old-one')]);
    expect(find.text('كلمة المرور الحالية غلط.'), findsOneWidget);
  });
}
