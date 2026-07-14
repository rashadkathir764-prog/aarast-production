import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.apiClient, super.authStorage);

  int requestCalls = 0;
  String? lastConfirmPhone;
  String? lastConfirmCode;
  String? lastConfirmPassword;
  bool failConfirm = false;
  bool failRequestWithNetworkError = false;

  @override
  Future<OtpRequestResult> requestPasswordReset({required String phone}) async {
    requestCalls += 1;
    if (failRequestWithNetworkError) {
      throw const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      );
    }
    return OtpRequestResult(
      phone: phone,
      purpose: 'RESET_PASSWORD',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: 'LOCAL_DEV',
      code: '123456',
      message: 'رمز التحقق مؤقت للتجربة المحلية: 123456',
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (failConfirm) {
      throw const ApiException('OTP code is invalid or expired');
    }
    lastConfirmPhone = phone;
    lastConfirmCode = code;
    lastConfirmPassword = newPassword;
  }
}

Future<_FakeAuthRepository> _fakeRepository() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  return _FakeAuthRepository(apiClient, authStorage);
}

Future<void> _pumpResetScreen(
  WidgetTester tester,
  _FakeAuthRepository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    Provider<AuthRepository>.value(
      value: repository,
      child: MaterialApp(
        builder: (context, materialChild) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: materialChild!,
        ),
        home: const ResetPasswordScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('reset flow walks phone → code → new password → success', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    expect(find.byType(AuthBrandMark), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, 1);
    expect(
      find.text('رمز التحقق مؤقت للتجربة المحلية: 123456'),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'new-secret');
    await tester.enterText(fields.at(2), 'new-secret');
    await tester.ensureVisible(find.text('تغيير كلمة المرور'));
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(repository.lastConfirmCode, '123456');
    expect(repository.lastConfirmPassword, 'new-secret');

    // لوحة النجاح الموحّدة (✓ الخضراء) تُعرض لثانية قبل خطوة الإتمام.
    expect(find.byKey(const Key('otp-success-panel')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('تم تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('reset flow blocks mismatched password confirmation', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'new-secret');
    await tester.enterText(fields.at(2), 'different');
    await tester.ensureVisible(find.text('تغيير كلمة المرور'));
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(repository.lastConfirmPassword, isNull);
  });

  testWidgets('reset flow surfaces the server error without leaking details', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..failConfirm = true;
    await _pumpResetScreen(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '999999');
    await tester.enterText(fields.at(1), 'new-secret');
    await tester.enterText(fields.at(2), 'new-secret');
    await tester.ensureVisible(find.text('تغيير كلمة المرور'));
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(find.text('OTP code is invalid or expired'), findsOneWidget);
    expect(find.text('تم تغيير كلمة المرور'), findsNothing);

    await tester.enterText(find.byKey(const Key('reset-otp-field')), '1');
    await tester.pump();
    expect(find.text('OTP code is invalid or expired'), findsNothing);
  });

  testWidgets('reset request timeout names the operation instead of login', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..failRequestWithNetworkError = true;
    await _pumpResetScreen(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, 1);
    expect(
      find.text('تعذر إرسال رمز الاستعادة الآن. تحقق من الاتصال وحاول مجددًا.'),
      findsOneWidget,
    );
    expect(find.textContaining('تعذر تسجيل الدخول'), findsNothing);
  });

  testWidgets('reset resend stays disabled for the full 60-second cooldown', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    final resend = find.byKey(const ValueKey('reset-otp-resend-button'));
    expect(repository.requestCalls, 1);
    expect(find.text('إعادة الإرسال خلال 60 ث'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('إعادة الإرسال خلال 1 ث'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة إرسال الرمز'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);

    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pump();
    expect(repository.requestCalls, 2);
    expect(find.text('إعادة الإرسال خلال 60 ث'), findsOneWidget);
  });

  testWidgets('reset confirmation is overflow-free at 320px and 1.3 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository, textScale: 1.3);

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال رمز الاستعادة'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
