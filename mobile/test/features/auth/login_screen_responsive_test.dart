import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_button.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoginExperience keeps its primary fields compact', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final phoneController = TextEditingController(text: '777123456');
    final passwordController = TextEditingController(text: 'password');
    addTearDown(phoneController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        home: AuthWeddingScaffold(
          maxWidth: 460,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          contentAlignment: Alignment.topCenter,
          child: Form(
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    for (final element in fields.evaluate()) {
      final height = tester.getSize(find.byWidget(element.widget)).height;
      expect(height, inInclusiveRange(48, 58));
    }

    final compactActions = {
      'primary login': find.widgetWithText(AarastButton, 'تسجيل الدخول'),
      'WhatsApp OTP': find.byKey(const ValueKey('login-otp-action')),
      'register prompt': find.byKey(const ValueKey('login-register-action')),
    };
    for (final MapEntry(key: label, value: action) in compactActions.entries) {
      expect(action, findsOneWidget);
      expect(
        tester.getSize(action).height,
        inInclusiveRange(48, 50),
        reason: '$label should stay compact',
      );
    }

    final fieldIconButtons = find.descendant(
      of: fields,
      matching: find.byType(IconButton),
    );
    expect(fieldIconButtons, findsOneWidget);
    for (final element in fieldIconButtons.evaluate()) {
      final style = IconButtonTheme.of(element).style;
      expect(style?.backgroundColor?.resolve({}), Colors.transparent);
      expect(style?.side?.resolve({}), BorderSide.none);
    }
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.3, 2.0]) {
    testWidgets(
      'LoginExperience stays RTL-safe at 320px and ${textScale}x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 760);
        addTearDown(tester.view.reset);

        final phoneController = TextEditingController(text: '777123456');
        final passwordController = TextEditingController(text: 'password');
        addTearDown(phoneController.dispose);
        addTearDown(passwordController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: AuthWeddingScaffold(
              maxWidth: 460,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              contentAlignment: Alignment.topCenter,
              child: Form(
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
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('خطتك بانتظارك.'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        final submit = find.widgetWithText(AarastButton, 'تسجيل الدخول');
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(submit, findsOneWidget);
        expect(tester.takeException(), isNull);

        final otp = find.byKey(const ValueKey('login-otp-action'));
        await tester.ensureVisible(otp);
        await tester.pumpAndSettle();
        expect(otp, findsOneWidget);
        expect(tester.takeException(), isNull);

        final register = find.byKey(const ValueKey('login-register-action'));
        await tester.ensureVisible(register);
        await tester.pumpAndSettle();
        expect(register, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
