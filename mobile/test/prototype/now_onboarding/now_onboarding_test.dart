// Captures today's real onboarding screens for the groom before/after review.
//   flutter test test/prototype/now_onboarding/now_onboarding_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/security/app_lock_controller.dart';
import 'package:aarast_mobile/core/security/app_lock_gate.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:aarast_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:aarast_mobile/features/auth/screens/splash_screen.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/local_plan_migration.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/onboarding/screens/local_plan_migration_screen.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  double h = 844,
  List<SingleChildWidget> providers = const [],
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: home,
    ),
  );
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

Future<AuthController> _auth() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  return AuthController(
    _Repo(ApiClient(tokenProvider: storage.readAccessToken), storage),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  Future<List<SingleChildWidget>> gateway() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final yemen = YemenAdministrativeProvider(_YemenApi());
    await yemen.loadGovernorates();
    return [
      Provider<AuthStorage>(create: (_) => AuthStorage(prefs)),
      Provider<GuestOnboardingStorage>(
        create: (_) => GuestOnboardingStorage(prefs),
      ),
      ChangeNotifierProvider<YemenAdministrativeProvider>.value(value: yemen),
    ];
  }

  testWidgets('n01 splash', (tester) async {
    final auth = await _auth();
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(prefs),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/n01_splash.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('n02 path', (tester) async {
    await _shot(
      tester,
      'n02_path',
      const SmartWelcomeScreen(),
      providers: await gateway(),
    );
  });

  testWidgets('n03 role', (tester) async {
    await _shot(
      tester,
      'n03_role',
      const SmartWelcomeScreen(),
      providers: await gateway(),
      act: () async {
        // a02 «أهلًا فيك» → «ابدأ» → a02b «خطة مين؟».
        await tester.tap(find.text('ابدأ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('العريس'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('n04 setup', (tester) async {
    await _shot(
      tester,
      'n04_setup',
      const SmartWelcomeScreen(),
      h: 1000,
      providers: await gateway(),
      act: () async {
        await tester.tap(find.text('ابدأ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('العريس'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
      },
    );
  });

  List<SingleChildWidget> authProviders(AuthController auth) => [
    ChangeNotifierProvider<AuthController>.value(value: auth),
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: _Market()),
  ];

  testWidgets('n05 register', (tester) async {
    await _shot(
      tester,
      'n05_register',
      const RegisterScreen(),
      h: 1100,
      providers: authProviders(await _auth()),
    );
  });

  testWidgets('n06 register errors', (tester) async {
    await _shot(
      tester,
      'n06_register_errors',
      const RegisterScreen(),
      h: 1100,
      providers: authProviders(await _auth()),
      act: () async {
        await tester.tap(find.text('إنشاء حساب').last);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('n07 otp', (tester) async {
    await _shot(
      tester,
      'n07_otp',
      const OtpScreen(phone: '+967777123456', purpose: 'VERIFY_PHONE'),
      providers: authProviders(await _auth()),
    );
  });

  testWidgets('n08 otp wrong', (tester) async {
    await _shot(
      tester,
      'n08_otp_wrong',
      const OtpScreen(phone: '+967777123456', purpose: 'VERIFY_PHONE'),
      providers: authProviders(await _auth()),
      act: () async {
        await tester.enterText(
          find.byKey(const Key('otp-code-field')),
          '999999',
        );
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('n09 login', (tester) async {
    await _shot(
      tester,
      'n09_login',
      const LoginScreen(),
      providers: authProviders(await _auth()),
    );
  });

  testWidgets('n10 reset', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    await _shot(
      tester,
      'n10_reset',
      const ResetPasswordScreen(),
      providers: [
        Provider<AuthRepository>.value(
          value: _Repo(
            ApiClient(tokenProvider: storage.readAccessToken),
            storage,
          ),
        ),
      ],
    );
  });

  // w09: the account already has an open plan, so the phone plan meets it in
  // the choice sheet (real counts for both).
  testWidgets('n11 local draft', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _shot(
      tester,
      'n11_local_draft',
      LocalPlanMigrationScreen(
        snapshot: _snapshot,
        migrationService: _Migration(
          GuestOnboardingStorage(prefs),
          account: const AccountPlanCounts(items: 8, tasks: 12),
        ),
        onFinished: (_) {},
      ),
      h: 1000,
      providers: [Provider<AuthStorage>.value(value: AuthStorage(prefs))],
    );
    expect(find.byType(LocalPlanMigrationScreen), findsOneWidget);
  });

  // An account without an open plan saves the phone plan at once; here the
  // save fails, so the screen offers a retry or dropping the phone plan.
  testWidgets('n11 local draft save failed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _shot(
      tester,
      'n11b_local_draft_failed',
      LocalPlanMigrationScreen(
        snapshot: _snapshot,
        migrationService: _Migration(GuestOnboardingStorage(prefs)),
        onFinished: (_) {},
      ),
      h: 1000,
      providers: [Provider<AuthStorage>.value(value: AuthStorage(prefs))],
    );
  });

  testWidgets('n12 lock', (tester) async {
    final lock = AppLockController(vault: _Vault(), userId: 'u1');
    await _shot(
      tester,
      'n12_lock',
      AppLockScreen(lock: lock, onForgotCode: () async {}),
    );
  });
}

class _Repo extends AuthRepository {
  _Repo(super.apiClient, super.authStorage);

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async => OtpRequestResult(
    phone: phone,
    purpose: purpose,
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    delivery: 'WHATSAPP',
    deliveryStatus: 'PENDING',
  );

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async => throw const ApiException('رمز التحقق غير صحيح أو انتهت صلاحيته.');
}

class _Market extends ProviderMarketplaceProvider {
  _Market() : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  Future<void> loadReferenceData() async {}
}

class _Vault implements SensitiveValueVault {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Migration extends LocalPlanMigrationService {
  _Migration(GuestOnboardingStorage storage, {this.account})
    : super(
        guestStorage: storage,
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
        financeApi: FinanceApi(ApiClient(tokenProvider: () async => null)),
      );

  /// The account's open plan; null means the account has none.
  final AccountPlanCounts? account;

  @override
  Future<AccountPlanCounts?> accountPlanCounts() async => account;

  @override
  Future<OnboardingCompleteResponse> migrate(LocalPlanSnapshot snapshot) =>
      Future.error('x');
}

class _YemenApi extends YemenAdministrativeApi {
  _YemenApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<YemenGovernorate>> getGovernorates() async => const [
    YemenGovernorate(
      id: 'capital',
      code: 'YE13',
      nameAr: 'أمانة العاصمة',
      nameEn: "Sana'a City",
      districtsCount: 2,
    ),
  ];

  @override
  Future<List<YemenDistrict>> getDistricts(String governorateId) async =>
      const [];
}

final _date = DateTime(2026, 1, 1);

final _snapshot = LocalPlanSnapshot(
  draft: GuestOnboardingDraft(
    guestPlanId: 'guest-plan-1',
    planName: 'خطة عرس محمد',
    createdAt: _date,
    isGuestPlan: true,
    needsSync: true,
    selectedPath: GuestOnboardingPath.weddingUser,
    persona: GuestPersona.groom,
    governorate: 'أمانة العاصمة',
    city: 'صنعاء',
    district: null,
    neighborhood: null,
    street: null,
    addressNote: null,
    weddingDate: DateTime(2027, 4, 20),
    weddingDateUnknown: false,
    priorities: const [],
    currency: 'YER',
    estimatedBudget: '4000000',
    selectedCategoryKeys: const ['التصوير'],
  ),
  costs: const [
    {'id': 'cost-1'},
    {'id': 'cost-2'},
  ],
  costPayments: const [],
  paymentSchedules: const [],
  tasks: const [
    {'id': 'task-1'},
  ],
  guests: const [],
  categoryNameById: const {},
);
