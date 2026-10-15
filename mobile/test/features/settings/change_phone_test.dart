import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/widgets/change_phone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.14: moving the account to a new phone number.

void main() {
  test('server codes read as Arabic actions', () {
    expect(phoneChangeErrorMessage('PHONE_IN_USE'), contains('لحساب آخر'));
    expect(phoneChangeErrorMessage('PHONE_UNCHANGED'), 'هذا هو رقمك الحالي.');
    expect(phoneChangeErrorMessage('OTHER'), isNull);
  });

  testWidgets('a code goes to a valid new number, then the right code moves it', (
    tester,
  ) async {
    final requested = <String>[];
    final confirmed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChangePhoneButton(
            requestCode: (phone) async {
              requested.add(phone);
              return null;
            },
            confirmCode: (phone, code) async {
              confirmed.add('$phone:$code');
              return code == '123456' ? null : 'الرمز غير صحيح.';
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('settings-change-phone')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('change-phone-number')), '12');
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();
    expect(find.textContaining('رقم جوال يمني صحيح'), findsOneWidget);
    expect(requested, isEmpty);

    await tester.enterText(find.byKey(const Key('change-phone-number')), '771234567');
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();
    expect(requested, ['771234567']);
    expect(find.textContaining('أرسلنا رمزًا على واتساب إلى 771234567'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('change-phone-code')), '000000');
    await tester.tap(find.text('تأكيد وتغيير الرقم'));
    await tester.pumpAndSettle();
    expect(find.text('الرمز غير صحيح.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('change-phone-code')), '123456');
    await tester.tap(find.text('تأكيد وتغيير الرقم'));
    await tester.pumpAndSettle();
    expect(confirmed.last, '771234567:123456');
    expect(find.byKey(const Key('change-phone-code')), findsNothing);
  });

  testWidgets('a refused number shows the server reason and stays on step one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChangePhoneButton(
            requestCode: (_) async => phoneChangeErrorMessage('PHONE_IN_USE'),
            confirmCode: (_, _) async => null,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-change-phone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('change-phone-number')), '771234567');
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();

    expect(find.textContaining('لحساب آخر'), findsOneWidget);
    expect(find.byKey(const Key('change-phone-number')), findsOneWidget);
  });
}
