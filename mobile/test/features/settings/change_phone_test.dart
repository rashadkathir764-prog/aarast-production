import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/widgets/change_phone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.14 and g09: moving the account to a new phone number.

Widget _app({
  required Future<String?> Function(String newPhone) requestCode,
  required Future<String?> Function(String newPhone, String code) confirmCode,
  String? currentPhone = '+967 777 123 456',
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('settings-change-phone'),
            onPressed: () => showChangePhoneSheet(
              context,
              currentPhone: currentPhone,
              requestCode: requestCode,
              confirmCode: confirmCode,
            ),
            child: const Text('افتح'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('server codes read as Arabic actions', () {
    expect(phoneChangeErrorMessage('PHONE_IN_USE'), contains('لحساب آخر'));
    expect(phoneChangeErrorMessage('PHONE_UNCHANGED'), 'هذا هو رقمك الحالي.');
    expect(phoneChangeErrorMessage('OTHER'), isNull);
  });

  testWidgets('g09 draws the number now, the new one and the note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(requestCode: (_) async => null, confirmCode: (_, _) async => null),
    );
    await tester.tap(find.byKey(const Key('settings-change-phone')));
    await tester.pumpAndSettle();

    // A journey sheet, as every sheet (D30).
    expect(find.byKey(const ValueKey('journey-sheet-handle')), findsOneWidget);
    expect(find.text('تغيير رقم الجوال'), findsOneWidget);
    expect(find.text('رقمك الحالي'), findsOneWidget);
    expect(find.text('+967 777 123 456'), findsOneWidget);
    expect(find.byType(JourneyTextField), findsOneWidget);
    expect(find.text('الرقم الجديد'), findsOneWidget);
    expect(find.textContaining('خطتك ومشاركينك يبقون'), findsOneWidget);
    expect(find.textContaining('بنطلعك من كل الأجهزة'), findsOneWidget);
    expect(find.text('أرسل الرمز للرقم الجديد'), findsOneWidget);
    // No Material field or old button is left.
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a code goes to a valid new number, then the right code moves it',
    (tester) async {
      final requested = <String>[];
      final confirmed = <String>[];
      await tester.pumpWidget(
        _app(
          requestCode: (phone) async {
            requested.add(phone);
            return null;
          },
          confirmCode: (phone, code) async {
            confirmed.add('$phone:$code');
            return code == '123456' ? null : 'الرمز غير صحيح.';
          },
        ),
      );

      await tester.tap(find.byKey(const Key('settings-change-phone')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('change-phone-number')),
        '12',
      );
      await tester.tap(find.text('أرسل الرمز للرقم الجديد'));
      await tester.pumpAndSettle();
      expect(find.textContaining('رقم جوال يمني صحيح'), findsOneWidget);
      expect(requested, isEmpty);

      await tester.enterText(
        find.byKey(const Key('change-phone-number')),
        '771234567',
      );
      await tester.tap(find.text('أرسل الرمز للرقم الجديد'));
      await tester.pumpAndSettle();
      expect(requested, ['771234567']);
      expect(
        find.textContaining('رمز على واتساب على 771234567'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('change-phone-code')),
        '000000',
      );
      await tester.tap(find.text('غيّر الرقم'));
      await tester.pumpAndSettle();
      expect(find.text('الرمز غير صحيح.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('change-phone-code')),
        '123456',
      );
      await tester.tap(find.text('غيّر الرقم'));
      await tester.pumpAndSettle();
      expect(confirmed.last, '771234567:123456');
      expect(find.byKey(const Key('change-phone-code')), findsNothing);
    },
  );

  testWidgets(
    'a refused number shows the server reason and stays on step one',
    (tester) async {
      await tester.pumpWidget(
        _app(
          requestCode: (_) async => phoneChangeErrorMessage('PHONE_IN_USE'),
          confirmCode: (_, _) async => null,
        ),
      );
      await tester.tap(find.byKey(const Key('settings-change-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('change-phone-number')),
        '771234567',
      );
      await tester.tap(find.text('أرسل الرمز للرقم الجديد'));
      await tester.pumpAndSettle();

      expect(find.textContaining('لحساب آخر'), findsOneWidget);
      expect(find.byKey(const Key('change-phone-number')), findsOneWidget);
    },
  );
}
