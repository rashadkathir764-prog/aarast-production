// Captures today's real account, plan and sharing screens for the groom
// before/after review.
//   flutter test test/prototype/now_account/now_account_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/security/app_lock_controller.dart';
import 'package:aarast_mobile/core/security/app_lock_gate.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/screens/account_context_selection_screen.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:aarast_mobile/features/settings/screens/lock_settings_screen.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/contribution_history.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/plan_role_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/contribution_history_provider.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/contribution_history_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/edit_shared_member_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:aarast_mobile/features/support/screens/support_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/my_wedding_plans_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account_contexts/account_context_test_data.dart';
import '../../support/preview_fonts.dart';

const _planId = 'plan-mohammed';

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
      data: MediaQueryData(
        size: Size(390, h),
        devicePixelRatio: 2,
        disableAnimations: true,
      ),
      child: home,
    ),
  );
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

const _user = SafeUser(
  id: 'user-1',
  name: 'محمد الحمدي',
  phone: '+967777123456',
  role: 'USER',
  status: 'ACTIVE',
);

Future<_Auth> _auth() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  await storage.saveSession(accessToken: 'token', user: _user);
  final repo = _Repo(storage);
  final auth = AuthController(repo);
  await auth.restoreSession();
  return _Auth(prefs, storage, repo, auth);
}

class _Auth {
  _Auth(this.prefs, this.storage, this.repo, this.controller);
  final SharedPreferences prefs;
  final AuthStorage storage;
  final AuthRepository repo;
  final AuthController controller;

  List<SingleChildWidget> get providers => [
    Provider<AuthStorage>.value(value: storage),
    Provider<AuthRepository>.value(value: repo),
    Provider<GuestOnboardingStorage>.value(
      value: GuestOnboardingStorage(prefs),
    ),
    ChangeNotifierProvider<AuthController>.value(value: controller),
  ];
}

WeddingPlan _plan({
  String id = _planId,
  String title = 'عرس محمد',
  String status = 'PLANNING',
  DateTime? date,
}) => WeddingPlan(
  id: id,
  ownerUserId: 'user-1',
  title: title,
  city: 'صنعاء',
  location: const {
    'governorate': 'أمانة العاصمة',
    'city': 'السبعين',
    'cityOrDistrict': 'السبعين',
  },
  weddingDate: date ?? DateTime(2027, 1, 21),
  estimatedBudget: '8000000',
  priorities: const ['budget', 'guests'],
  onboardingPath: 'PLAN',
  persona: 'GROOM',
  currency: 'YER',
  status: status,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 10, 1),
);

SharedMember _member(
  String id,
  String name,
  String role, {
  bool money = false,
  bool tasks = false,
  bool guests = false,
  bool providers = false,
  bool plan = false,
}) => SharedMember(
  id: id,
  weddingPlanId: _planId,
  userId: 'user-$id',
  user: SharedMemberUser(id: 'user-$id', name: name, phone: '+967771554220'),
  role: role,
  canViewMoney: money,
  canEditPlan: plan,
  canManageTasks: tasks,
  canManageGuests: guests,
  canManageProviders: providers,
  canManageMoney: false,
  createdAt: DateTime(2026, 10, 3),
  updatedAt: DateTime(2026, 10, 3),
);

final _members = [
  _member('m1', 'صالح الحمدي', 'HELPER', tasks: true, guests: true),
  _member('m2', 'الوالد', 'VIEWER'),
  _member('m3', 'العروسة', 'BRIDE', tasks: true, guests: true, money: true),
];

PlanInvite _invite() => PlanInvite(
  id: 'invite-1',
  weddingPlanId: _planId,
  token: 'invite-token',
  role: 'FAMILY',
  status: 'PENDING',
  expiresAt: DateTime(2026, 11, 2),
  canViewMoney: false,
  canEditPlan: false,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: false,
  canInviteMembers: false,
  canManageMoney: false,
  deliveryStatus: 'SENT',
  phone: '+967733880145',
  name: 'خالي أحمد',
);

