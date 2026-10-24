// Captures today's real participant screens (how an invited father, brother
// or helper sees the groom's plan) for the groom before/after review.
//   flutter test test/prototype/now_participants/now_participants_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/screens/account_context_selection_screen.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/contribution_history.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/sharing/providers/contribution_history_provider.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/contribution_history_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/shared_wedding_plans_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

const _planId = 'plan-mohammed';
final _token = List.filled(43, 'a').join();

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  double h = 844,
  List<SingleChildWidget> providers = const [],
  Future<void> Function()? act,
  GoRouter? router,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final Widget app = router != null
      ? MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        )
      : MaterialApp(
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
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp).evaluate().isNotEmpty
        ? find.byType(MaterialApp)
        : find.byWidgetPredicate((w) => w is MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

// ---------- account contexts ----------

AccountContext _ctx({
  required String role,
  required String planId,
  required String name,
  String persona = 'GROOM',
  String lifecycle = 'PLANNING',
  String accessMode = 'FULL',
  bool tasks = true,
  bool guests = true,
  bool providers = true,
  bool viewMoney = false,
  bool manageMoney = false,
}) {
  final owner = role == 'OWNER';
  return AccountContext.fromJson({
    'contextKey': 'plan:$planId:${owner ? 'owner' : 'contributor'}',
    'role': role == 'OWNER' ? 'OWNER' : 'CONTRIBUTOR',
    'weddingPlanId': planId,
    'providerId': null,
    'membershipId': owner ? null : 'member-$planId',
    'membershipAuthorityVersion': owner ? null : 1,
    'persona': persona,
    'displayName': name,
    'lifecycle': lifecycle,
    'accessMode': accessMode,
    'capabilities': {
      'canViewProviderProfile': false,
      'canManageProviderProfile': false,
      'canUseProviderOperations': false,
    },
    'permissions': {
      'canViewPlan': true,
      'canEditPlan': owner,
      'canManageTasks': owner || tasks,
      'canManageGuests': owner || guests,
      'canManageProviders': owner || providers,
      'canInviteMembers': owner,
      'canViewMoney': owner || viewMoney,
      'canManageMoney': owner || manageMoney,
      'canManageProviderProfile': false,
    },
    'isAvailable': true,
    'unavailableReason': null,
  });
}

class _Gateway implements AccountContextsGateway {
  _Gateway(this.contexts);
  final List<AccountContext> contexts;
  @override
  Future<List<AccountContext>> listContexts() async => contexts;
  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((c) => c.contextKey == contextKey);
}

Future<AccountContextController> _contexts(
  List<AccountContext> list, {
  String? select,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final c = AccountContextController(
    contextsApi: _Gateway(list),
    authStorage: AuthStorage(prefs),
    setActiveWeddingPlan: (_) async {},
  );
  await c.refresh();
  if (select != null) await c.select(select);
  return c;
}

// ---------- auth ----------

const _saleh = SafeUser(
  id: 'saleh',
  name: 'صالح الحمدي',
  phone: '+967771554220',
  role: 'USER',
  status: 'ACTIVE',
);

class _AuthRepo extends AuthRepository {
  _AuthRepo(AuthStorage storage, {this.signedIn = false})
    : super(ApiClient(tokenProvider: () async => null), storage);
  final bool signedIn;
  bool setupRequired = false;

  @override
  SafeUser? readCachedUser() => signedIn ? _saleh : null;
  @override
  Future<String?> readAccessToken() async => signedIn ? 'token' : null;
  @override
  Future<SafeUser> me() async => _saleh;

  OtpRequestResult _otp(String phone) => OtpRequestResult(
    phone: phone,
    purpose: 'LOGIN',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    delivery: 'WHATSAPP',
    deliveryStatus: 'PENDING',
    accountSetupRequired: setupRequired,
  );

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async => _otp(phone);

  @override
  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) async => _otp(phone);

  @override
  Future<OtpVerifyResult> verifyInviteOtp({
    required String token,
    required String phone,
    required String code,
    String? name,
    String? password,
  }) => verifyOtp(phone: phone, purpose: 'LOGIN', code: code);

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async => OtpVerifyResult(
    verified: true,
    phone: phone,
    purpose: purpose,
    user: _saleh,
    accessToken: 'verified-access-token',
  );

  @override
  Future<void> logout() async {}
}

Future<AuthController> _auth({bool signedIn = false, bool setup = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  if (signedIn) {
    await storage.saveSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: _saleh,
    );
  }
  final repo = _AuthRepo(storage, signedIn: signedIn)..setupRequired = setup;
  final c = AuthController(repo);
  await c.restoreSession();
  return c;
}

// ---------- sharing ----------

PlanInvite _invite({String status = 'PENDING'}) => PlanInvite(
  id: 'invite-1',
  weddingPlanId: _planId,
  token: _token,
  contextKey: status == 'ACCEPTED' ? 'plan:$_planId:contributor' : null,
  role: 'HELPER',
  status: status,
  expiresAt: DateTime(2026, 11, 3),
  // HELPER defaults on the server: tasks + guests + providers.
  canViewMoney: false,
  canEditPlan: false,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: true,
  canInviteMembers: false,
  canManageMoney: false,
  weddingPlanTitle: 'عرس محمد',
  inviterName: 'محمد',
  name: 'صالح',
  phone: '+967771554220',
);

SharedMember _member(
  String id,
  String name,
  String role, {
  bool tasks = true,
  bool guests = true,
  bool providers = false,
  bool money = false,
}) => SharedMember(
  id: id,
  weddingPlanId: _planId,
  userId: 'user-$id',
  user: SharedMemberUser(id: 'user-$id', name: name, phone: '+967771554220'),
  role: role,
  canViewMoney: money,
  canManageTasks: tasks,
  canManageGuests: guests,
  canManageProviders: providers,
  canManageMoney: false,
  createdAt: DateTime(2026, 10, 2),
  updatedAt: DateTime(2026, 10, 2),
);

class _SharingApi extends SharingApi {
  _SharingApi({
    this.invites = const [],
    this.members = const [],
    this.planInvites = const [],
    this.shared = const [],
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<PlanInvite> invites;
  final List<SharedMember> members;
  final List<PlanInvite> planInvites;
  final List<SharedWeddingPlan> shared;

  @override
  Future<List<PlanInvite>> getMyInvites() async => invites;
  @override
  Future<PlanInvite> getInvite(String token) async => invites.first;
  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) async =>
      AcceptedPlanInvite(
        invite: _invite(status: 'ACCEPTED'),
        member: _member('m1', 'صالح', 'HELPER', providers: true),
        contextKey: 'plan:$_planId:contributor',
      );
  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String id) async =>
      PlanAccessPermissions.owner(weddingPlanId: id);
  @override
  Future<List<SharedMember>> getSharedMembers(String id) async => members;
  @override
  Future<List<PlanInvite>> getPlanInvites(String id) async => planInvites;
  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async => shared;
  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
    String? section,
    String? contributorUserId,
  }) async {
    Map<String, dynamic> ev(
      String id,
      String section,
      String type,
      String action,
      String title,
      int day,
    ) => {
      'id': id,
      'section': section,
      'entityType': type,
      'action': action,
      'occurredAt': '2026-10-${day.toString().padLeft(2, '0')}T10:00:00.000Z',
      'capturedAt': '2026-10-${day.toString().padLeft(2, '0')}T10:00:01.000Z',
      // Same allow-listed fields the server snapshot builder keeps.
      'snapshot': type == 'TASK'
          ? {
              'title': title,
              'status': action == 'COMPLETED' ? 'DONE' : 'TODO',
              'priority': 'MEDIUM',
              'dueDate': '2027-01-15T00:00:00.000Z',
            }
          : {'displayName': title},
    };
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-10-02T09:00:00.000Z',
      'total': 4,
      'events': [
        ev('e1', 'TASKS', 'TASK', 'COMPLETED', 'استلام البدلة', 18),
        ev('e2', 'GUESTS', 'GUEST', 'CREATED', 'آل الحمدي', 12),
        ev('e3', 'TASKS', 'TASK', 'CREATED', 'ترتيب سيارات الزفة', 9),
        ev('e4', 'GUESTS', 'GUEST', 'CREATED', 'يحيى السنيدار', 5),
      ],
    });
  }
}

