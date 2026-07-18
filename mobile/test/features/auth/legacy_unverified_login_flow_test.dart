import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'correct password for a legacy unverified account requests LOGIN OTP and routes to verification',
    (tester) async {
      final harness = await _LoginHarness.create(
        loginErrorCode: 'PHONE_VERIFICATION_REQUIRED',
      );
      final router = _router();
      addTearDown(router.dispose);

      await _pump(tester, harness.controller, router);
      await tester.enterText(find.byType(TextFormField).at(1), 'correct-pass');
      final submit = find.byType(AarastButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(harness.repository.loginCalls, 1);
      expect(harness.repository.otpCalls, 1);
      expect(harness.repository.lastOtpPurpose, 'LOGIN');
      expect(harness.repository.lastOtpPhone, '+967777123456');
      expect(router.state.uri.path, '/otp');
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.text('delivery pending'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(harness.repository.verifyCalls, 1);
      expect(harness.repository.lastVerifyPurpose, 'LOGIN');
      expect(harness.controller.status, AuthStatus.authenticated);
      expect(router.state.uri.path, '/invite/example');
      expect(
        find.byKey(const ValueKey('legacy-login-success-destination')),
        findsOneWidget,
      );
    },
  );

  testWidgets('wrong password never requests OTP or reveals account state', (
    tester,
  ) async {
    final harness = await _LoginHarness.create(
      loginErrorCode: 'INVALID_CREDENTIALS',
    );
    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, harness.controller, router);
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-pass');
    final submit = find.byType(AarastButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(harness.repository.loginCalls, 1);
    expect(harness.repository.otpCalls, 0);
    expect(router.state.uri.path, '/login');
    expect(find.textContaining('نسيت كلمة المرور'), findsWidgets);
    expect(find.textContaining('يحتاج حساب التطبيق'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AuthController controller,
  GoRouter router,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/login?phone=%2B967777123456&resume=%2Finvite%2Fexample',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(initialPhone: state.uri.queryParameters['phone']),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final args = state.extra! as OtpScreenArgs;
          return OtpScreen(
            phone: args.phone,
            purpose: args.purpose,
            otpNoticeMessage: args.otpNoticeMessage,
            successLocation: args.successLocation,
          );
        },
      ),
      GoRoute(
        path: '/invite/example',
        builder: (context, state) =>
            const SizedBox(key: ValueKey('legacy-login-success-destination')),
      ),
    ],
  );
}

class _LoginHarness {
  const _LoginHarness({required this.controller, required this.repository});

  final AuthController controller;
  final _LegacyLoginRepository repository;

  static Future<_LoginHarness> create({required String loginErrorCode}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final repository = _LegacyLoginRepository(
      ApiClient(tokenProvider: storage.readAccessToken),
      storage,
      loginErrorCode: loginErrorCode,
    );
    return _LoginHarness(
      controller: AuthController(repository),
      repository: repository,
    );
  }
}

class _LegacyLoginRepository extends AuthRepository {
  _LegacyLoginRepository(
    super.apiClient,
    super.authStorage, {
    required this.loginErrorCode,
  });

  final String loginErrorCode;
  int loginCalls = 0;
  int otpCalls = 0;
  int verifyCalls = 0;
  String? lastOtpPhone;
  String? lastOtpPurpose;
  String? lastVerifyPurpose;

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    loginCalls += 1;
    throw ApiException(
      'backend login error',
      statusCode: 401,
      serverCode: loginErrorCode,
    );
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    otpCalls += 1;
    lastOtpPhone = phone;
    lastOtpPurpose = purpose;
    return OtpRequestResult(
      phone: phone,
      purpose: purpose,
      expiresAt: DateTime.utc(2026, 7, 19, 12, 5),
      delivery: 'WHATSAPP',
      deliveryStatus: 'UNCERTAIN',
      message: 'delivery pending',
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    verifyCalls += 1;
    lastVerifyPurpose = purpose;
    return OtpVerifyResult(
      verified: true,
      phone: phone,
      purpose: purpose,
      accessToken: 'legacy-access-token',
      refreshToken: 'legacy-refresh-token',
      user: SafeUser(
        id: 'legacy-user-1',
        name: 'مستخدم قديم',
        phone: phone,
        role: 'USER',
        status: 'ACTIVE',
        phoneVerifiedAt: DateTime.utc(2026, 7, 19, 12),
      ),
    );
  }
}
