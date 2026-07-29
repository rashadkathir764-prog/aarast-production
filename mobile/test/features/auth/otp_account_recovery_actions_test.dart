import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/pending_registration.dart';
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
    'registered phone shows Arabic login and password recovery actions at 320px',
    (tester) async {
      final controller = await _controller(
        registerErrorCode: 'ACCOUNT_ALREADY_EXISTS',
      );
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
          password: 'secret123',
        ),
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('مسجل بالفعل'), findsOneWidget);
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

      expect(find.text('تسجيل الدخول برمز التحقق'), findsOneWidget);
      expect(find.textContaining('لتسجيل الدخول إلى حسابك'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.errorMessage, isNotNull);

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
        password: 'secret123',
      ),
    );
    addTearDown(router.dispose);

    await _pump(tester, controller: controller, router: router);

    expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
    expect(find.textContaining('لإكمال إعداد الحساب'), findsOneWidget);
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
        password: 'secret123',
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
    final resetAction = find.byKey(
      const ValueKey('login-forgot-password-action'),
    );
    await tester.ensureVisible(resetAction);
    await tester.pumpAndSettle();
    await tester.tap(resetAction);
    await tester.pumpAndSettle();

    expect(find.text('reset:+967777123456:/invite/example'), findsOneWidget);
  });

  testWidgets(
    'missing account after phone proof offers registration with the phone',
    (tester) async {
      final controller = await _controller(
        verifyErrorCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
      );
      final router = _router();
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('تم التحقق من الرقم'), findsOneWidget);
      final registerAction = find.byKey(const ValueKey('otp-go-to-register'));
      expect(registerAction, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(registerAction);
      await tester.tap(registerAction);
      await tester.pump(const Duration(milliseconds: 100));

      final registerUri = router.routeInformationProvider.value.uri;
      expect(registerUri.path, '/register');
      expect(registerUri.queryParameters['phone'], '+967777123456');
      expect(registerUri.queryParameters['resume'], '/invite/example');
    },
  );

  testWidgets(
    'successful registration returns to the private invite with a one-shot resume token',
    (tester) async {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
      final controller = await _controller(registrationSucceeds: true);
      final router = _router(
        registration: const PendingRegistration(
          name: 'مستخدم',
          phone: '+967777123456',
          password: 'secret123',
        ),
        successLocation: '/invites/$token',
      );
      addTearDown(router.dispose);

      await _pump(tester, controller: controller, router: router);
      await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      final postAuthUri = router.routeInformationProvider.value.uri;
      expect(postAuthUri.path, '/home');
      expect(postAuthUri.queryParameters['resume'], '/invites/$token');
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.claimPendingInviteResumeRoute(), token);
      expect(controller.claimPendingInviteResumeRoute(), isNull);
    },
  );
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
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
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(
    _RecoveryRepository(
      apiClient,
      storage,
      registerErrorCode: registerErrorCode,
      verifyErrorCode: verifyErrorCode,
      registrationSucceeds: registrationSucceeds,
    ),
  );
}

class _RecoveryRepository extends AuthRepository {
  _RecoveryRepository(
    super.apiClient,
    super.authStorage, {
    this.registerErrorCode,
    this.verifyErrorCode,
    this.registrationSucceeds = false,
  });

  final String? registerErrorCode;
  final String? verifyErrorCode;
  final bool registrationSucceeds;

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
  }) async {
    if (registrationSucceeds) {
      return const AuthResponse(
        accessToken: 'registered-access-token',
        refreshToken: 'registered-refresh-token',
        user: SafeUser(
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
    throw ApiException(
      'backend OTP error',
      statusCode: 404,
      serverCode: verifyErrorCode,
    );
  }
}