// ---------- dashboard ----------

DashboardSummary _summary({
  required String role,
  bool tasks = true,
  bool guests = true,
  bool providers = true,
  bool money = false,
}) => DashboardSummary(
  planId: _planId,
  title: 'عرس محمد',
  status: 'PLANNING',
  progressPercentage: 35,
  weddingDate: DateTime(2027, 1, 21),
  daysRemaining: 93,
  city: 'صنعاء',
  currency: 'YER',
  totalTasks: 4,
  completedTasks: 1,
  overdueTasks: 0,
  todayTasks: 1,
  guestCount: 8,
  confirmedGuests: 3,
  providerCount: 0,
  quoteRequestsCount: 0,
  participantCount: 3,
  unreadNotificationsCount: 2,
  importantItems: const [],
  planProviders: const [],
  importantNotifications: [
    DashboardNotificationPreview(
      id: 'n1',
      type: 'TASK_ASSIGNED',
      title: 'محمد أسند لك مهمة',
      body: 'رتّب سيارات الزفة قبل 15 يناير.',
      createdAt: DateTime(2026, 10, 19, 18),
    ),
  ],
  contributionHistory: const {'TASKS': 2, 'GUESTS': 2},
  permissions: DashboardPermissionSummary(
    isOwner: false,
    role: role,
    canViewMoney: money,
    canManageTasks: tasks,
    canManageGuests: guests,
    canManageProviders: providers,
    canManageMembers: false,
    canManageMoney: false,
    canManagePlan: false,
  ),
);

