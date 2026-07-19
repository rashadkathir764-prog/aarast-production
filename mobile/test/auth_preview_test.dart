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

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_otp_field.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
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
  return Builder(
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const AuthBrandMark(compact: true),
          const SizedBox(height: 26),
          Text(
            'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ادخل بحسابك لمتابعة تنظيم زفافك بسهولة.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          AuthPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: TextEditingController(text: '777123456'),
                  label: 'رقم الهاتف',
                  hint: 'مثال: 77xxxxxxx',
                  icon: Icons.phone_rounded,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: TextEditingController(text: '••••••••'),
                  label: 'كلمة المرور',
                  icon: Icons.lock_rounded,
                  obscureText: false,
                  suffixIcon: const Icon(Icons.visibility_rounded),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AarastButton(
                  label: 'تسجيل الدخول',
                  icon: Icons.login_rounded,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'ليس لديك حساب؟',
            action: 'إنشاء حساب',
            onTap: () {},
          ),
        ],
      );
    },
  );
}

Widget _otpBody() {
  return Builder(
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'تأكيد رقم الهاتف',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'أدخل رمز التحقق إذا وصلك عبر واتساب\nلإكمال إعداد الحساب.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          AuthPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AarastOtpField(
                  controller: TextEditingController(text: '123456'),
                  enabled: false,
                ),
                const SizedBox(height: 22),
                AarastButton(
                  label: 'تأكيد الرمز',
                  icon: Icons.verified_rounded,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'لم تستلم الرمز؟',
            action: 'إعادة الإرسال',
            onTap: () {},
          ),
        ],
      );
    },
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('auth — login (430)', (tester) async {
    await _pump(
      tester,
      AuthWeddingScaffold(child: _loginBody()),
      size: const Size(430, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/auth_login.png'),
    );
  });

  testWidgets('auth — OTP verification (430)', (tester) async {
    await _pump(
      tester,
      AuthWeddingScaffold(child: _otpBody()),
      size: const Size(430, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/auth_otp.png'),
    );
  });
}
