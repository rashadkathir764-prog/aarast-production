// Visual preview for the auth surfaces (login + OTP verification). Renders the
// shared wedding-styled auth widgets in the same compositions the real
// LoginScreen / OtpScreen build, with static data (no AuthController), so the
// auth design language can be inspected as golden PNGs without a backend.
//
// Regenerate with:
//   flutter test test/auth_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/pending_registration.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';

import 'support/preview_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MediaQuery(
        // Disables AarastFadeSlide entrance so the golden is deterministic.
        data: const MediaQueryData(disableAnimations: true),
        child: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

Widget _loginBody() {
  final phoneController = TextEditingController(text: '777123456');
  final passwordController = TextEditingController(text: 'password');
  addTearDown(phoneController.dispose);
  addTearDown(passwordController.dispose);

  return Form(
    child: LoginExperience(
      phoneController: phoneController,
      passwordController: passwordController,
      obscurePassword: true,
      isSubmitting: false,
      onSubmit: () {},
      onRequestOtp: () {},
      onResetPassword: () {},
      onTogglePassword: () {},
      onRegister: () {},
    ),
  );
}

/// The real code screen, as a groom saving a plan sees it (a09).
Future<Widget> _otpScreen() async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final auth = AuthController(
    AuthRepository(ApiClient(tokenProvider: storage.readAccessToken), storage),
  );
  return ChangeNotifierProvider<AuthController>.value(
    value: auth,
    child: OtpScreen(
      phone: '+967777123456',
      purpose: 'REGISTER',
      registration: const PendingRegistration(
        name: 'محمد',
        phone: '+967777123456',
        password: 'password',
      ),
    ),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('auth — login (430)', (tester) async {
    await _pump(
      tester,
      AuthWeddingScaffold(
        maxWidth: 460,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        contentAlignment: Alignment.topCenter,
        child: _loginBody(),
      ),
      size: const Size(430, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/auth_login.png'),
    );
  });

  testWidgets('auth — OTP verification (430)', (tester) async {
    await _pump(tester, await _otpScreen(), size: const Size(430, 900));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/auth_otp.png'),
    );
  });
}