class _PlansApi extends WeddingPlansApi {
  _PlansApi(this.summary) : super(ApiClient(tokenProvider: () async => null));
  final DashboardSummary summary;
  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async => summary;
  @override
  Future<WeddingPlan> getWeddingPlan(String id) async =>
      throw const ApiException('not used');
}

Future<(List<SingleChildWidget>, GoRouter)> _workspace({
  required String role,
  bool tasks = true,
  bool guests = true,
  bool providers = true,
  bool money = false,
}) async {
  final contexts = await _contexts(
    [
      _ctx(
        role: 'CONTRIBUTOR',
        planId: _planId,
        name: 'عرس محمد',
        tasks: tasks,
        guests: guests,
        providers: providers,
        viewMoney: money,
      ),
    ],
    select: 'plan:$_planId:contributor',
  );
  final auth = await _auth(signedIn: true);
  final api = _PlansApi(
    _summary(
      role: role,
      tasks: tasks,
      guests: guests,
      providers: providers,
      money: money,
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const PlanCenterScreen(weddingPlanId: _planId),
      ),
    ],
  );
  return (
    <SingleChildWidget>[
      ChangeNotifierProvider<AccountContextController>.value(value: contexts),
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider<WeddingPlansProvider>.value(
        value: WeddingPlansProvider(api),
      ),
      ChangeNotifierProvider<DashboardSummaryProvider>.value(
        value: DashboardSummaryProvider(weddingPlansApi: api),
      ),
      Provider<SharingApi>.value(value: _SharingApi()),
    ],
    router,
  );
}

// ---------- finance ----------

class _ReadOnlyFinance extends FinanceProvider {
  _ReadOnlyFinance()
    : super(FinanceApi(ApiClient(tokenProvider: () async => null)));
  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedMoney => true;
  @override
  String? get loadedPlanId => _planId;
  @override
  bool get canManageMoney => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {}
}

