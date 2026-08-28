import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/utils/auth_action_guard.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/add_shared_member_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const localPlanId = 'guest-plan-sharing';
  const accountPlanId = 'plan-account-1';
  const rawAuthError = 'بيانات الدخول غير صحيحة أو انتهت الجلسة.';

  test('member lookup always scopes the request to its wedding plan', () async {
    final client = _RecordingLookupApiClient();
    final api = SharingApi(client);

    await api.lookupUserByPhone(accountPlanId, '777123456');

    final uri = Uri.parse(client.path!);
    expect(uri.path, '/api/v1/users/lookup');
    expect(uri.queryParameters['weddingPlanId'], accountPlanId);
    expect(uri.queryParameters['phone'], '+967777123456');
  });

  testWidgets(
    'local/no-login opening sharing shows login gate without protected API retry',
    (tester) async {
      final fakeApi = _FakeSharingApi();
      final provider = SharingProvider(fakeApi);

      await _pumpSharingScreen(
        tester,
        provider: provider,
        screen: const SharingScreen(weddingPlanId: localPlanId),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
      expect(find.text(AuthActionGuard.sharingLoginGateTitle), findsOneWidget);
      expect(find.text(AuthActionGuard.sharingLoginGateBody), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
      expect(find.text(rawAuthError), findsNothing);
      expect(fakeApi.getSharedMembersCalls, 0);
      expect(fakeApi.getPlanInvitesCalls, 0);
      expect(fakeApi.getMyPlanPermissionsCalls, 0);
      expect(provider.members, isEmpty);
      expect(provider.invites, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sharing login gate preserves the protected route as resume', (
    tester,
  ) async {
    final fakeApi = _FakeSharingApi();
    final provider = SharingProvider(fakeApi);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final sharingLocation = AppRouter.sharing(localPlanId);
    final router = GoRouter(
      initialLocation: sharingLocation,
      routes: [
        GoRoute(
          path: AppRouter.login,
          builder: (context, state) => Scaffold(
            body: Text('resume:${state.uri.queryParameters['resume'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing',
          builder: (context, state) =>
              SharingScreen(weddingPlanId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<SharingProvider>.value(value: provider),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sharing-auth-gate-login')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.login);
    expect(router.state.uri.queryParameters['resume'], sharingLocation);
    expect(find.text('resume:$sharingLocation'), findsOneWidget);
    expect(fakeApi.getSharedMembersCalls, 0);
    expect(fakeApi.getPlanInvitesCalls, 0);
    expect(fakeApi.getMyPlanPermissionsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local/no-login add member shows login gate', (tester) async {
    final fakeApi = _FakeSharingApi();
    final provider = SharingProvider(fakeApi);

    await _pumpSharingScreen(
      tester,
      provider: provider,
      screen: const AddSharedMemberScreen(weddingPlanId: localPlanId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateTitle), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateBody), findsOneWidget);
    expect(find.text('إرسال دعوة المشاركة'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(find.text(rawAuthError), findsNothing);
    expect(fakeApi.lookupUserByPhoneCalls, 0);
    expect(fakeApi.createPlanInviteCalls, 0);
    expect(provider.members, isEmpty);
    expect(provider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired token shows friendly session gate', (tester) async {
    final fakeApi = _FakeSharingApi(throwUnauthorized: true);
    final provider = SharingProvider(fakeApi);

    await _pumpSharingScreen(
      tester,
      provider: provider,
      screen: const SharingScreen(weddingPlanId: accountPlanId),
      accessToken: 'expired-token',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    expect(find.text(AuthActionGuard.sessionExpiredTitle), findsOneWidget);
    expect(
      find.text(AuthActionGuard.sharingSessionExpiredBody),
      findsOneWidget,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(find.text(rawAuthError), findsNothing);
    expect(fakeApi.getMyPlanPermissionsCalls, 1);
    expect(fakeApi.getSharedMembersCalls, 0);
    expect(fakeApi.getPlanInvitesCalls, 0);
    expect(provider.members, isEmpty);
    expect(provider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid account flow loads sharing data normally', (tester) async {
    final member = _member(
      id: 'member-real-1',
      weddingPlanId: accountPlanId,
      userName: 'أمينة',
    );
    final fakeApi = _FakeSharingApi(members: [member]);
    final provider = SharingProvider(fakeApi);

    await _pumpSharingScreen(
      tester,
      provider: provider,
      screen: const SharingScreen(weddingPlanId: accountPlanId),
      accessToken: 'valid-token',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sharing-auth-gate')), findsNothing);
    expect(find.text('أمينة'), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateTitle), findsNothing);
    expect(find.text(AuthActionGuard.sessionExpiredTitle), findsNothing);
    expect(fakeApi.getSharedMembersCalls, 1);
    expect(fakeApi.getPlanInvitesCalls, 1);
    expect(fakeApi.getMyPlanPermissionsCalls, 1);
    expect(provider.members, [member]);
    expect(provider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'member without invite permission sees a permission gate and no private list request',
    (tester) async {
      final fakeApi = _FakeSharingApi(
        permissions: const PlanAccessPermissions.denied(
          weddingPlanId: accountPlanId,
        ),
      );
      final provider = SharingProvider(fakeApi);

      await _pumpSharingScreen(
        tester,
        provider: provider,
        screen: const SharingScreen(weddingPlanId: accountPlanId),
        accessToken: 'valid-token',
      );
      await tester.pumpAndSettle();

      expect(find.text('ليس لديك صلاحية إدارة المشاركين'), findsOneWidget);
      expect(fakeApi.getMyPlanPermissionsCalls, 1);
      expect(fakeApi.getSharedMembersCalls, 0);
      expect(fakeApi.getPlanInvitesCalls, 0);
      expect(provider.members, isEmpty);
      expect(provider.invites, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retrying an access failure rechecks permission and loads the sharing data',
    (tester) async {
      final member = _member(
        id: 'member-after-retry',
        weddingPlanId: accountPlanId,
        userName: 'أمينة',
      );
      final fakeApi = _FakeSharingApi(
        members: [member],
        accessFailuresRemaining: 1,
      );
      final provider = SharingProvider(fakeApi);

      await _pumpSharingScreen(
        tester,
        provider: provider,
        screen: const SharingScreen(weddingPlanId: accountPlanId),
        accessToken: 'valid-token',
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر التحقق من الصلاحيات'), findsOneWidget);
      expect(fakeApi.getSharedMembersCalls, 0);
      expect(fakeApi.getPlanInvitesCalls, 0);

      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();

      expect(fakeApi.getMyPlanPermissionsCalls, 2);
      expect(fakeApi.getSharedMembersCalls, 1);
      expect(fakeApi.getPlanInvitesCalls, 1);
      expect(find.text('أمينة'), findsOneWidget);
      expect(find.text('تعذر التحقق من الصلاحيات'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpSharingScreen(
  WidgetTester tester, {
  required SharingProvider provider,
  required Widget screen,
  String? accessToken,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  if (accessToken != null) {
    await authStorage.saveSession(
      accessToken: accessToken,
      user: const SafeUser(
        id: 'user-1',
        name: 'رشاد',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<SharingProvider>.value(value: provider),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
}

SharedMember _member({
  required String id,
  required String weddingPlanId,
  required String userName,
}) {
  return SharedMember(
    id: id,
    weddingPlanId: weddingPlanId,
    userId: 'user-$id',
    user: SharedMemberUser(
      id: 'user-$id',
      name: userName,
      phone: '+967777123456',
    ),
    role: 'VIEWER',
    canViewMoney: false,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({
    this.throwUnauthorized = false,
    this.members = const [],
    this.permissions,
    this.accessFailuresRemaining = 0,
  }) : super(ApiClient(tokenProvider: () async => null));

  final bool throwUnauthorized;
  final List<SharedMember> members;
  final PlanAccessPermissions? permissions;
  int accessFailuresRemaining;

  int getSharedMembersCalls = 0;
  int getPlanInvitesCalls = 0;
  int lookupUserByPhoneCalls = 0;
  int createPlanInviteCalls = 0;
  int getMyPlanPermissionsCalls = 0;
  int getSharedWeddingPlansCalls = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    getMyPlanPermissionsCalls += 1;
    _throwIfUnauthorized();
    if (accessFailuresRemaining > 0) {
      accessFailuresRemaining -= 1;
      throw const ApiException(
        'تعذر التحقق من صلاحية إدارة المشاركين.',
        statusCode: 503,
      );
    }
    return permissions ??
        PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);
  }

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    getSharedMembersCalls += 1;
    _throwIfUnauthorized();
    return members;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    getPlanInvitesCalls += 1;
    _throwIfUnauthorized();
    return const [];
  }

  @override
  Future<SharedUserLookup> lookupUserByPhone(
    String weddingPlanId,
    String phone,
  ) async {
    lookupUserByPhoneCalls += 1;
    _throwIfUnauthorized();
    return const SharedUserLookup(id: 'lookup-user', name: 'عضو');
  }

  @override
  Future<PlanInvite> createPlanInvite({
    required String weddingPlanId,
    required String phone,
    String? name,
    required String role,
    required bool canViewMoney,
    required bool canEditPlan,
    required bool canManageTasks,
    required bool canManageGuests,
    required bool canManageProviders,
    required bool canInviteMembers,
    required bool canManageMoney,
    required bool receiveNotifications,
  }) async {
    createPlanInviteCalls += 1;
    _throwIfUnauthorized();
    return PlanInvite(
      id: 'invite-1',
      weddingPlanId: weddingPlanId,
      token: 'invite-token',
      role: role,
      status: 'PENDING',
      expiresAt: DateTime(2026, 7, 1),
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      phone: phone,
      name: name,
    );
  }

  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    getSharedWeddingPlansCalls += 1;
    _throwIfUnauthorized();
    return const [];
  }

  void _throwIfUnauthorized() {
    if (throwUnauthorized) {
      throw const ApiException(
        'بيانات الدخول غير صحيحة أو انتهت الجلسة.',
        statusCode: 401,
      );
    }
  }
}

class _RecordingLookupApiClient extends ApiClient {
  _RecordingLookupApiClient() : super(tokenProvider: () async => 'token');

  String? path;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    this.path = path;
    return const {
      'id': 'lookup-user',
      'name': 'Member',
      'phone': '+967777123456',
    };
  }
}
