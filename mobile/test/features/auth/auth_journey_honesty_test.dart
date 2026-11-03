import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/pending_registration.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sign-in and sign-up journey tells the truth (J1 audit): a used-up
/// code, an old proof, a second tap, the way back after an expiry, a number
/// that already had an account, and a lost connection on sign-up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('J1-03: an expired or used-up code', () {
    testWidgets('says the server\'s honest words, not "wrong code"', (
      tester,
    ) async {
      final (auth, _) = await _setup(verifyErrorCode: 'OTP_INVALID_OR_EXPIRED');
      final router = _otpRouter();
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('otp-wrong')), findsOneWidget);
      expect(
        find.text('الرمز غلط أو انتهى وقته. اكتبه مرة ثانية أو اطلب رمز جديد.'),
        findsOneWidget,
      );
      expect(find.text('الرمز غلط، جرّب مرة ثانية.'), findsNothing);
      await _drain(tester);
    });

    testWidgets('speaks to a woman in her words', (tester) async {
      final (auth, _) = await _setup(verifyErrorCode: 'OTP_INVALID_OR_EXPIRED');
      final router = _otpRouter();
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router, feminine: true);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'الرمز غلط أو انتهى وقته. اكتبيه مرة ثانية أو اطلبي رمز جديد.',
        ),
        findsOneWidget,
      );
      expect(find.text('الرمز غلط، جرّبي مرة ثانية.'), findsNothing);
      await _drain(tester);
    });

    testWidgets('makes a new code the next move once it can be sent', (
      tester,
    ) async {
      final (auth, repository) = await _setup(
        verifyErrorCode: 'OTP_INVALID_OR_EXPIRED',
      );
      final router = _otpRouter();
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // While the minute runs, the countdown says when.
      expect(find.byKey(const ValueKey('otp-request-new-code')), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      final newCode = find.byKey(const ValueKey('otp-request-new-code'));
      expect(newCode, findsOneWidget);
      expect(
        find.descendant(of: newCode, matching: find.text('اطلب رمز جديد')),
        findsOneWidget,
      );

      await tester.ensureVisible(newCode);
      await tester.tap(newCode);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.requestOtpCalls, 1);
      await _drain(tester);
    });
  });

  group('J1-06: the phone proof lives as long as the server keeps it', () {
    test('a proof older than ten minutes is ignored', () async {
      var now = DateTime(2026, 11, 3, 10);
      final (auth, _) = await _setup(
        verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
        verifyPhoneProof: 'proof-token',
        clock: () => now,
      );
      await auth.verifyOtp(
        phone: '+967777123456',
        purpose: 'LOGIN',
        code: '123456',
      );
      expect(auth.phoneProofFor('777123456'), 'proof-token');

      now = now.add(const Duration(minutes: 9));
      expect(auth.phoneProofFor('777123456'), 'proof-token');
      expect(auth.phoneProof, 'proof-token');

      now = now.add(const Duration(minutes: 1));
      expect(auth.phoneProofFor('777123456'), isNull);
      expect(auth.phoneProof, isNull);
    });

    testWidgets('the sign-up screen asks for a code again once it is old', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 3, 10);
      final (auth, _) = await _setup(
        verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
        verifyPhoneProof: 'proof-token',
        clock: () => now,
      );
      await auth.verifyOtp(
        phone: '+967777123456',
        purpose: 'LOGIN',
        code: '123456',
      );
      const proven = 'تأكدنا من هذا الرقم قبل شوي، فما نحتاج رمز ثاني.';

      await _pumpScreen(
        tester,
        auth: auth,
        child: const RegisterScreen(initialPhone: '777123456'),
      );
      expect(find.text(proven), findsOneWidget);

      now = now.add(const Duration(minutes: 11));
      await _pumpScreen(
        tester,
        auth: auth,
        child: const RegisterScreen(
          key: ValueKey('later'),
          initialPhone: '777123456',
        ),
      );
      expect(find.text(proven), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('register-submit')),
          matching: find.text('أرسل الرمز'),
        ),
        findsOneWidget,
      );
    });
  });

  group('J1-07: the keyboard\'s done never sends twice', () {
    testWidgets('sign-up sends one code request while one is in flight', (
      tester,
    ) async {
      final (auth, repository) = await _setup();
      final hold = Completer<void>();
      repository.hold = hold;
      await _pumpScreen(tester, auth: auth, child: const RegisterScreen());

      await tester.enterText(find.byType(TextField).first, 'مستخدم');
      await tester.enterText(
        find.byKey(const ValueKey('journey-phone-input')),
        '777123456',
      );
      final submitted = _phoneField(tester).onSubmitted!;
      submitted('777 123 456');
      await tester.pump();
      submitted('777 123 456');
      await tester.pump();

      expect(repository.startCalls, 1);
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('sign-in sends one code request while one is in flight', (
      tester,
    ) async {
      final (auth, repository) = await _setup();
      final hold = Completer<void>();
      repository.hold = hold;
      await _pumpScreen(tester, auth: auth, child: const LoginScreen());

      await tester.enterText(
        find.byKey(const ValueKey('journey-phone-input')),
        '777123456',
      );
      final submitted = _phoneField(tester).onSubmitted!;
      submitted('777 123 456');
      await tester.pump();
      submitted('777 123 456');
      await tester.pump();

      expect(repository.requestOtpCalls, 1);
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a password sign-in sends one request while one is in flight', (
      tester,
    ) async {
      final (auth, repository) = await _setup();
      final hold = Completer<void>();
      repository.hold = hold;
      final router = _doorRouter('/login');
      addTearDown(router.dispose);
      await _pumpRouter(tester, auth: auth, router: router);

      await tester.ensureVisible(find.byKey(const ValueKey('login-mode')));
      await tester.tap(find.byKey(const ValueKey('login-mode')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('journey-phone-input')),
        '777123456',
      );
      final passwordField = find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(TextField),
      );
      await tester.enterText(passwordField, 'secret-pass');
      final submitted = tester.widget<TextField>(passwordField).onSubmitted!;
      submitted('secret-pass');
      await tester.pump();
      submitted('secret-pass');
      await tester.pump();

      expect(repository.loginCalls, 1);
      hold.complete();
      await tester.pumpAndSettle();
    });

    test('the controller itself refuses a second request while one is in '
        'flight, whichever button asked', () async {
      final (auth, repository) = await _setup();
      final hold = Completer<void>();
      repository.hold = hold;

      final first = auth.requestOtp(phone: '777123456', purpose: 'REGISTER');
      final second = auth.requestOtp(phone: '777123456', purpose: 'REGISTER');
      expect(repository.requestOtpCalls, 1);
      expect(auth.isSubmitting, isTrue);

      hold.complete();
      await Future.wait([first, second]);
      expect(repository.requestOtpCalls, 1);
      expect(auth.isSubmitting, isFalse);
    });
  });

  group('J1-05: after an expiry, signing in returns where you were', () {
    testWidgets('the expiry sign-in carries the page it left', (tester) async {
      final (auth, _) = await _setup(signedIn: true);
      await auth.restoreSession();
      final router = _pageRouter('/wedding-plans/plan-1/money');
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router);
      expect(find.text('page'), findsOneWidget);

      await auth.handleSessionExpired();
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/login');
      expect(uri.queryParameters['expired'], '1');
      expect(uri.queryParameters['phone'], '+967777123456');
      expect(uri.queryParameters['resume'], '/wedding-plans/plan-1/money');
    });

    test('only a page worth returning to is carried', () {
      expect(
        Uri.parse(
          sessionExpiredLoginLocation(
            phone: '+967777123456',
            from: '/wedding-plans/plan-1/guests?tab=2',
          ),
        ).queryParameters,
        {
          'expired': '1',
          'phone': '+967777123456',
          'resume': '/wedding-plans/plan-1/guests?tab=2',
        },
      );
      for (final from in [
        null,
        '',
        '/',
        '/welcome',
        '/login?expired=1',
        '/otp',
        '/register?type=provider',
        '/reset-password',
        '/onboarding',
        '//evil.example/path',
        'https://evil.example/',
      ]) {
        expect(
          Uri.parse(
            sessionExpiredLoginLocation(phone: null, from: from),
          ).queryParameters,
          {'expired': '1'},
          reason: '$from',
        );
      }
    });
  });

  group('J1-10: a sign-up code for a number that has an account', () {
    test('the account entered is the one the server answers with', () {
      // The server signs in to the existing account and answers with it
      // (auth.service.ts completeRegistration): its user is that account.
      final response = AuthResponse.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'refreshTokenExpiresAt': '2026-12-01T00:00:00.000Z',
        'user': {'id': 'u', 'name': 'سالم', 'role': 'USER', 'status': 'ACTIVE'},
        'existingAccount': true,
      });
      expect(response.existingAccount, isTrue);
      expect(response.user.name, 'سالم');
    });

    testWidgets('says once, on landing, whose account it entered', (
      tester,
    ) async {
      final (auth, _) = await _setup(
        registerSucceeds: true,
        existingAccount: true,
        existingAccountName: 'سالم',
      );
      final router = _otpRouter(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
        successLocation: '/home',
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(
        find.text('هذا الرقم عليه حساب باسم سالم، دخلناك عليه.'),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('without a name, says it plainly', (tester) async {
      // An account whose name is blank: the notice carries no name.
      final (auth, _) = await _setup(
        registerSucceeds: true,
        existingAccount: true,
        existingAccountName: '',
      );
      final router = _otpRouter(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
        successLocation: '/home',
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router, feminine: true);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();

      expect(find.text('هذا الرقم عليه حساب، دخلناكِ عليه.'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a new account hears nothing of the kind', (tester) async {
      final (auth, _) = await _setup(registerSucceeds: true);
      final router = _otpRouter(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
        successLocation: '/home',
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.textContaining('دخلناك'), findsNothing);
      await _drain(tester);
    });
  });

  group('J1-17: a lost connection on sign-up', () {
    test('is not called a failed sign-in', () async {
      final (auth, _) = await _setup(registerOffline: true);
      final ok = await auth.register(
        name: 'مستخدم',
        phone: '+967777123456',
        otpCode: '123456',
      );
      expect(ok, isFalse);
      expect(auth.failedOffline, isTrue);
      expect(
        auth.errorMessage,
        'ما قدرنا ننشئ حسابك الحين، تأكد من النت وجرّب.',
      );
    });

    testWidgets('the code screen says it in the reader\'s words', (
      tester,
    ) async {
      final (auth, _) = await _setup(registerOffline: true);
      final router = _otpRouter(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
        ),
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, auth: auth, router: router, feminine: true);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('ما قدرنا ننشئ حسابك الحين، تأكدي من النت وجرّبي.'),
        findsOneWidget,
      );
      expect(find.textContaining('تعذر تسجيل الدخول'), findsNothing);
      await _drain(tester);
    });

    testWidgets(
      'a proven number\'s sign-up says it of the account, not a code',
      (tester) async {
        final (auth, _) = await _setup(
          verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
          verifyPhoneProof: 'proof-token',
          registerOffline: true,
        );
        await auth.verifyOtp(
          phone: '+967777123456',
          purpose: 'LOGIN',
          code: '123456',
        );
        final router = GoRouter(
          initialLocation: '/register',
          routes: [
            GoRoute(
              path: '/register',
              builder: (context, state) =>
                  const RegisterScreen(initialPhone: '777123456'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await _pumpRouter(tester, auth: auth, router: router);
        await tester.enterText(find.byType(TextField).first, 'مستخدم');
        final submit = find.byKey(const ValueKey('register-submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(
          find.text('ما قدرنا ننشئ حسابك الحين، تأكد من النت وجرّب.'),
          findsOneWidget,
        );
        expect(find.textContaining('ما قدرنا نرسل الرمز'), findsNothing);
      },
    );

    testWidgets('the sign-in screen\'s offline line speaks to a woman', (
      tester,
    ) async {
      final (auth, repository) = await _setup();
      repository.requestOtpOffline = true;
      await _pumpScreen(
        tester,
        auth: auth,
        child: const LoginScreen(),
        feminine: true,
      );

      await tester.enterText(
        find.byKey(const ValueKey('journey-phone-input')),
        '777123456',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('ما قدرنا نوصل، النت مقطوع. جرّبي مرة ثانية.'),
        findsOneWidget,
      );
    });
  });

  group('J1-15: a signed-in person on the sign-in doors', () {
    for (final door in ['/login', '/register']) {
      testWidgets('$door takes them home', (tester) async {
        final (auth, repository) = await _setup(signedIn: true);
        await auth.restoreSession();
        final router = _doorRouter(door);
        addTearDown(router.dispose);

        await _pumpRouter(tester, auth: auth, router: router);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(find.text('home'), findsOneWidget);
        expect(repository.requestOtpCalls + repository.startCalls, 0);
      });
    }
  });
}

TextField _phoneField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const ValueKey('journey-phone-input')));

/// Lets the toasts and the code's countdown run out before the test ends.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required AuthController auth,
  required GoRouter router,
  bool feminine = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        routerConfig: router,
        builder: (context, child) => JourneyProfileScope(
          profile: feminine ? JourneyProfile.bride : JourneyProfile.groom,
          child: AarastAuthFlowRedirector(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AuthController auth,
  required Widget child,
  bool feminine = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        home: JourneyProfileScope(
          profile: feminine ? JourneyProfile.bride : JourneyProfile.groom,
          child: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

GoRouter _otpRouter({
  PendingRegistration? registration,
  String successLocation = '/home',
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
      GoRoute(path: '/home', builder: (context, state) => const Text('home')),
      GoRoute(
        path: '/provider/apply',
        builder: (context, state) => const Text('provider'),
      ),
    ],
  );
}

GoRouter _pageRouter(String initial) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (context, state) => const Text('page'),
      ),
      GoRoute(path: '/login', builder: (context, state) => const Text('login')),
    ],
  );
}

GoRouter _doorRouter(String door) {
  return GoRouter(
    initialLocation: door,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const Text('home')),
    ],
  );
}