// ---------- notifications ----------

class _NotesApi extends NotificationsApi {
  _NotesApi(this.items) : super(ApiClient(tokenProvider: () async => null));
  final List<AarastNotification> items;
  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async => NotificationsPage(
    items: items,
    page: page,
    limit: limit,
    total: items.length,
    totalPages: 1,
    hasMore: false,
  );
  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async =>
      items.where((i) => i.isUnread).length;
}

AarastNotification _note(
  String id,
  String type,
  String title,
  String body,
  int hoursAgo, {
  bool unread = true,
}) {
  final at = DateTime(2026, 10, 20, 12).subtract(Duration(hours: hoursAgo));
  return AarastNotification(
    id: id,
    userId: 'saleh',
    weddingPlanId: _planId,
    type: type,
    title: title,
    body: body,
    priority: 'NORMAL',
    createdAt: at,
    updatedAt: at,
    readAt: unread ? null : at,
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<SingleChildWidget>> inviteProviders({
    bool signedIn = false,
    bool setup = false,
  }) async {
    final auth = await _auth(signedIn: signedIn, setup: setup);
    final contexts = await _contexts([
      _ctx(role: 'CONTRIBUTOR', planId: _planId, name: 'عرس محمد'),
    ]);
    return [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider<SharingProvider>.value(
        value: SharingProvider(_SharingApi(invites: [_invite()])),
      ),
      ChangeNotifierProvider<AccountContextController>.value(value: contexts),
    ];
  }

  Future<void> enterPhone(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('invite-phone-field')),
      '771554220',
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final f = find.byKey(key);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('p02 invite phone', (tester) async {
    await _shot(
      tester,
      'p02_invite_phone',
      InviteDecisionScreen(token: _token),
      h: 900,
      providers: await inviteProviders(),
      act: () => enterPhone(tester),
    );
  });

  testWidgets('p03 invite account setup (link)', (tester) async {
    await _shot(
      tester,
      'p03_invite_account',
      InviteDecisionScreen(token: _token),
      h: 1000,
      providers: await inviteProviders(setup: true),
      act: () async {
        await enterPhone(tester);
        await tapKey(tester, const Key('invite-request-otp-button'));
        await tester.enterText(
          find.byKey(const ValueKey('invite-account-name-field')),
          'صالح الحمدي',
        );
        await tester.pump();
      },
    );
  });

  testWidgets('p04 invite otp', (tester) async {
    await _shot(
      tester,
      'p04_invite_otp',
      InviteDecisionScreen(token: _token),
      h: 1000,
      providers: await inviteProviders(),
      act: () async {
        await enterPhone(tester);
        await tapKey(tester, const Key('invite-request-otp-button'));
      },
    );
  });

  Future<void> verified(WidgetTester tester) async {
    await enterPhone(tester);
    await tapKey(tester, const Key('invite-request-otp-button'));
    await tester.enterText(find.byKey(const Key('invite-otp-field')), '123456');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
  }

  testWidgets('p05 invite decision', (tester) async {
    await _shot(
      tester,
      'p05_invite_decision',
      InviteDecisionScreen(token: _token),
      h: 1500,
      providers: await inviteProviders(),
      act: () async {
        await verified(tester);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('p06 invite joined', (tester) async {
    await _shot(
      tester,
      'p06_invite_joined',
      InviteDecisionScreen(token: _token),
      h: 1100,
      providers: await inviteProviders(),
      act: () async {
        await verified(tester);
        await tapKey(tester, const Key('invite-accept-button'));
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('p07 invite decline confirm', (tester) async {
    await _shot(
      tester,
      'p07_invite_decline',
      InviteDecisionScreen(token: _token),
      h: 1100,
      providers: await inviteProviders(),
      act: () async {
        await verified(tester);
        await tapKey(tester, const Key('invite-decline-button'));
      },
    );
  });

  testWidgets('p08 choose path', (tester) async {
    final c = await _contexts([
      _ctx(role: 'CONTRIBUTOR', planId: _planId, name: 'عرس محمد'),
      _ctx(
        role: 'CONTRIBUTOR',
        planId: 'plan-laila',
        name: 'عرس ليلى وفهد',
        persona: 'BRIDE',
        tasks: false,
        guests: true,
        providers: false,
      ),
      _ctx(role: 'OWNER', planId: 'plan-saleh', name: 'عرس صالح'),
    ]);
    await _shot(
      tester,
      'p08_choose_path',
      const AccountContextSelectionScreen(),
      h: 1000,
      providers: [
        ChangeNotifierProvider<AccountContextController>.value(value: c),
      ],
    );
  });

  testWidgets('p09 helper workspace', (tester) async {
    final (p, r) = await _workspace(role: 'HELPER');
    await _shot(
      tester,
      'p09_workspace_helper',
      const SizedBox(),
      h: 1700,
      providers: p,
      router: r,
    );
  });

  testWidgets('p10 viewer workspace (father, view only)', (tester) async {
    final (p, r) = await _workspace(
      role: 'VIEWER',
      tasks: false,
      guests: false,
      providers: false,
    );
    await _shot(
      tester,
      'p10_workspace_viewer',
      const SizedBox(),
      h: 1500,
      providers: p,
      router: r,
    );
  });

  testWidgets('p11 money viewer workspace', (tester) async {
    final (p, r) = await _workspace(
      role: 'FAMILY',
      providers: false,
      money: true,
    );
    await _shot(
      tester,
      'p11_workspace_money_view',
      const SizedBox(),
      h: 1700,
      providers: p,
      router: r,
    );
  });

  testWidgets('p12 permissions sheet', (tester) async {
    final (p, r) = await _workspace(role: 'HELPER');
    await _shot(
      tester,
      'p12_permissions_sheet',
      const SizedBox(),
      h: 1100,
      providers: p,
      router: r,
      act: () async {
        final card = find.byKey(const Key('contributor-permissions-card'));
        await tester.scrollUntilVisible(
          card,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('p13 account menu', (tester) async {
    final (p, r) = await _workspace(role: 'HELPER');
    await _shot(
      tester,
      'p13_account_menu',
      const SizedBox(),
      h: 1000,
      providers: p,
      router: r,
      act: () async {
        await tester.tap(find.byKey(const Key('contributor-account-action')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('p14 leave confirm', (tester) async {
    final (p, r) = await _workspace(role: 'HELPER');
    await _shot(
      tester,
      'p14_leave_confirm',
      const SizedBox(),
      h: 844,
      providers: p,
      router: r,
      act: () async {
        await tester.tap(find.byKey(const Key('contributor-account-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('contributor-leave-plan')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('p15 section blocked by permission', (tester) async {
    final c = await _contexts(
      [_ctx(role: 'CONTRIBUTOR', planId: _planId, name: 'عرس محمد')],
      select: 'plan:$_planId:contributor',
    );
    await _shot(
      tester,
      'p15_section_blocked',
      const WeddingPlanContextGate(
        weddingPlanId: _planId,
        requiredAccess: WeddingPlanRouteAccess.viewMoney,
        child: SizedBox(),
      ),
      providers: [
        ChangeNotifierProvider<AccountContextController>.value(value: c),
      ],
    );
  });

  testWidgets('p16 money read only block', (tester) async {
    await _shot(
      tester,
      'p16_money_read_only',
      const MoneyBudgetScreen(weddingPlanId: _planId),
      providers: [
        ChangeNotifierProvider<FinanceProvider>.value(
          value: _ReadOnlyFinance(),
        ),
      ],
    );
  });

  testWidgets('p17 removed from plan', (tester) async {
    final c = await _contexts(
      [_ctx(role: 'OWNER', planId: 'plan-saleh', name: 'عرس صالح')],
      select: 'plan:plan-saleh:owner',
    );
    await _shot(
      tester,
      'p17_removed',
      const WeddingPlanContextGate(weddingPlanId: _planId, child: SizedBox()),
      providers: [
        ChangeNotifierProvider<AccountContextController>.value(value: c),
      ],
    );
  });

  Future<List<SingleChildWidget>> sharingProviders(_SharingApi api) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    await storage.saveSession(accessToken: 'token', user: _saleh);
    return [
      Provider<AuthStorage>.value(value: storage),
      ChangeNotifierProvider<SharingProvider>.value(
        value: SharingProvider(api),
      ),
    ];
  }

  testWidgets('p18 shared plans list', (tester) async {
    await _shot(
      tester,
      'p18_shared_plans',
      const SharedWeddingPlansScreen(),
      h: 1000,
      providers: await sharingProviders(
        _SharingApi(
          shared: [
            SharedWeddingPlan(
              id: _planId,
              title: 'عرس محمد',
              city: 'صنعاء',
              weddingDate: DateTime(2027, 1, 21),
              currency: 'YER',
              status: 'ACTIVE',
              sharedMember: _member('m1', 'صالح', 'HELPER', providers: true),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('p19 contribution history', (tester) async {
    await _shot(
      tester,
      'p19_contribution_history',
      const ContributionHistoryScreen(weddingPlanId: _planId),
      h: 1100,
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

  testWidgets('p20 plan notifications', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    await storage.saveSession(accessToken: 'token', user: _saleh);
    await _shot(
      tester,
      'p20_notifications',
      const NotificationsScreen(),
      h: 1000,
      providers: [
        Provider<AuthStorage>.value(value: storage),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(
            _NotesApi([
              _note(
                'n1',
                'TASK_ASSIGNED',
                'مهمة جديدة لك',
                'محمد أسند لك: رتّب سيارات الزفة.',
                2,
              ),
              _note(
                'n2',
                'TASK_DUE_SOON',
                'مهمة قريبة',
                'ذكّر آل الحمدي اللي ما ردّوا: باقي يومين.',
                20,
              ),
              _note(
                'n3',
                'SHARING_INVITATION',
                'دعوة مشاركة',
                'محمد دعاك تشارك في خطة عرس محمد.',
                200,
                unread: false,
              ),
            ]),
          ),
        ),
      ],
    );
  });

  testWidgets('p21 owner members screen', (tester) async {
    await _shot(
      tester,
      'p21_owner_members',
      const SharingScreen(weddingPlanId: _planId),
      h: 1500,
      providers: await sharingProviders(
        _SharingApi(
          members: [
            _member('m1', 'صالح', 'HELPER', providers: true),
            _member('m2', 'العروسة', 'BRIDE', money: true),
          ],
          planInvites: [
            PlanInvite(
              id: 'inv-father',
              weddingPlanId: _planId,
              token: 'inv-father',
              role: 'VIEWER',
              status: 'PENDING',
              expiresAt: DateTime(2026, 11, 2),
              canViewMoney: false,
              canEditPlan: false,
              canManageTasks: false,
              canManageGuests: false,
              canManageProviders: false,
              canInviteMembers: false,
              canManageMoney: false,
              deliveryStatus: 'DELIVERED',
              phone: '+967777100200',
              name: 'الوالد',
            ),
            PlanInvite(
              id: 'inv-adel',
              weddingPlanId: _planId,
              token: 'inv-adel',
              role: 'HELPER',
              status: 'PENDING',
              expiresAt: DateTime(2026, 11, 2),
              canViewMoney: false,
              canEditPlan: false,
              canManageTasks: true,
              canManageGuests: true,
              canManageProviders: true,
              canInviteMembers: false,
              canManageMoney: false,
              deliveryStatus: 'UNAVAILABLE',
              phone: '+967733400500',
              name: 'عادل',
            ),
          ],
        ),
      ),
    );
  });
}
