import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'invite access starts with phone verification and no plan creation',
    (tester) async {
      final harness = await _authHarness();
      await _pumpInviteScreen(tester, harness);

      expect(find.text('وصلتني دعوة لخطة'), findsOneWidget);
      expect(find.text('أدخل الرقم الذي وصلت إليه الدعوة.'), findsWidgets);
      expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
      expect(find.text('إنشاء خطة'), findsNothing);
      expect(find.text('أجهز عرسي'), findsNothing);
      expect(find.text('إرسال رمز التحقق'), findsOneWidget);
    },
  );

  testWidgets('invite resend stays disabled for the full 60-second cooldown', (
    tester,
  ) async {
    final harness = await _authHarness();
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    final resend = find.byKey(const ValueKey('invite-otp-resend-button'));
    expect(harness.repository.requestCalls, 1);
    expect(find.text('إعادة الإرسال خلال 60 ث'), findsOneWidget);
    expect(tester.widget<AarastButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('إعادة الإرسال خلال 1 ث'), findsOneWidget);
    expect(tester.widget<AarastButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة إرسال الرمز'), findsOneWidget);
    expect(tester.widget<AarastButton>(resend).onPressed, isNotNull);

    await tester.tap(resend);
    await tester.pump();
    expect(harness.repository.requestCalls, 2);
    expect(find.text('إعادة الإرسال خلال 60 ث'), findsOneWidget);
  });

  testWidgets('invite OTP clears stale errors when a new attempt starts', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.failVerify = true;
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    await tester.enterText(find.byKey(const Key('invite-otp-field')), '999999');
    await tester.pumpAndSettle();
    expect(harness.controller.errorMessage, isNotNull);

    await tester.enterText(find.byKey(const Key('invite-otp-field')), '1');
    await tester.pump();
    expect(harness.controller.errorMessage, isNull);
  });

  testWidgets('invite OTP submits only once while verification is in flight', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository
      ..failVerify = true
      ..verifyGate = Completer<void>();
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    await tester.enterText(find.byKey(const Key('invite-otp-field')), '123456');
    await tester.tap(
      find.byKey(const Key('invite-verify-otp-button')),
      warnIfMissed: false,
    );
    expect(harness.repository.verifyCalls, 1);

    harness.repository.verifyGate!.complete();
    await tester.pumpAndSettle();
    expect(harness.repository.verifyCalls, 1);
  });

  testWidgets('invite OTP is overflow-free at 320px and 1.3 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _authHarness();
    await _pumpInviteScreen(tester, harness, textScale: 1.3);
    await _openOtpStep(tester);

    expect(find.byKey(const Key('invite-otp-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'verified contributor reviews real role and permissions before joining',
    (tester) async {
      final invite = _invite(
        canManageTasks: true,
        canManageGuests: true,
        canViewMoney: false,
      );
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      final sharingApi = _FakeSharingApi(invites: [invite]);

      await _pumpInviteScreen(tester, harness, sharingApi: sharingApi);
      await _openVerifiedInvite(tester);

      expect(find.text('عرس رشاد وسارة'), findsOneWidget);
      expect(find.text('الداعي: رشاد'), findsOneWidget);
      expect(find.textContaining('مساهم'), findsWidgets);
      expect(find.text('المهام'), findsOneWidget);
      expect(find.text('الضيوف'), findsOneWidget);
      expect(
        find.text('الميزانية والتكاليف والدفعات خاصة ولن تظهر لك.'),
        findsOneWidget,
      );
      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('invite-accept-button')),
      );
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(find.text('إنشاء خطة'), findsNothing);
    },
  );

  testWidgets('accepting an invite shows success before entering the plan', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(
      invites: [_invite(canManageTasks: true)],
    );

    await _pumpInviteScreen(tester, harness, sharingApi: sharingApi);
    await _openVerifiedInvite(tester);
    await _tapVisible(tester, find.byKey(const Key('invite-accept-button')));
    await tester.pumpAndSettle();

    expect(sharingApi.acceptCalls, 1);
    expect(find.byKey(const Key('invite-joined-success')), findsOneWidget);
    expect(find.text('تم الانضمام بنجاح'), findsOneWidget);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('invite-open-plan-button')),
    );
    expect(find.byKey(const Key('invite-open-plan-button')), findsOneWidget);
  });

  testWidgets(
    'a private invite link checks its phone, verifies OTP, accepts, and opens contributor dashboard',
    (tester) async {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      final sharingApi = _FakeSharingApi(invites: [_invite(token: token)]);

      await _pumpLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
      );
      await _openOtpStep(tester);

      expect(harness.repository.inviteRequestCalls, 1);
      expect(harness.repository.lastInviteToken, token);
      expect(find.text('تأكيد الرمز والانضمام'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('invite-otp-field')),
        '123456',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(sharingApi.acceptCalls, 1);
      expect(find.byKey(const Key('contributor-dashboard')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a private invite link rejects a non-invited phone before OTP', (
    tester,
  ) async {
    const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
    final harness = await _authHarness();
    harness.repository.failInviteRequest = true;
    await _pumpLinkedInviteScreen(
      tester,
      harness,
      token: token,
      sharingApi: _FakeSharingApi(invites: [_invite(token: token)]),
    );

    await tester.enterText(
      find.byKey(const Key('invite-phone-field')),
      '777999999',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('invite-request-otp-button')),
    );
    await tester.pumpAndSettle();

    expect(harness.repository.inviteRequestCalls, 1);
    expect(harness.repository.verifyCalls, 0);
    expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
    expect(find.textContaining('لا توجد دعوة فعّالة'), findsOneWidget);
  });

  testWidgets('declining an invite requires explicit confirmation', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(invites: [_invite()]);

    await _pumpInviteScreen(tester, harness, sharingApi: sharingApi);
    await _openVerifiedInvite(tester);
    await _tapVisible(tester, find.byKey(const Key('invite-decline-button')));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد رفض الدعوة'), findsOneWidget);
    expect(sharingApi.declineCalls, 0);

    await tester.tap(find.byKey(const Key('invite-confirm-decline-button')));
    await tester.pumpAndSettle();

    expect(sharingApi.declineCalls, 1);
    expect(find.text('مرفوضة'), findsOneWidget);
  });

  testWidgets('invite details are overflow-free at 320px and 1.3 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(
      invites: [
        _invite(
          canViewMoney: true,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: true,
        ),
      ],
    );

    await _pumpInviteScreen(
      tester,
      harness,
      sharingApi: sharingApi,
      textScale: 1.3,
    );
    await _openVerifiedInvite(tester);

    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('invite-accept-button')),
    );
    expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('invite permission labels keep financial access explicit', () {
    final helperInvite = _invite(canManageTasks: true);
    expect(helperInvite.permissionLabels, contains('عرض الخطة'));
    expect(helperInvite.permissionLabels, contains('المهام'));
    expect(helperInvite.permissionLabels, isNot(contains('إدارة المال')));
    expect(helperInvite.permissionLabels, isNot(contains('عرض مالي محدود')));

    final financeInvite = _invite(canViewMoney: true, canManageMoney: true);
    expect(financeInvite.permissionLabels, contains('إدارة المال'));
  });
}

