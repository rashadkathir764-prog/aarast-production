import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mobile displays dev OTP helper only for local dev responses', (
    tester,
  ) async {
    final authController = await _authController();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(
            phone: '+967777123456',
            purpose: 'VERIFY_PHONE',
            otpNoticeMessage: 'رمز التحقق مؤقت للتجربة المحلية: 123456',
          ),
        ),
      ),
    );

    expect(
      find.text('رمز التحقق مؤقت للتجربة المحلية: 123456'),
      findsOneWidget,
    );
  });

  testWidgets('mobile hides dev OTP helper for production OTP responses', (
    tester,
  ) async {
    final authController = await _authController();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(phone: '+967777123456', purpose: 'VERIFY_PHONE'),
        ),
      ),
    );

    expect(
      find.textContaining('رمز التحقق مؤقت للتجربة المحلية'),
      findsNothing,
    );
    expect(find.byType(AuthBrandMark), findsNothing);
  });

  testWidgets('OTP clears the stale server error when retry input starts', (
    tester,
  ) async {
    final authController = await _authController(failVerify: true);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(phone: '+967777123456', purpose: 'VERIFY_PHONE'),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('otp-code-field')), '999999');
    await tester.pumpAndSettle();
    expect(authController.errorMessage, isNotNull);

    await tester.enterText(find.byKey(const Key('otp-code-field')), '1');
    await tester.pump();
    expect(authController.errorMessage, isNull);
  });

  testWidgets('OTP resend remains disabled for the server cooldown window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authController = await _authController();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: MaterialApp(
          locale: const Locale('ar'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const OtpScreen(
            phone: '+967777123456',
            purpose: 'VERIFY_PHONE',
          ),
        ),
      ),
    );

    expect(find.textContaining('إعادة الإرسال خلال 60 ث'), findsOneWidget);
    final footer = find.byKey(const ValueKey('otp-resend-button'));
    await tester.ensureVisible(footer);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(of: footer, matching: find.byType(TextButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 59));
    expect(find.textContaining('إعادة الإرسال خلال 1 ث'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('لم تستلم الرمز؟ إعادة الإرسال'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(of: footer, matching: find.byType(TextButton)),
          )
          .onPressed,
      isNotNull,
    );
  });
}

Future<AuthController> _authController({bool failVerify = false}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = _TestAuthRepository(
    apiClient,
    authStorage,
    failVerify: failVerify,
  );
  return AuthController(authRepository);
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository(
    super.apiClient,
    super.authStorage, {
    required this.failVerify,
  });

  final bool failVerify;

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    if (failVerify) {
      throw const ApiException('OTP code is invalid or expired');
    }
    return OtpVerifyResult(verified: true, phone: phone, purpose: purpose);
  }
}
