import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.apiClient, super.authStorage);

  int requestCalls = 0;
  String? lastConfirmPhone;
  String? lastConfirmCode;
  String? lastConfirmPassword;
  bool failConfirm = false;
  String? confirmFailureCode;
  bool failRequestWithNetworkError = false;
  ApiException? requestFailure;
  String delivery = 'LOCAL_DEV';
  String? deliveryMessage = 'رمز التحقق مؤقت للتجربة المحلية: 123456';

  @override
  Future<OtpRequestResult> requestPasswordReset({required String phone}) async {
    requestCalls += 1;
    if (failRequestWithNetworkError) {
      throw const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      );
    }
    if (requestFailure != null) throw requestFailure!;
    return OtpRequestResult(
      phone: phone,
      purpose: 'RESET_PASSWORD',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: delivery,
      code: delivery == 'LOCAL_DEV' ? '123456' : null,
      message: deliveryMessage,
    );
  }

  final List<String> loginCalls = [];

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    loginCalls.add('$phone:$password');
    throw const ApiException(
      'تعذر الدخول للاختبار.',
      statusCode: 401,
      serverCode: 'INVALID_CREDENTIALS',
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (failConfirm) {
      throw ApiException(
        confirmFailureCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF'
            ? 'تم التحقق من الرقم، لكن لا يوجد حساب تطبيق مرتبط به. أنشئ حسابًا جديدًا للمتابعة.'
            : 'رمز التحقق غير صحيح أو انتهت صلاحيته.',
        serverCode: confirmFailureCode ?? 'OTP_INVALID_OR_EXPIRED',
      );
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

final _primary = find.byKey(const ValueKey('reset-primary-action'));

/// «رقمك»: the number, then «أرسل الرمز».
Future<void> _sendCode(WidgetTester tester, {bool typePhone = true}) async {
  if (typePhone) {
    await tester.enterText(find.byType(TextFormField).first, '777123456');
  }
  await tester.tap(find.text('أرسل الرمز'));
  await tester.pumpAndSettle();
}

/// «الرمز»: six digits move on to «كلمة جديدة».
Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('reset-otp-field')), code);
  await tester.pumpAndSettle();
}

