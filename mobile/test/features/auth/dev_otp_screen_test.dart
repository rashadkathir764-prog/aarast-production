import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
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

  testWidgets('OTP copy never claims delivery for an uncertain request', (
    tester,
  ) async {
    final authController = await _authController(
      otpDeliveryStatus: 'UNCERTAIN',
    );
    await authController.requestOtp(phone: '+967777123456', purpose: 'LOGIN');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(phone: '+967777123456', purpose: 'LOGIN'),
        ),
      ),
    );

    // D7 wording: «طلبنا», never «أرسلنا» or «وصل» while unconfirmed.
    expect(find.text('طلبنا لك رمز على واتساب'), findsOneWidget);
    expect(find.textContaining('أرسلنا'), findsNothing);
    expect(find.text('وصل إلى الرقم'), findsNothing);
  });

  testWidgets('OTP copy says delivered only for a DELIVERED response', (
    tester,
  ) async {
    final authController = await _authController(
      otpDeliveryStatus: 'DELIVERED',
    );
    await authController.requestOtp(phone: '+967777123456', purpose: 'LOGIN');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(phone: '+967777123456', purpose: 'LOGIN'),
        ),
      ),
    );

    expect(find.text('أرسلنا لك رمز على واتساب'), findsOneWidget);
    expect(find.textContaining('طلبنا'), findsNothing);
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

    // D75: while the window runs, the row only says when; nothing to press.
    final footer = find.byKey(
      const ValueKey('otp-resend-button'),
      skipOffstage: false,
    );
    await tester.ensureVisible(footer);
    await tester.pump();
    expect(find.text('نرسله مرة ثانية بعد 1:00'), findsOneWidget);
    expect(
      find.descendant(of: footer, matching: find.byType(AarastPressable)),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('نرسله مرة ثانية بعد 0:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('أرسله مرة ثانية'), findsOneWidget);
    expect(
      tester
          .widget<AarastPressable>(
            find.descendant(of: footer, matching: find.byType(AarastPressable)),
          )
          .onTap,
      isNotNull,
    );

    // «ما وصلني الرمز» opens what to check, with the same ways out.
    final help = find.byKey(const ValueKey('otp-code-help'));
    await tester.ensureVisible(help);
    await tester.pump();
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.byType(JourneyCodeHelpSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AuthController> _authController({
  bool failVerify = false,
  String otpDeliveryStatus = 'PENDING',
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = _TestAuthRepository(
    apiClient,
    authStorage,
    failVerify: failVerify,
    otpDeliveryStatus: otpDeliveryStatus,
  );
  return AuthController(authRepository);
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository(
    super.apiClient,
    super.authStorage, {
    required this.failVerify,
    required this.otpDeliveryStatus,
  });

  final bool failVerify;
  final String otpDeliveryStatus;

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    return OtpRequestResult(
      phone: phone,
      purpose: purpose,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: 'WHATSAPP',
      deliveryStatus: otpDeliveryStatus,
    );
  }

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
