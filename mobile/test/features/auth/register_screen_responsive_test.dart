import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
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
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AuthController>.value(value: auth)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: RegisterScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
    expect(find.text('البريد الإلكتروني اختياري'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'customer registration blocks passwords above 72 UTF-8 bytes at 320px',
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
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: RegisterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'مستخدم جديد');
      await tester.enterText(fields.at(1), '777123456');
      await tester.enterText(fields.at(2), 'ك' * 37);
      final submit = find.widgetWithText(JourneyButton, 'إنشاء حساب');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.textContaining('كلمة المرور طويلة جدًا'), findsOneWidget);
      expect(repository.startCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  // Field test Q09: "required" stayed under a field after it was filled.
  testWidgets('a required error clears as soon as the field is filled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final auth = await _authController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AuthController>.value(value: auth)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: RegisterScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(JourneyButton, 'إنشاء حساب');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('رقم الهاتف مطلوب'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '777123456');
    await tester.enterText(fields.at(2), 'Test123456');
    await tester.pumpAndSettle();

    expect(find.text('رقم الهاتف مطلوب'), findsNothing);
    expect(find.text('كلمة المرور مطلوبة'), findsNothing);
    expect(find.text('الاسم مطلوب'), findsOneWidget);
  });

  // a08b: the plan kept on the phone is named, and its name is not asked
  // again; the phone and the password are.
  for (final textScale in [1.0, 2.0]) {
    testWidgets('saving a kept plan asks only phone and password at 320px '
        'and ${textScale}x text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.reset);

      final auth = await _authController();
      final preferences = await SharedPreferences.getInstance();
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
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<GuestOnboardingStorage>.value(value: guest),
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
      await tester.pumpAndSettle();

      expect(find.text('احفظ خطتك'), findsOneWidget);
      expect(find.text('عرس محمد · صنعاء · 3 بنود'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('الاسم'), findsNothing);
      // The action keeps the heading's words.
      expect(find.widgetWithText(JourneyButton, 'احفظ خطتي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(AuthRepository(client, storage));
}

class _RecordingRegistrationRepository extends AuthRepository {
  _RecordingRegistrationRepository(super.apiClient, super.authStorage);

  int startCalls = 0;

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
    required String password,
  }) async {
    startCalls += 1;
    throw const ApiException('تعذر إرسال رمز إنشاء الحساب للاختبار.');
  }
}
