import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/phone/yemeni_phone_normalizer.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:aarast_mobile/features/auth/screens/provider_register_screen.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// p01 «حساب مزود»: the provider's own account. The business is asked after
// the WhatsApp code, in the joining steps.

void main() {
  testWidgets('p01 draws the account fields and the code note', (tester) async {
    final repository = await _repository();
    await _pump(tester, repository);

    expect(find.text('استقبال طلبات العرسان'), findsOneWidget);
    expect(
      find.text('مكان لنشاطك في اعّرست، توصل منه طلبات عروض الأسعار.'),
      findsOneWidget,
    );
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('رقم جوالك'), findsOneWidget);
    // D75: the account is the number and a WhatsApp code; no password.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.textContaining('كلمة المرور'), findsNothing);
    // The four joining steps that follow the code.
    expect(find.text('بعد رمز واتساب، أربع خطوات'), findsOneWidget);
    for (final step in [
      'النشاط ونوعه',
      'مكان العمل',
      'الخدمة وسعرها',
      'معاينة الإعلان وإرساله، ثم المراجعة',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.widgetWithText(JourneyButton, 'أرسل الرمز'), findsOneWidget);
    // Nothing about the business is asked here any more.
    expect(find.text('المدينة'), findsNothing);
    expect(find.text('اسم النشاط'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty press names each missing field and sends nothing', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('الاسم مطلوب'), findsOneWidget);
    expect(find.text('رقم الجوال مطلوب'), findsOneWidget);
    expect(repository.starts, isEmpty);

    await tester.enterText(
      find.byKey(const Key('provider-register-name')).first,
      'علي الشامي',
    );
    await tester.pumpAndSettle();
    expect(find.text('الاسم مطلوب'), findsNothing);
    expect(find.text('رقم الجوال مطلوب'), findsOneWidget);
  });

  testWidgets('the account is started and the code screen leads to joining', (
    tester,
  ) async {
    final repository = await _repository();
    final router = await _pump(tester, repository);

    await _fill(tester);
    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();

    expect(repository.starts, [
      ('علي الشامي', normalizeYemeniPhone('773210455')),
    ]);
    expect(router.state.uri.path, AppRouter.otp);
    final args = router.state.extra! as OtpScreenArgs;
    expect(args.purpose, 'REGISTER');
    expect(args.successLocation, AppRouter.providerApply);
    expect(args.registration?.name, 'علي الشامي');
  });

  testWidgets('a provider page that sent the person here is kept', (
    tester,
  ) async {
    final repository = await _repository();
    final router = await _pump(
      tester,
      repository,
      resume: AppRouter.providerDashboard,
    );

    await _fill(tester);
    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();

    final args = router.state.extra! as OtpScreenArgs;
    expect(args.successLocation, AppRouter.providerDashboard);
  });

  // D75 replaced the password length guards: a wrong number is refused on
  // the phone, and nothing is sent.
  testWidgets('a number that is not Yemeni is refused on the phone', (
    tester,
  ) async {
    final repository = await _repository();
    await _pump(tester, repository);

    await _fill(tester, phone: '12345');
    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال غير صحيح'), findsOneWidget);
    expect(repository.starts, isEmpty);
  });

  testWidgets('the server refusal is shown above the link', (tester) async {
    final repository = await _repository(failStart: true);
    await _pump(tester, repository);

    await _fill(tester);
    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider-register-error')), findsOneWidget);
    expect(find.text('الرقم مسجّل من قبل.'), findsOneWidget);
  });

  testWidgets('«عندي حساب؟» signs in and comes back to joining', (
    tester,
  ) async {
    final repository = await _repository();
    final router = await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('provider-register-login')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.login);
    expect(router.state.uri.queryParameters['resume'], AppRouter.providerApply);
  });

  testWidgets('p01 fits 320 points with the largest text', (tester) async {
    final repository = await _repository();
    await _pump(tester, repository, width: 320, textScale: 1.3);

    await tester.tap(find.byKey(const Key('provider-register-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the register route opens p01 for a provider only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final auth = AuthController(
      AuthRepository(
        ApiClient(tokenProvider: storage.readAccessToken),
        storage,
      ),
    );
    final router = AppRouter.create();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    router.go('${AppRouter.register}?type=provider');
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProviderRegisterScreen), findsOneWidget);

    // Back from the code screen keeps only the resume.
    router.go(
      Uri(
        path: AppRouter.register,
        queryParameters: {'resume': AppRouter.providerApply},
      ).toString(),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProviderRegisterScreen), findsOneWidget);

    router.go(AppRouter.register);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(ProviderRegisterScreen), findsNothing);
  });
}

Future<void> _fill(WidgetTester tester, {String phone = '773210455'}) async {
  await tester.enterText(
    find.byKey(const Key('provider-register-name')).first,
    'علي الشامي',
  );
  await tester.enterText(
    find.byKey(const Key('provider-register-phone')).first,
    phone,
  );
  await tester.pumpAndSettle();
}

Future<_RecordingRepository> _repository({bool failStart = false}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  return _RecordingRepository(
    ApiClient(tokenProvider: storage.readAccessToken),
    storage,
    failStart: failStart,
  );
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _RecordingRepository repository, {
  String? resume,
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.reset);
  final auth = AuthController(repository);
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, _) => ProviderRegisterScreen(resumeLocation: resume),
      ),
      GoRoute(
        path: AppRouter.otp,
        builder: (_, _) => const Scaffold(body: Text('الرمز')),
      ),
      GoRoute(
        path: AppRouter.login,
        builder: (_, _) => const Scaffold(body: Text('الدخول')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _RecordingRepository extends AuthRepository {
  _RecordingRepository(
    super.apiClient,
    super.authStorage, {
    this.failStart = false,
  });

  final bool failStart;
  final starts = <(String, String)>[];

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) async {
    if (failStart) throw const ApiException('الرقم مسجّل من قبل.');
    starts.add((name, phone));
    return OtpRequestResult(
      phone: phone,
      purpose: 'REGISTER',
      expiresAt: DateTime(2030),
      delivery: 'WHATSAPP',
      deliveryStatus: 'DELIVERED',
    );
  }
}
