// Visual preview harness for the redesigned More family: compact menu tiles,
// support link rows, and shared-plan rows.
// Regenerate with:
//   flutter test test/more_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/shared_wedding_plans_screen.dart';
import 'package:aarast_mobile/features/support/screens/support_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/create_wedding_plan_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/my_wedding_plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';
import 'features/account_contexts/account_context_test_data.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('more menu — compact tiles (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1250);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final authRepository = _SignedInAuthRepository(authStorage);
    final authController = AuthController(authRepository);
    await authController.restoreSession();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.refreshStatus();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<AuthRepository>.value(value: authRepository),
          Provider<GuestOnboardingStorage>.value(
            value: GuestOnboardingStorage(preferences),
          ),
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const MoreScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/more_menu.png'),
    );
  });

  testWidgets('settings — dense grouped switches (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1100);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    await authStorage.saveSession(
      accessToken: 'settings-preview-token',
      user: const SafeUser(
        id: 'user-1',
        name: 'رشاد الحميدي',
        phone: '+967777000000',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
    final authRepository = _SignedInAuthRepository(authStorage);
    final authController = AuthController(authRepository);
    await authController.restoreSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<AuthRepository>.value(value: authRepository),
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(_FakeSettingsApi()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/settings_dense.png'),
    );
  });

  testWidgets('support — link rows (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SupportScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/support_links.png'),
    );
  });

  testWidgets('create wedding plan — form without hero (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1100);
    addTearDown(tester.view.reset);

    final provider = WeddingPlansProvider(
      WeddingPlansApi(ApiClient(tokenProvider: () async => null)),
    );
    final yemen = YemenAdministrativeProvider(_PreviewYemenAdministrativeApi());
    await yemen.loadGovernorates();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: provider),
          ChangeNotifierProvider<YemenAdministrativeProvider>.value(
            value: yemen,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const CreateWeddingPlanScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/create_wedding_plan.png'),
    );
  });

  testWidgets('my wedding plans — slim cards (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(tester.view.reset);

    final provider = _FakePlansProvider([
      // تاريخ ماضٍ عمدًا: يثبّت شريط التقدم على 100% فلا تتغير الصورة يوميًا.
      WeddingPlan(
        id: 'plan-1',
        ownerUserId: 'user-1',
        title: 'عرس العبسي',
        city: 'صنعاء همدان',
        weddingDate: DateTime(2026, 1, 1),
        currency: 'YER',
        status: 'ACTIVE',
        createdAt: DateTime(2025, 7, 1),
        updatedAt: DateTime(2025, 7, 1),
      ),
      WeddingPlan(
        id: 'plan-2',
        ownerUserId: 'user-1',
        title: 'عرس أخي',
        city: 'عدن',
        currency: 'YER',
        status: 'DRAFT',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
    ]);
    final accountContexts = AccountContextController(
      contextsApi: _PreviewContextsGateway([
        accountContext(role: AccountContextRole.owner, planId: 'plan-1'),
        accountContext(role: AccountContextRole.owner, planId: 'plan-2'),
      ]),
      authStorage: AuthStorage(await SharedPreferences.getInstance()),
      setActiveWeddingPlan: (_) async {},
    );
    await accountContexts.refresh();
    await accountContexts.select('plan:plan-1:owner');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: provider),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const MyWeddingPlansScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/my_wedding_plans.png'),
    );
  });

  testWidgets('shared plans — compact rows (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    await authStorage.saveSession(
      accessToken: 'more-preview-token',
      user: const SafeUser(
        id: 'user-1',
        name: 'رشاد',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );

    final api = _FakeSharingApi(
      sharedPlans: [
        _sharedPlan(
          id: 'plan-1',
          title: 'عرس العبسي',
          city: 'صنعاء',
          currency: 'YER',
          role: 'FAMILY',
          canViewMoney: true,
          canManageTasks: true,
          canManageGuests: true,
        ),
        _sharedPlan(
          id: 'plan-2',
          title: 'عرس آل سالم',
          city: 'عدن',
          currency: 'SAR',
          role: 'VIEWER',
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<SharingProvider>.value(
            value: SharingProvider(api),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SharedWeddingPlansScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/shared_plans.png'),
    );
  });
}

class _PreviewContextsGateway implements AccountContextsGateway {
  const _PreviewContextsGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((context) => context.contextKey == contextKey);
}

SharedWeddingPlan _sharedPlan({
  required String id,
  required String title,
  required String city,
  required String currency,
  required String role,
  bool canViewMoney = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
}) {
  return SharedWeddingPlan(
    id: id,
    title: title,
    city: city,
    weddingDate: DateTime(2026, 8, 31),
    currency: currency,
    status: 'ACTIVE',
    sharedMember: SharedMember(
      id: 'member-$id',
      weddingPlanId: id,
      userId: 'user-member-$id',
      user: SharedMemberUser(
        id: 'user-member-$id',
        name: 'رشاد',
        phone: '+967777123456',
      ),
      role: role,
      canViewMoney: canViewMoney,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageMoney: false,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    ),
  );
}

class _FakeSettingsApi extends SettingsApi {
  _FakeSettingsApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<UserSettings> getSettings() async {
    return UserSettings(
      id: 'settings-1',
      userId: 'user-1',
      pushEnabled: false,
      whatsappEnabled: false,
      emailEnabled: false,
      smsEnabled: false,
      taskRemindersEnabled: true,
      paymentRemindersEnabled: true,
      providerMessagesEnabled: true,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 10),
    );
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    return settings;
  }
}

class _PreviewYemenAdministrativeApi extends YemenAdministrativeApi {
  _PreviewYemenAdministrativeApi()
    : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<YemenGovernorate>> getGovernorates() async => const [
    YemenGovernorate(
      id: 'capital',
      code: 'YE13',
      nameAr: 'أمانة العاصمة',
      nameEn: "Sana'a City",
      districtsCount: 10,
    ),
    YemenGovernorate(
      id: 'sanaa',
      code: 'YE23',
      nameAr: 'صنعاء',
      nameEn: "Sana'a",
      districtsCount: 16,
    ),
    YemenGovernorate(
      id: 'aden',
      code: 'YE24',
      nameAr: 'عدن',
      nameEn: 'Aden',
      districtsCount: 8,
    ),
  ];

  @override
  Future<List<YemenDistrict>> getDistricts(String governorateId) async =>
      const [];
}

class _FakePlansProvider extends WeddingPlansProvider {
  _FakePlansProvider(this._plans)
    : _active = _plans.isEmpty
          ? null
          : ActiveWeddingPlan.fromWeddingPlan(_plans.first),
      super(WeddingPlansApi(ApiClient(tokenProvider: () async => null)));

  final List<WeddingPlan> _plans;
  final ActiveWeddingPlan? _active;

  @override
  List<WeddingPlan> get plans => _plans;

  @override
  ActiveWeddingPlan? get activePlan => _active;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadMyWeddingPlans() async {}

  @override
  Future<void> loadActiveWeddingPlan() async {}
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({this.sharedPlans = const []})
    : super(ApiClient(tokenProvider: () async => null));

  final List<SharedWeddingPlan> sharedPlans;

  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    return sharedPlans;
  }
}

class _SignedInAuthRepository extends AuthRepository {
  _SignedInAuthRepository(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => 'token'), storage);

  static const _user = SafeUser(
    id: 'user-1',
    name: 'رشاد الحميدي',
    phone: '+967777000000',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<SafeUser> me() async => _user;
}