const _user = SafeUser(
  id: 'user-1',
  name: 'سالم',
  phone: '+967777123456',
  role: 'USER',
  status: 'ACTIVE',
);

Future<(AuthController, _JourneyRepository)> _setup({
  String? verifyErrorCode,
  String? verifyPhoneProof,
  bool registerSucceeds = false,
  bool registerOffline = false,
  bool existingAccount = false,
  String? existingAccountName,
  bool signedIn = false,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final repository = _JourneyRepository(
    ApiClient(tokenProvider: storage.readAccessToken),
    storage,
    verifyErrorCode: verifyErrorCode,
    verifyPhoneProof: verifyPhoneProof,
    registerSucceeds: registerSucceeds,
    registerOffline: registerOffline,
    existingAccount: existingAccount,
    existingAccountName: existingAccountName,
    signedIn: signedIn,
  );
  final auth = AuthController(
    repository,
    sessionTeardownCoordinator: SessionTeardownCoordinator(
      auth: repository,
      clearLocalAccountData: () async {},
      clearGuestDraft: () async {},
    ),
    clock: clock,
  );
  if (!signedIn) await auth.restoreSession();
  return (auth, repository);
}

class _JourneyRepository extends AuthRepository {
  _JourneyRepository(
    super.apiClient,
    super.authStorage, {
    this.verifyErrorCode,
    this.verifyPhoneProof,
    this.registerSucceeds = false,
    this.registerOffline = false,
    this.existingAccount = false,
    this.existingAccountName,
    this.signedIn = false,
  });

  final String? verifyErrorCode;
  final String? verifyPhoneProof;
  final bool registerSucceeds;
  final bool registerOffline;
  final bool existingAccount;
  final String? existingAccountName;
  final bool signedIn;

  /// Holds the next code request (or password sign-in) in flight.
  Completer<void>? hold;
  bool requestOtpOffline = false;
  int requestOtpCalls = 0;
  int startCalls = 0;
  int loginCalls = 0;

  static const _offline = ApiException('offline', isNetworkFailure: true);

  @override
  SafeUser? readCachedUser() => signedIn ? _user : null;

  @override
  Future<String?> readAccessToken() async => signedIn ? 'access-1' : null;

  @override
  Future<SafeUser> me() async => _user;

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    loginCalls += 1;
    await hold?.future;
    throw const ApiException('nope', statusCode: 401);
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    requestOtpCalls += 1;
    await hold?.future;
    if (requestOtpOffline || hold != null) throw _offline;
    return OtpRequestResult(
      phone: phone,
      purpose: purpose,
      expiresAt: DateTime(2026, 11, 3, 10, 5),
      delivery: 'WHATSAPP',
      deliveryStatus: 'DELIVERED',
    );
  }

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) async {
    startCalls += 1;
    await hold?.future;
    throw _offline;
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    throw ApiException(
      'backend OTP error',
      statusCode: 400,
      serverCode: verifyErrorCode,
      phoneProof: verifyPhoneProof,
    );
  }

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    String? otpCode,
    String? phoneProof,
  }) async {
    if (registerOffline) throw _offline;
    if (!registerSucceeds) {
      throw const ApiException('nope', statusCode: 400);
    }
    // An existing account answers with itself, under its own name.
    return AuthResponse(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      existingAccount: existingAccount,
      user: existingAccount && existingAccountName != null
          ? SafeUser(
              id: _user.id,
              name: existingAccountName!,
              phone: _user.phone,
              role: _user.role,
              status: _user.status,
            )
          : _user,
    );
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {}
}
