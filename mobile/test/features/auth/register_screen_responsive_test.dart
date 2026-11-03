import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The provider's account is its own screen now (p01,
  // provider_register_screen_test.dart); its city and category moved to the
  // joining steps (provider_apply_screen_test.dart).
  testWidgets('RegisterScreen is RTL and overflow-free at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    final auth = await _authController();
    await _pumpRegister(tester, auth: auth, textScale: 1.3);
    await tester.pump();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('حساب جديد'), findsOneWidget);
    // D75: a name and the number, nothing else.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byKey(const ValueKey('journey-phone-input')), findsOneWidget);
    expect(find.text('البريد الإلكتروني اختياري'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('register-submit')),
        matching: find.text('أرسل الرمز'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('register-login')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // D75 replaced the 72-byte password guard: sign-up asks no password at
  // all, and the request carries only the name and the number.
  testWidgets(
    'customer registration asks no password and sends none at 320px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final repository = _RecordingRegistrationRepository(
        ApiClient(tokenProvider: storage.readAccessToken),
        storage,
      );
      final auth = AuthController(repository);
      await _pumpRegister(tester, auth: auth, textScale: 1.3);
      await tester.pumpAndSettle();

      expect(find.textContaining('كلمة المرور'), findsNothing);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'مستخدم جديد');
      await tester.enterText(
        find.byKey(const ValueKey('journey-phone-input')),
        '777123456',
      );
      final submit = find.byKey(const ValueKey('register-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repository.startCalls, 1);
      expect(repository.lastName, 'مستخدم جديد');
      expect(repository.lastPhone, '+967777123456');
      expect(
        find.text('تعذر إرسال رمز إنشاء الحساب للاختبار.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a lost connection says so and keeps the kept plan safe', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final repository = _RecordingRegistrationRepository(
      ApiClient(tokenProvider: storage.readAccessToken),
      storage,
      failure: const ApiException('offline', isNetworkFailure: true),
    );
    final auth = AuthController(repository);
    final guest = await _keptPlan(preferences);
    await _pumpRegister(tester, auth: auth, guest: guest);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('journey-phone-input')),
      '777123456',
    );
    final submit = find.byKey(const ValueKey('register-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(auth.failedOffline, isTrue);
    expect(
      find.text(
        'ما قدرنا نرسل الرمز، ما وصلنا للخادم. خطتك محفوظة على هذا الجوال.',
      ),
      findsOneWidget,
    );
    expect(find.text('أرسل الرمز مرة ثانية'), findsOneWidget);
    // The server's own words are not repeated over the warning.
    expect(find.text('offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Field test Q09: "required" stayed under a field after it was filled.
  testWidgets('a required error clears as soon as the field is filled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final auth = await _authController();
    await _pumpRegister(tester, auth: auth);
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('register-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال مطلوب'), findsOneWidget);
    expect(find.text('الاسم مطلوب'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('journey-phone-input')),
      '777123456',
    );
    await tester.pumpAndSettle();

    expect(find.text('رقم الجوال مطلوب'), findsNothing);
    expect(find.text('الاسم مطلوب'), findsOneWidget);
  });

  // a08b: the plan kept on the phone is named, and its name is not asked
  // again; only the number is (D75: no password).
  for (final textScale in [1.0, 2.0]) {
    testWidgets('saving a kept plan asks only the phone at 320px '
        'and ${textScale}x text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.reset);

      final auth = await _authController();
      final preferences = await SharedPreferences.getInstance();
      final guest = await _keptPlan(preferences);
      await _pumpRegister(
        tester,
        auth: auth,
        guest: guest,
        textScale: textScale,
      );
      await tester.pumpAndSettle();

      expect(find.text('احفظ خطتك'), findsOneWidget);
      final strip = find.text('عرس محمد · صنعاء · 3 بنود', skipOffstage: false);
      await tester.ensureVisible(strip);
      await tester.pumpAndSettle();
      expect(find.text('عرس محمد · صنعاء · 3 بنود'), findsOneWidget);
      expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journey-phone-input'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('اسمك', skipOffstage: false), findsNothing);
      expect(
        find.textContaining('كلمة المرور', skipOffstage: false),
        findsNothing,
      );
      final submit = find.byKey(const ValueKey('register-submit'));
      await tester.ensureVisible(submit);
      expect(
        find.descendant(of: submit, matching: find.text('أرسل الرمز')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<GuestOnboardingStorage> _keptPlan(SharedPreferences preferences) async {
  final guest = GuestOnboardingStorage(preferences);
  await guest.saveDraft(
    GuestOnboardingDraft.quickLocalPlanSetup(
      planName: 'عرس محمد',
      persona: GuestPersona.groom,
      location: WeddingLocationDraft.fromLegacyFields(
        governorate: 'صنعاء',
        city: 'صنعاء',
      ),
      weddingDate: null,
      currency: 'YER',
      startingItemNames: const ['القاعة', 'الذهب', 'الكسوة'],
    ).copyWith(
      guestPlanId: 'local-guest-1',
      createdAt: DateTime(2026, 10, 23),
      isGuestPlan: true,
      needsSync: true,
    ),
  );
  return guest;
}

Future<void> _pumpRegister(
  WidgetTester tester, {
  required AuthController auth,
  GuestOnboardingStorage? guest,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        if (guest != null) Provider<GuestOnboardingStorage>.value(value: guest),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: RegisterScreen(),
        ),
      ),
    ),
  );
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(AuthRepository(client, storage));
}

class _RecordingRegistrationRepository extends AuthRepository {
  _RecordingRegistrationRepository(
    super.apiClient,
    super.authStorage, {
    this.failure = const ApiException('تعذر إرسال رمز إنشاء الحساب للاختبار.'),
  });

  final ApiException failure;
  int startCalls = 0;
  String? lastName;
  String? lastPhone;

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) async {
    startCalls += 1;
    lastName = name;
    lastPhone = phone;
    throw failure;
  }
}
