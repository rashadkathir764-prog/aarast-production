import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/pending_registration.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  _backButtonCases();

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'D75: a sign-in code for a number with no account keeps its proof for that number',
    () async {
      final controller = await _controller(
        verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
        verifyPhoneProof: 'proof-token',
      );
      final ok = await controller.verifyOtp(
        phone: '+967777123456',
        purpose: 'LOGIN',
        code: '123456',
      );

      expect(ok, isFalse);
      expect(controller.phoneProofFor('777 123 456'), 'proof-token');
      expect(controller.phoneProofFor('+967777123456'), 'proof-token');
      expect(controller.phoneProofFor('771 111 111'), isNull);
    },
  );

  // RA-MO-111: every request dropped the proof as it began, so a save that
  // failed took it, and «احفظ خطتي بهذا الرقم» left for a new code.
  test('a failed save keeps the proof of the number', () async {
    final controller = await _controller(
      verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
      verifyPhoneProof: 'proof-token',
    );
    await controller.verifyOtp(
      phone: '+967777123456',
      purpose: 'LOGIN',
      code: '123456',
    );

    final saved = await controller.register(
      name: 'صالح',
      phone: '+967777123456',
      phoneProof: controller.phoneProofFor('+967777123456'),
    );

    expect(saved, isFalse);
    expect(controller.phoneProofFor('+967777123456'), 'proof-token');
    expect(controller.phoneProofFor('771 111 111'), isNull);
  });

  testWidgets(
    'D75: an admin number without an app password is offered only another number',
    (tester) async {
      final controller = await _controller(
        registerErrorCode: 'ADMIN_APP_PASSWORD_REQUIRED',
      );
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('لحساب إدارة في اعّرست'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('otp-admin-change-number')),
        findsOneWidget,
      );
      // No way in that cannot work: no sign-in, no password reset.
      expect(find.byKey(const ValueKey('otp-go-to-login')), findsNothing);
      expect(
        find.byKey(const ValueKey('otp-go-to-password-reset')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'registered phone shows Arabic login and password recovery actions at 320px',
    (tester) async {
      final controller = await _controller(
        registerErrorCode: 'ACCOUNT_ALREADY_EXISTS',
      );
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'هذا الرقم عليه حساب من قبل. الدخول له برمز واتساب من «تسجيل الدخول».',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Phone or email'), findsNothing);
      expect(find.byKey(const ValueKey('otp-go-to-login')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('otp-go-to-password-reset')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final loginAction = find.byKey(const ValueKey('otp-go-to-login'));
      await tester.ensureVisible(loginAction);
      await tester.tap(loginAction);
      await tester.pump(const Duration(milliseconds: 100));

      final loginUri = router.routeInformationProvider.value.uri;
      expect(loginUri.path, '/login');
      expect(loginUri.queryParameters['phone'], '+967777123456');
      expect(loginUri.queryParameters['resume'], '/invite/example');
    },
  );

  testWidgets(
    'login OTP uses login copy and back returns with phone and resume',
    (tester) async {
      final controller = await _controller(
        verifyErrorCode: 'OTP_INVALID_OR_EXPIRED',
      );
      final router = _router();
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);

      // A sign-in code speaks of signing in, never of a new account (D7).
      await tester.ensureVisible(
        find.text('بعد الرمز ندخلك حسابك.', skipOffstage: false),
      );
      await tester.pump();
      expect(find.text('بعد الرمز ندخلك حسابك.'), findsOneWidget);
      expect(find.textContaining('ينحفظ حسابك'), findsNothing);

      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.errorMessage, isNotNull);
      // D75: a wrong code is said under the boxes, in the reader's words.
      expect(find.byKey(const ValueKey('otp-wrong')), findsOneWidget);

      await _scrollToTop(tester);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pump(const Duration(milliseconds: 100));

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/login');
      expect(uri.queryParameters['phone'], '+967777123456');
      expect(uri.queryParameters['resume'], '/invite/example');
      expect(controller.errorMessage, isNull);
    },
  );

  testWidgets('registration OTP back returns to registration', (tester) async {
    final controller = await _controller();
    final router = _router(
      registration: const PendingRegistration(
        name: 'مستخدم',
        phone: '+967777123456',
      ),
    );
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);

    final registerCopy = find.text(
      'أول ما تكتمل الأرقام الستة ينحفظ حسابك.',
      skipOffstage: false,
    );
    await tester.ensureVisible(registerCopy);
    await tester.pump();
    expect(
      find.text('أول ما تكتمل الأرقام الستة ينحفظ حسابك.'),
      findsOneWidget,
    );
    await _scrollToTop(tester);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pump(const Duration(milliseconds: 100));

    final uri = router.state.uri;
    expect(uri.path, '/register');
    expect(uri.queryParameters['phone'], '+967777123456');
    expect(uri.queryParameters['resume'], '/invite/example');
  });

  testWidgets('OTP password recovery preserves phone and resume', (
    tester,
  ) async {
    final controller = await _controller(
      registerErrorCode: 'ACCOUNT_ALREADY_EXISTS',
    );
    final router = _router(
      registration: const PendingRegistration(
        name: 'مستخدم',
        phone: '+967777123456',
      ),
    );
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);
    await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final resetAction = find.byKey(const ValueKey('otp-go-to-password-reset'));
    await tester.ensureVisible(resetAction);
    await tester.tap(resetAction);
    await tester.pump(const Duration(milliseconds: 100));

    final uri = router.state.uri;
    expect(uri.path, '/reset-password');
    expect(uri.queryParameters['phone'], '+967777123456');
    expect(uri.queryParameters['resume'], '/invite/example');
  });

  testWidgets('login password recovery preserves phone and resume', (
    tester,
  ) async {
    final controller = await _controller();
    final router = GoRouter(
      initialLocation:
          '/login?phone=%2B967777123456&resume=%2Finvite%2Fexample',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginScreen(initialPhone: state.uri.queryParameters['phone']),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => Text(
            'reset:${state.uri.queryParameters['phone']}:'
            '${state.uri.queryParameters['resume']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);
    await tester.pumpAndSettle();
    // D75: sign-in is by code first; the password (and its recovery) is
    // the second way.
    expect(
      find.byKey(const ValueKey('login-forgot-password-action')),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-mode')));
    await tester.tap(find.byKey(const ValueKey('login-mode')));
    await tester.pumpAndSettle();
    final resetAction = find.byKey(
      const ValueKey('login-forgot-password-action'),
    );
    await tester.ensureVisible(resetAction);
    await tester.pumpAndSettle();
    await tester.tap(resetAction);
    await tester.pumpAndSettle();

    expect(find.text('reset:+967777123456:/invite/example'), findsOneWidget);
  });

  // RA-MO-119: a check that never reached the server wiped the code typed,
  // with nothing to check it again.
  testWidgets('a check lost to the network keeps the code and offers again', (
    tester,
  ) async {
    final controller = await _controller(verifyOffline: true);
    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);
    await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('otp-code-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '123456');
    expect(find.byKey(const ValueKey('otp-retry-verify')), findsOneWidget);
  });

  testWidgets('missing account after a sign-in code starts again at the door', (
    tester,
  ) async {
    final controller = await _controller(
      verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
    );
    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);
    await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('هذا الرقم ما عليه حساب في اعّرست'),
      findsOneWidget,
    );
    expect(find.text('ابدأ من هنا'), findsOneWidget);
    final registerAction = find.byKey(const ValueKey('otp-go-to-register'));
    expect(registerAction, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(registerAction);
    await tester.tap(registerAction);
    await tester.pump(const Duration(milliseconds: 100));

    // D75: there is no account to sign up from here; the door asks
    // what the person came for (a plan, an invite, a service).
    final registerUri = router.routeInformationProvider.value.uri;
    expect(registerUri.path, '/welcome');
    expect(controller.errorCode, isNull);
  });

  testWidgets(
    'successful registration returns to the private invite with a one-shot resume token',
    (tester) async {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
      final controller = await _controller(registrationSucceeds: true);
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
        successLocation: '/invites/$token',
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      final postAuthUri = router.routeInformationProvider.value.uri;
      expect(postAuthUri.path, '/invites/$token');
      expect(controller.status, AuthStatus.authenticated);
      // No plan on the phone to save: nothing is imported on its own.
      expect(controller.accountJustCreated, isFalse);
      expect(controller.signUpFoundAccount, isFalse);
      expect(controller.hasPendingInviteResume, isFalse);
      expect(controller.claimPendingInviteResumeRoute(), isNull);
      expect(controller.consumePendingInviteResume(token), isTrue);
    },
  );

  testWidgets(
    'D75: a sign-up code for a number with an account signs in to it',
    (tester) async {
      final controller = await _controller(
        registrationSucceeds: true,
        existingAccount: true,
      );
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
        successLocation: '/home',
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.errorCode, isNull);
      expect(controller.signUpFoundAccount, isTrue);
      expect(controller.accountJustCreated, isFalse);
      expect(find.byKey(const ValueKey('otp-go-to-login')), findsNothing);
    },
  );
}