void main() {
  setUpAll(loadPreviewAppFonts);

  Future<List<SingleChildWidget>> moreProviders() async {
    final a = await _auth();
    final database = JsonLocalDatabase(a.prefs);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.refreshStatus();
    // g02 draws «عرسي» for the plan's owner and «شكل التطبيق» from the
    // phone's own preferences, so both are provided as the app does.
    final accountContexts = AccountContextController(
      contextsApi: _Contexts([
        _ctx(AccountContextRole.owner, _planId, 'عرس محمد'),
      ]),
      authStorage: a.storage,
      setActiveWeddingPlan: (_) async {},
    );
    await accountContexts.refresh(allowInitialSingleContext: true);
    final lock = AppLockController(vault: _Vault(), userId: 'user-1');
    await lock.load();
    return [
      ...a.providers,
      ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
      ChangeNotifierProvider<DevicePreferences>.value(
        value: DevicePreferences(a.prefs),
      ),
      ChangeNotifierProvider<AccountContextController>.value(
        value: accountContexts,
      ),
      ChangeNotifierProvider<DashboardSummaryProvider>.value(value: _Dash()),
      ChangeNotifierProvider<AppLockController>.value(value: lock),
    ];
  }

  // g02 «حسابي».
  testWidgets('a01 more', (tester) async {
    await _shot(
      tester,
      'a01_more',
      const MoreScreen(),
      h: 1300,
      providers: await moreProviders(),
    );
    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('عرسي'), findsOneWidget);
  });

  // g11 «الخروج». The old «إدارة الحساب» sheet (a02) and «حذف الحساب نهائيًا»
  // (a04) are gone: a229aa97 (D23) removed them, account deletion stays hidden
  // until its 30-day grace exists (C4), so those two shots have no screen.
  testWidgets('a03 logout confirm', (tester) async {
    await _shot(
      tester,
      'a03_logout_confirm',
      const MoreScreen(),
      h: 1300,
      providers: await moreProviders(),
      act: () async {
        await tester.tap(find.byKey(const ValueKey('account-logout')));
        await tester.pumpAndSettle();
      },
    );
  });

  // w39 / settings: «التنبيهات».
  Future<List<SingleChildWidget>> settingsProviders({
    bool lockOn = false,
  }) async {
    final a = await _auth();
    final vault = _Vault();
    final lock = AppLockController(vault: vault, userId: 'user-1');
    await lock.load();
    if (lockOn) await lock.setCode('2580');
    return [
      ...a.providers,
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(_SettingsApi()),
      ),
      ChangeNotifierProvider<AppLockController>.value(value: lock),
    ];
  }

  testWidgets('a05 settings', (tester) async {
    await _shot(
      tester,
      'a05_settings',
      const SettingsScreen(devicePushAvailableOverride: true),
      h: 1500,
      providers: await settingsProviders(),
    );
  });

  // The app lock moved out of the settings screen to its own page
  // (`LockSettingsScreen`, reached from «قفل التطبيق» in g02).
  testWidgets('a06 lock on', (tester) async {
    await _shot(
      tester,
      'a06_lock_on',
      const LockSettingsScreen(),
      providers: await settingsProviders(lockOn: true),
    );
    expect(find.text('التطبيق مقفول برمزك'), findsOneWidget);
  });

  testWidgets('a07 lock choose code', (tester) async {
    await _shot(
      tester,
      'a07_lock_choose',
      const LockSettingsScreen(),
      providers: await settingsProviders(),
    );
    expect(find.text('اختر رمز من 4 أرقام'), findsOneWidget);
  });

  // The change-phone sheet is opened from g02 now, not from settings.
  testWidgets('a08 change phone', (tester) async {
    await _shot(
      tester,
      'a08_change_phone',
      const MoreScreen(),
      h: 1300,
      providers: await moreProviders(),
      act: () async {
        await tester.tap(find.byKey(const ValueKey('account-change-phone')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('a09 lock wrong', (tester) async {
    final vault = _Vault();
    final setup = AppLockController(vault: vault, userId: 'user-1');
    await setup.load();
    await setup.setCode('2580');
    final lock = AppLockController(vault: vault, userId: 'user-1');
    await lock.load();
    for (var i = 0; i < 4; i++) {
      await lock.unlock('1111');
    }
    await _shot(
      tester,
      'a09_lock_wrong',
      AppLockScreen(lock: lock, onForgotCode: () async {}),
      act: () async {
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('1').first);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a10 support', (tester) async {
    await _shot(tester, 'a10_support', const SupportScreen(), h: 1700);
  });

  Future<List<SingleChildWidget>> planProviders({
    List<AccountContext>? contexts,
    DateTime? weddingDate,
  }) async {
    final a = await _auth();
    final plans = _Plans([
      _plan(date: weddingDate),
      _plan(
        id: 'plan-old',
        title: 'خطة تجربة',
        status: 'ARCHIVED',
        date: DateTime(2026, 5, 2),
      ),
    ]);
    final accountContexts = AccountContextController(
      contextsApi: _Contexts(
        contexts ??
            [
              _ctx(AccountContextRole.owner, _planId, 'عرس محمد'),
              _ctx(AccountContextRole.contributor, 'plan-saleh', 'عرس صالح'),
              _ctx(
                AccountContextRole.owner,
                'plan-old',
                'خطة تجربة',
                lifecycle: 'ARCHIVED',
              ),
            ],
      ),
      authStorage: a.storage,
      setActiveWeddingPlan: (_) async {},
    );
    await accountContexts.refresh();
    return [
      ...a.providers,
      ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
      ChangeNotifierProvider<DashboardSummaryProvider>.value(value: _Dash()),
      // w10 reads the plan's budget from the money provider, as main.dart
      // provides it.
      ChangeNotifierProvider<FinanceProvider>.value(value: _Finance()),
      ChangeNotifierProvider<AccountContextController>.value(
        value: accountContexts,
      ),
    ];
  }

  testWidgets('a11 my plans', (tester) async {
    // «خطتك · 88 يوم» counts from today, so the day follows today.
    final now = appNow();
    await _shot(
      tester,
      'a11_my_plans',
      const MyWeddingPlansScreen(),
      h: 1000,
      providers: await planProviders(
        weddingDate: DateTime(now.year, now.month, now.day + 88),
      ),
    );
    expect(find.text('خطتك · 88 يوم'), findsOneWidget);
  });

  testWidgets('a12 contexts', (tester) async {
    await _shot(
      tester,
      'a12_contexts',
      const AccountContextSelectionScreen(),
      h: 1000,
      providers: await planProviders(),
    );
  });

  testWidgets('a13 plan center', (tester) async {
    await _shot(
      tester,
      'a13_plan_center',
      const PlanCenterScreen(weddingPlanId: _planId),
      h: 2000,
      providers: await planProviders(),
    );
  });

  // a14 «تعديل البيانات الأساسية» had its own page; w10 (5712617e) edits the
  // plan on the screen itself, so a13 is the edit screen and a14 has no
  // screen of its own.
  testWidgets('a15 archive confirm', (tester) async {
    await _shot(
      tester,
      'a15_archive_confirm',
      const PlanCenterScreen(weddingPlanId: _planId),
      h: 1000,
      providers: await planProviders(),
      act: () async {
        final archive = find.byKey(const ValueKey('plan-details-archive'));
        await tester.ensureVisible(archive);
        await tester.pumpAndSettle();
        await tester.tap(archive);
        await tester.pumpAndSettle();
      },
    );
    expect(find.text('تحط الخطة في الأرشيف؟'), findsOneWidget);
  });

  Future<List<SingleChildWidget>> sharingProviders(_SharingApi api) async {
    final a = await _auth();
    return [
      ...a.providers,
      ChangeNotifierProvider<SharingProvider>.value(
        value: SharingProvider(api),
      ),
    ];
  }

  testWidgets('a16 sharing', (tester) async {
    await _shot(
      tester,
      'a16_sharing',
      const SharingScreen(weddingPlanId: _planId),
      h: 1500,
      providers: await sharingProviders(
        _SharingApi(members: _members, invites: [_invite()]),
      ),
    );
  });

  testWidgets('a17 sharing empty', (tester) async {
    await _shot(
      tester,
      'a17_sharing_empty',
      const SharingScreen(weddingPlanId: _planId),
      providers: await sharingProviders(_SharingApi()),
    );
  });

  testWidgets('a18 add member', (tester) async {
    await _shot(
      tester,
      'a18_add_member',
      const SharingScreen(weddingPlanId: _planId, startAdding: true),
      h: 1300,
      providers: await sharingProviders(_SharingApi()),
    );
  });

  testWidgets('a19 add member custom', (tester) async {
    await _shot(
      tester,
      'a19_add_member_custom',
      const SharingScreen(weddingPlanId: _planId, startAdding: true),
      h: 1900,
      providers: await sharingProviders(_SharingApi()),
      act: () async {
        await tester.tap(find.text('أهل').last);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('a20 edit member', (tester) async {
    final a = await _auth();
    await _shot(
      tester,
      'a20_edit_member',
      const EditSharedMemberScreen(sharedMemberId: 'm1'),
      h: 1600,
      providers: [
        ...a.providers,
        ChangeNotifierProvider<SharingProvider>.value(
          value: _EditSharing(_members.first),
        ),
      ],
    );
  });

  testWidgets('a21 history', (tester) async {
    await _shot(
      tester,
      'a21_history',
      const ContributionHistoryScreen(weddingPlanId: _planId),
      h: 1300,
      providers: [
        ChangeNotifierProvider<SharingProvider>.value(
          value: SharingProvider(_SharingApi(history: true, members: _members)),
        ),
        ChangeNotifierProvider<ContributionHistoryProvider>.value(
          value: ContributionHistoryProvider(
            _SharingApi(history: true, members: _members),
          ),
        ),
      ],
    );
    expect(
      find.textContaining('دفعة التصوير', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a22 history empty', (tester) async {
    await _shot(
      tester,
      'a22_history_empty',
      const ContributionHistoryScreen(weddingPlanId: _planId),
      providers: [
        ChangeNotifierProvider<SharingProvider>.value(
          value: SharingProvider(_SharingApi()),
        ),
        ChangeNotifierProvider<ContributionHistoryProvider>.value(
          value: ContributionHistoryProvider(_SharingApi()),
        ),
      ],
    );
  });
}

AccountContext _ctx(
  AccountContextRole role,
  String planId,
  String name, {
  String lifecycle = 'PLANNING',
}) => accountContext(
  role: role,
  planId: planId,
  displayName: name,
  lifecycle: lifecycle,
  persona: AccountContextPersona.groom,
  isAvailable: lifecycle == 'PLANNING',
  unavailableReason: lifecycle == 'PLANNING' ? null : 'PLAN_ARCHIVED',
);

class _Contexts implements AccountContextsGateway {
  const _Contexts(this.contexts);
  final List<AccountContext> contexts;
  @override
  Future<List<AccountContext>> listContexts() async => contexts;
  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((c) => c.contextKey == contextKey);
}

class _Repo extends AuthRepository {
  _Repo(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => 'token'), storage);
  @override
  Future<String?> readAccessToken() async => 'token';
  @override
  SafeUser? readCachedUser() => _user;
  @override
  Future<SafeUser> me() async => _user;
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

class _SettingsApi extends SettingsApi {
  _SettingsApi() : super(ApiClient(tokenProvider: () async => null));
  @override
  Future<UserSettings> getSettings() async => UserSettings(
    id: 'settings-1',
    userId: 'user-1',
    pushEnabled: true,
    whatsappEnabled: false,
    emailEnabled: false,
    smsEnabled: false,
    taskRemindersEnabled: true,
    paymentRemindersEnabled: true,
    providerMessagesEnabled: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 10, 12),
  );
  @override
  Future<UserSettings> updateSettings(UserSettings settings) async => settings;
}

class _Plans extends WeddingPlansProvider {
  _Plans(this._list)
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => null)));
  final List<WeddingPlan> _list;
  @override
  List<WeddingPlan> get plans => _list;
  @override
  WeddingPlan? get selectedPlan => _list.first;
  @override
  ActiveWeddingPlan? get activePlan =>
      ActiveWeddingPlan.fromWeddingPlan(_list.first);
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> loadMyWeddingPlans() async {}
  @override
  Future<void> loadActiveWeddingPlan() async {}
  @override
  Future<void> loadWeddingPlan(String id) async {}
}

class _Finance extends FinanceProvider {
  _Finance() : super(FinanceApi(ApiClient(tokenProvider: () async => null)));
  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedMoney => true;
  @override
  String? get loadedPlanId => _planId;
  @override
  String? get errorMessage => null;
  @override
  MoneySummary get summary => const MoneySummary(
    planId: _planId,
    budget: MoneyBudgetSummary(total: '8000000'),
  );
  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {}
}

class _Dash extends DashboardSummaryProvider {
  _Dash()
    : super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );
  final _summary = DashboardSummary.fromJson({
    'planId': _planId,
    'title': 'عرس محمد',
    'currency': 'YER',
    'weddingDate': '2027-01-21T00:00:00.000Z',
    'status': 'PLANNING',
    'participantCount': 3,
    'pendingInvites': 1,
    'permissions': {
      'isOwner': true,
      'role': 'OWNER',
      'canViewMoney': true,
      'canManageTasks': true,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManageMembers': true,
      'canManageMoney': true,
      'canManagePlan': true,
    },
  });
  @override
  DashboardSummary? get summary => _summary;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {}
}

class _SharingApi extends SharingApi {
  _SharingApi({
    this.members = const [],
    this.invites = const [],
    this.history = false,
  }) : super(ApiClient(tokenProvider: () async => 'token'));
  final List<SharedMember> members;
  final List<PlanInvite> invites;
  final bool history;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String id) async =>
      PlanAccessPermissions.owner(weddingPlanId: id);
  @override
  Future<List<SharedMember>> getSharedMembers(String id) async => members;
  @override
  Future<List<PlanInvite>> getPlanInvites(String id) async => invites;

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
    String? section,
    String? contributorUserId,
  }) async {
    Map<String, dynamic> e(
      String id,
      String section,
      String type,
      String action,
      String at,
      Map<String, dynamic> snap,
    ) => {
      'id': id,
      'section': section,
      'entityType': type,
      'action': action,
      'occurredAt': at,
      'capturedAt': at,
      'snapshot': snap,
    };
    final all = history
        ? [
            e(
              'e1',
              'MONEY',
              'COST_PAYMENT',
              'PAYMENT_RECORDED',
              '2026-10-19T07:20:00.000Z',
              {'title': 'دفعة التصوير', 'amount': '200000'},
            ),
            e('e2', 'TASKS', 'TASK', 'COMPLETED', '2026-10-18T16:45:00.000Z', {
              'title': 'استلام البدلة',
              'status': 'DONE',
            }),
            e('e3', 'GUESTS', 'GUEST', 'CREATED', '2026-10-18T05:05:00.000Z', {
              'displayName': 'آل السقاف',
              'count': '12',
            }),
            e('e4', 'TASKS', 'TASK', 'ASSIGNED', '2026-10-17T09:00:00.000Z', {
              'title': 'حجز القاعة',
              'status': 'TODO',
            }),
          ]
        : const <Map<String, dynamic>>[];
    // The server never names who did an event: the owner asks for each
    // participant by id, so the fake answers per participant.
    const doneBy = {
      'e1': 'user-m3',
      'e2': 'user-m1',
      'e3': 'user-m1',
      'e4': 'user-m1',
    };
    final events = all
        .where(
          (event) =>
              contributorUserId == null ||
              doneBy[event['id']] == contributorUserId,
        )
        .toList();
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-10-01T09:00:00.000Z',
      'total': events.length,
      'events': events,
    });
  }
}

class _EditSharing extends SharingProvider {
  _EditSharing(this.member)
    : super(SharingApi(ApiClient(tokenProvider: () async => null)));
  final SharedMember member;
  @override
  SharedMember? get selectedMember => member;
  @override
  SharedMember? findMember(String id) => member.id == id ? member : null;
  @override
  PlanAccessPermissions get access =>
      const PlanAccessPermissions.owner(weddingPlanId: _planId);
  @override
  Future<bool> loadAccess(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async => true;
  @override
  Future<void> loadMembers(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {}
  @override
  Future<bool> updateMember({
    required String weddingPlanId,
    required String id,
    required String role,
    required PlanRolePermissions permissions,
  }) async => false;
}