/// «كلمة جديدة»: both fields, then «حفظ وتسجيل الدخول».
Future<void> _savePassword(
  WidgetTester tester,
  String password, {
  String? again,
  bool settle = true,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), password);
  await tester.enterText(fields.at(1), again ?? password);
  await tester.ensureVisible(_primary);
  await tester.tap(find.text('حفظ وتسجيل الدخول'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('w01 walks «رقمك» → «الرمز» → «كلمة جديدة» → done', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    // w01: the sub-header, the three named steps and the kit's button.
    expect(find.text('نسيت كلمة المرور'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-steps')), findsOneWidget);
    expect(find.text('رقمك'), findsOneWidget);
    expect(find.text('الرمز'), findsOneWidget);
    expect(find.text('كلمة جديدة'), findsOneWidget);
    expect(find.byType(AuthBrandMark), findsNothing);
    expect(tester.widget(_primary), isA<JourneyButton>());

    await _sendCode(tester);

    expect(repository.requestCalls, 1);
    expect(find.text('أرسلنا لك رمز على واتساب'), findsOneWidget);
    expect(
      find.text('رمز التحقق مؤقت للتجربة المحلية: 123456'),
      findsOneWidget,
    );

    await _typeCode(tester, '123456');
    expect(find.text('اختر كلمة مرور جديدة'), findsOneWidget);
    expect(find.text('6 أحرف أو أكثر'), findsOneWidget);
    expect(find.textContaining('بنطلعك من كل الأجهزة'), findsOneWidget);

    await _savePassword(tester, 'new-secret');

    expect(repository.lastConfirmCode, '123456');
    expect(repository.lastConfirmPassword, 'new-secret');
    expect(find.byKey(const Key('otp-success-panel')), findsNothing);
    expect(find.text('غيّرنا كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('reset flow blocks mismatched password confirmation', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '123456');
    await _savePassword(tester, 'new-secret', again: 'different');

    expect(find.text('ما تطابقت مع الكلمة الجديدة'), findsOneWidget);
    expect(repository.lastConfirmPassword, isNull);
  });

  testWidgets('a short code stays on «الرمز»', (tester) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '123');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب الرمز كامل'), findsOneWidget);
    expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);
    expect(find.text('اختر كلمة مرور جديدة'), findsNothing);
  });

  testWidgets('a refused code goes back to «الرمز» with the server error', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..failConfirm = true;
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '999999');
    await _savePassword(tester, 'new-secret');

    expect(find.text('رمز التحقق غير صحيح أو انتهت صلاحيته.'), findsOneWidget);
    expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);
    expect(find.text('غيّرنا كلمة المرور'), findsNothing);

    await tester.enterText(find.byKey(const Key('reset-otp-field')), '1');
    await tester.pump();
    expect(find.text('رمز التحقق غير صحيح أو انتهت صلاحيته.'), findsNothing);
  });

  testWidgets('verified missing account offers account creation in Arabic', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..failConfirm = true
      ..confirmFailureCode = 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '123456');
    await _savePassword(tester, 'new-secret');

    expect(find.textContaining('لا يوجد حساب تطبيق'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reset-create-account-action')),
      findsOneWidget,
    );
    expect(find.text('أنشئ حساب جديد بهذا الرقم'), findsOneWidget);
    expect(find.textContaining('No account'), findsNothing);
  });

  testWidgets('reset request timeout names the operation instead of login', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..failRequestWithNetworkError = true;
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);

    expect(repository.requestCalls, 1);
    expect(
      find.text('تعذر إرسال رمز الاستعادة الآن. تحقق من الاتصال وحاول مجددًا.'),
      findsOneWidget,
    );
    expect(find.textContaining('تعذر تسجيل الدخول'), findsNothing);
  });

  testWidgets('reset request reports unavailable OTP as a service failure', (
    tester,
  ) async {
    final repository = await _fakeRepository()
      ..requestFailure = const ApiException(
        'تعذر إرسال رمز التحقق عبر واتساب. تأكد أن الرقم صحيح وعليه واتساب، ثم حاول مرة أخرى.',
        statusCode: 503,
        serverCode: 'OTP_DELIVERY_UNAVAILABLE',
      );
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);

    expect(repository.requestCalls, 1);
    expect(
      find.text(
        'تعذر إرسال رمز التحقق عبر واتساب. تأكد أن الرقم صحيح وعليه واتساب، ثم حاول مرة أخرى.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('كلمة المرور غير صحيحة'), findsNothing);
  });

  testWidgets(
    'uncertain WhatsApp delivery opens code entry and shows its notice',
    (tester) async {
      const notice =
          'قد يستغرق وصول الرمز لحظات. إذا وصلك الرمز فأدخله، وإن لم يصل فأعد الإرسال بعد انتهاء المهلة.';
      final repository = await _fakeRepository()
        ..delivery = 'WHATSAPP'
        ..deliveryMessage = notice;
      await _pumpResetScreen(tester, repository);

      await _sendCode(tester);

      expect(repository.requestCalls, 1);
      expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);
      expect(find.text(notice), findsOneWidget);
      expect(
        find.text('خدمة التحقق غير مفعلة حاليًا. حاول لاحقًا.'),
        findsNothing,
      );
    },
  );

  testWidgets('reset resend stays disabled for the full 60-second cooldown', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);

    final resend = find.byKey(const ValueKey('reset-otp-resend-button'));
    VoidCallback? onTap() => tester
        .widget<AarastPressable>(
          find.descendant(of: resend, matching: find.byType(AarastPressable)),
        )
        .onTap;
    expect(repository.requestCalls, 1);
    expect(find.text('ما وصلك؟ نعيد الإرسال بعد 1:00'), findsOneWidget);
    expect(onTap(), isNull);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('ما وصلك؟ نعيد الإرسال بعد 0:01'), findsOneWidget);
    expect(onTap(), isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ما وصلك؟ أرسل رمز جديد'), findsOneWidget);
    expect(onTap(), isNotNull);

    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pump();
    expect(repository.requestCalls, 2);
    expect(find.text('ما وصلك؟ نعيد الإرسال بعد 1:00'), findsOneWidget);
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

    await _sendCode(tester);
    expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _typeCode(tester, '123456');
    expect(find.text('اختر كلمة مرور جديدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reset blocks passwords above 72 UTF-8 bytes at 320px and 1.3 scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = await _fakeRepository();
      await _pumpResetScreen(tester, repository, textScale: 1.3);

      await _sendCode(tester);
      await _typeCode(tester, '123456');
      await _savePassword(tester, 'ك' * 37);

      expect(find.textContaining('كلمة المرور طويلة جدًا'), findsOneWidget);
      expect(repository.lastConfirmPassword, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reset accepts a password exactly 72 UTF-8 bytes', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '123456');
    final boundaryArabicPassword = 'ك' * 36;
    await _savePassword(tester, boundaryArabicPassword, settle: false);

    expect(repository.lastConfirmPassword, boundaryArabicPassword);
    await tester.pumpAndSettle();
  });

  testWidgets('reset success returns to login with phone and invite resume', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    final router = GoRouter(
      initialLocation:
          '/reset-password?phone=%2B967777123456&resume=%2Finvite%2Fexample',
      routes: [
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => ResetPasswordScreen(
            initialPhone: state.uri.queryParameters['phone'],
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => Text(
            'login:${state.uri.queryParameters['phone']}:'
            '${state.uri.queryParameters['resume']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider<AuthRepository>.value(
        value: repository,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await _sendCode(tester, typePhone: false);
    await _typeCode(tester, '123456');
    await _savePassword(tester, 'new-secret');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/login');
    expect(uri.queryParameters['phone'], '+967777123456');
    expect(uri.queryParameters['resume'], '/invite/example');
  });

  // w01: the reset signs every device out, so the app signs in again with
  // the new password; when that fails, «تسجيل الدخول» stays.
  testWidgets('reset confirm signs in again with the new password', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    final auth = AuthController(repository);
    await auth.restoreSession();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: repository),
          ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/reset-password',
            routes: [
              GoRoute(
                path: '/reset-password',
                builder: (context, state) => const ResetPasswordScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await _sendCode(tester);
    await _typeCode(tester, '123456');
    await _savePassword(tester, 'new-secret');

    expect(repository.lastConfirmPassword, 'new-secret');
    expect(repository.loginCalls, ['+967777123456:new-secret']);
    expect(find.text('غيّرنا كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('the back arrow walks the steps back before it leaves', (
    tester,
  ) async {
    final repository = await _fakeRepository();
    await _pumpResetScreen(tester, repository);

    await _sendCode(tester);
    await _typeCode(tester, '123456');
    expect(find.text('اختر كلمة مرور جديدة'), findsOneWidget);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-otp-field')), findsOneWidget);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب رقمك'), findsOneWidget);
  });
}