// RA-MO-112: only the arrow on screen cleared the code screen's error. Left
// by the phone's back button, «الرمز غلط…» stayed and showed on the number
// screen, over «أرسل الرمز».
void _backButtonCases() {
  testWidgets('leaving the code screen by the phone\'s back button takes its '
      'error with it', (tester) async {
    final controller = await _controller(
      verifyErrorCode: 'OTP_INVALID_OR_EXPIRED',
    );
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const Text('the number screen'),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) => const OtpScreen(
            phone: '+967777123456',
            purpose: 'LOGIN',
            successLocation: '/home',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);
    unawaited(router.push('/otp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(controller.errorMessage, isNotNull, reason: 'the code was refused');

    // The system's back, not the arrow on screen.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('the number screen'), findsOneWidget);
    expect(controller.errorMessage, isNull);
  });
}

/// The page scrolls at 320 px and 1.3x text; back is at its top.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required AuthController controller,
  required GoRouter router,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        routerConfig: router,
        builder: (context, child) => AarastAuthFlowRedirector(
          router: router,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

GoRouter _router({
  PendingRegistration? registration,
  String successLocation = '/invite/example',
}) {
  return GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(
          phone: '+967777123456',
          purpose: registration == null ? 'LOGIN' : 'REGISTER',
          registration: registration,
          successLocation: successLocation,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => Text(
          'login:${state.uri.queryParameters['phone']}:'
          '${state.uri.queryParameters['resume']}',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => Text(
          'reset:${state.uri.queryParameters['phone']}:'
          '${state.uri.queryParameters['resume']}',
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => Text(
          'register:${state.uri.queryParameters['phone']}:'
          '${state.uri.queryParameters['resume']}',
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const Text('welcome'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            Text('home:${state.uri.queryParameters['resume']}'),
      ),
      GoRoute(
        path: '/invites/:token',
        builder: (context, state) =>
            const SizedBox(key: ValueKey('private-invite-resume-destination')),
      ),
    ],
  );
}

Future<AuthController> _controller({
  String? registerErrorCode,
  String? verifyErrorCode,
  bool registrationSucceeds = false,
  bool existingAccount = false,
  String? verifyPhoneProof,
  bool verifyOffline = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
  final controller = AuthController(
    _RecoveryRepository(
      apiClient,
      storage,
      registerErrorCode: registerErrorCode,
      verifyErrorCode: verifyErrorCode,
      registrationSucceeds: registrationSucceeds,
      existingAccount: existingAccount,
      verifyPhoneProof: verifyPhoneProof,
      verifyOffline: verifyOffline,
    ),
  );
  await controller.restoreSession();
  return controller;
}

class _RecoveryRepository extends AuthRepository {
  _RecoveryRepository(
    super.apiClient,
    super.authStorage, {
    this.registerErrorCode,
    this.verifyErrorCode,
    this.registrationSucceeds = false,
    this.existingAccount = false,
    this.verifyPhoneProof,
    this.verifyOffline = false,
  });

  /// The code's check never reaches the server.
  final bool verifyOffline;
  final String? verifyPhoneProof;
  final String? registerErrorCode;
  final String? verifyErrorCode;
  final bool registrationSucceeds;
  final bool existingAccount;

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    String? otpCode,
    String? phoneProof,
  }) async {
    if (registrationSucceeds) {
      return AuthResponse(
        accessToken: 'registered-access-token',
        refreshToken: 'registered-refresh-token',
        existingAccount: existingAccount,
        user: const SafeUser(
          id: 'invitee-1',
          name: 'مستخدم',
          phone: '+967777123456',
          role: 'USER',
          status: 'ACTIVE',
        ),
      );
    }
    throw ApiException(
      'backend registration error',
      statusCode: 409,
      serverCode: registerErrorCode,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    if (verifyOffline) {
      throw const ApiException('ما وصلنا', isNetworkFailure: true);
    }
    throw ApiException(
      'backend OTP error',
      statusCode: 404,
      serverCode: verifyErrorCode,
      phoneProof: verifyPhoneProof,
    );
  }
}