Future<_AuthHarness> _authHarness() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final repository = _FakeAuthRepository(authStorage);
  return _AuthHarness(AuthController(repository), repository);
}

Future<void> _pumpInviteScreen(
  WidgetTester tester,
  _AuthHarness harness, {
  SharingApi? sharingApi,
  double textScale = 1,
}) async {
  final sharing = SharingProvider(sharingApi ?? _FakeSharingApi());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: harness.controller),
        ChangeNotifierProvider<SharingProvider>.value(value: sharing),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, materialChild) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: materialChild!,
        ),
        home: const InviteDecisionScreen(),
      ),
    ),
  );
}

Future<void> _pumpLinkedInviteScreen(
  WidgetTester tester,
  _AuthHarness harness, {
  required String token,
  required SharingApi sharingApi,
}) async {
  final sharing = SharingProvider(sharingApi);
  final router = GoRouter(
    initialLocation: '/invites/$token',
    routes: [
      GoRoute(
        path: '/invites/:token',
        builder: (context, state) =>
            InviteDecisionScreen(token: state.pathParameters['token']),
      ),
      GoRoute(
        path: '/wedding-plans/:id/plan-center',
        builder: (context, state) => const Scaffold(
          key: Key('contributor-dashboard'),
          body: Text('مساحة المساهم'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: harness.controller),
        ChangeNotifierProvider<SharingProvider>.value(value: sharing),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openVerifiedInvite(WidgetTester tester) async {
  await _openOtpStep(tester);
  await tester.enterText(find.byKey(const Key('invite-otp-field')), '123456');
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pumpAndSettle();
}

Future<void> _openOtpStep(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('invite-phone-field')),
    '777123456',
  );
  await _tapVisible(tester, find.byKey(const Key('invite-request-otp-button')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _scrollUntilVisible(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
}

class _AuthHarness {
  const _AuthHarness(this.controller, this.repository);

  final AuthController controller;
  final _FakeAuthRepository repository;
}

PlanInvite _invite({
  String token = 'token-1',
  bool canViewMoney = false,
  bool canEditPlan = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
  bool canManageProviders = false,
  bool canInviteMembers = false,
  bool canManageMoney = false,
}) {
  return PlanInvite(
    id: 'invite-1',
    weddingPlanId: 'plan-1',
    token: token,
    role: 'HELPER',
    status: 'PENDING',
    expiresAt: DateTime(2026),
    canViewMoney: canViewMoney,
    canEditPlan: canEditPlan,
    canManageTasks: canManageTasks,
    canManageGuests: canManageGuests,
    canManageProviders: canManageProviders,
    canInviteMembers: canInviteMembers,
    canManageMoney: canManageMoney,
    weddingPlanTitle: 'عرس رشاد وسارة',
    inviterName: 'رشاد',
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => null), storage);

  int requestCalls = 0;
  int inviteRequestCalls = 0;
  int verifyCalls = 0;
  String? lastInviteToken;
  bool failVerify = false;
  bool failInviteRequest = false;
  bool authenticateOnVerify = false;
  Completer<void>? verifyGate;

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    requestCalls += 1;
    return OtpRequestResult(
      phone: phone,
      purpose: purpose,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: 'WHATSAPP',
    );
  }

  @override
  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    requestCalls += 1;
    inviteRequestCalls += 1;
    lastInviteToken = token;
    if (failInviteRequest) {
      throw const ApiException(
        'No active invitation matches this phone',
        statusCode: 404,
        serverCode: 'INVITE_NOT_FOUND_FOR_PHONE',
      );
    }
    return OtpRequestResult(
      phone: phone,
      purpose: 'LOGIN',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: 'WHATSAPP',
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    verifyCalls += 1;
    await verifyGate?.future;
    if (failVerify) {
      throw const ApiException('OTP code is invalid or expired');
    }
    return OtpVerifyResult(
      verified: true,
      phone: phone,
      purpose: purpose,
      user: authenticateOnVerify
          ? const SafeUser(
              id: 'invitee-1',
              name: 'أحمد',
              phone: '+967777123456',
              role: 'USER',
              status: 'ACTIVE',
            )
          : null,
      accessToken: authenticateOnVerify ? 'verified-access-token' : null,
    );
  }
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({this.invites = const []})
    : super(ApiClient(tokenProvider: () async => null));

  final List<PlanInvite> invites;
  int acceptCalls = 0;
  int declineCalls = 0;

  @override
  Future<List<PlanInvite>> getMyInvites() async => invites;

  @override
  Future<PlanInvite> getInvite(String token) async {
    return invites.singleWhere((invite) => invite.token == token);
  }

  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) async {
    acceptCalls += 1;
    final invite = _withStatus(
      invites.singleWhere((item) => item.token == token),
      'ACCEPTED',
    );
    final now = DateTime(2026);
    return AcceptedPlanInvite(
      invite: invite,
      member: SharedMember(
        id: 'member-1',
        weddingPlanId: invite.weddingPlanId,
        userId: 'invitee-1',
        role: invite.role,
        canViewMoney: invite.canViewMoney,
        canManageTasks: invite.canManageTasks,
        canManageMoney: invite.canManageMoney,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<PlanInvite> declineInvite(String token) async {
    declineCalls += 1;
    return _withStatus(
      invites.singleWhere((item) => item.token == token),
      'DECLINED',
    );
  }
}

PlanInvite _withStatus(PlanInvite invite, String status) {
  return PlanInvite(
    id: invite.id,
    weddingPlanId: invite.weddingPlanId,
    token: invite.token,
    role: invite.role,
    status: status,
    expiresAt: invite.expiresAt,
    canViewMoney: invite.canViewMoney,
    canEditPlan: invite.canEditPlan,
    canManageTasks: invite.canManageTasks,
    canManageGuests: invite.canManageGuests,
    canManageProviders: invite.canManageProviders,
    canInviteMembers: invite.canInviteMembers,
    canManageMoney: invite.canManageMoney,
    name: invite.name,
    phone: invite.phone,
    email: invite.email,
    weddingPlanTitle: invite.weddingPlanTitle,
    inviterName: invite.inviterName,
  );
}
