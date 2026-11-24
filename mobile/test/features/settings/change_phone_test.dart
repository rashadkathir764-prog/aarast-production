import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/widgets/change_phone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.14 and g09: moving the account to a new phone number.

/// The code was sent and nothing more needs saying.
const ({String? error, String? notice}) _sent = (error: null, notice: null);

Widget _app({
  required Future<({String? error, String? notice})> Function(String newPhone)
  requestCode,
  required Future<String?> Function(String newPhone, String code) confirmCode,
  String? currentPhone = '+967 777 123 456',
  bool hasPassword = true,
  Future<({String? error, String? notice})> Function()? requestCurrentCode,
  void Function(PhoneChangeProof proof)? onProof,
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
              hasPassword: hasPassword,
              requestCode: requestCode,
              requestCurrentCode: requestCurrentCode ?? () async => _sent,
              confirmCode: (phone, code, proof) {
                onProof?.call(proof);
                return confirmCode(phone, code);
              },
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
      _app(requestCode: (_) async => _sent, confirmCode: (_, _) async => null),
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
            return _sent;
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

      // RA-BE-141: this account proves the change with its password.
      await tester.enterText(
        find.byKey(const Key('change-phone-password')),
        'my-password',
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
          requestCode: (_) async =>
              (error: phoneChangeErrorMessage('PHONE_IN_USE'), notice: null),
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

  // The answer to the request was lost: the code may be in WhatsApp, so
  // the code step opens and says so, without claiming it was sent.
  testWidgets('a code that may have arrived opens the code step and says so', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        requestCode: (_) async => (
          error: null,
          notice: 'ما وصلنا رد، بس الرمز يمكن وصلك على واتساب.',
        ),
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

    expect(find.byKey(const Key('change-phone-code')), findsOneWidget);
    expect(find.textContaining('ما وصلنا رد'), findsOneWidget);
    expect(find.textContaining('أرسلنا لك رمز'), findsNothing);
  });

  // RA-BE-141: the new number's code alone no longer moves the account. An
  // account with a password gives it; one without gets a code on its
  // current number at the same time as the new one's.
  testWidgets('an account with a password proves the change with it', (
    tester,
  ) async {
    final proofs = <PhoneChangeProof>[];
    var currentCodes = 0;
    await tester.pumpWidget(
      _app(
        requestCode: (_) async => _sent,
        requestCurrentCode: () async {
          currentCodes += 1;
          return _sent;
        },
        confirmCode: (_, _) async => null,
        onProof: proofs.add,
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

    expect(currentCodes, 0);
    expect(find.byKey(const Key('change-phone-current-code')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('change-phone-code')),
      '123456',
    );
    await tester.tap(find.text('غيّر الرقم'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب كلمة المرور'), findsOneWidget);
    expect(proofs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('change-phone-password')),
      'my-password',
    );
    await tester.tap(find.text('غيّر الرقم'));
    await tester.pumpAndSettle();
    expect(proofs, [(currentCode: null, currentPassword: 'my-password')]);
  });

  testWidgets('an account without a password proves it with a code to its '
      'current number', (tester) async {
    final proofs = <PhoneChangeProof>[];
    var currentCodes = 0;
    await tester.pumpWidget(
      _app(
        hasPassword: false,
        requestCode: (_) async => _sent,
        requestCurrentCode: () async {
          currentCodes += 1;
          return _sent;
        },
        confirmCode: (_, _) async => null,
        onProof: proofs.add,
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

    expect(currentCodes, 1);
    expect(find.byKey(const Key('change-phone-password')), findsNothing);
    expect(find.text('رمز رقمك الحالي'), findsOneWidget);
    expect(find.textContaining('على +967 777 123 456'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('change-phone-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const Key('change-phone-current-code')),
      '654321',
    );
    await tester.tap(find.text('غيّر الرقم'));
    await tester.pumpAndSettle();
    expect(proofs, [(currentCode: '654321', currentPassword: null)]);
    expect(tester.takeException(), isNull);
  });

  test('the proof refusals read as Arabic actions', () {
    expect(
      phoneChangeErrorMessage('CURRENT_PHONE_CODE_INVALID'),
      'رمز رقمك الحالي غلط أو انتهى.',
    );
    expect(phoneChangeErrorMessage('INVALID_CREDENTIALS'), 'كلمة المرور غلط.');
    expect(
      phoneChangeErrorMessage('PHONE_CHANGE_PROOF_REQUIRED'),
      contains('رمز رقمك الحالي'),
    );
  });
}
