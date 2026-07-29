import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_boundary.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
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

import '../account_contexts/account_context_test_data.dart';

String _testInviteToken() => List.filled(43, 'a').join();

void main() {
  test(
    'private invite resume tokens are validated, memory-only, and one-shot',
    () async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;

      expect(
        await harness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
          resumeInviteToken: 'not-a-private-token',
        ),
        isTrue,
      );
      expect(harness.controller.hasPendingInviteResume, isFalse);

      expect(
        await harness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
          resumeInviteToken: token,
        ),
        isTrue,
      );
      expect(harness.controller.claimPendingInviteResumeRoute(), token);
      expect(harness.controller.claimPendingInviteResumeRoute(), isNull);
      expect(
        harness.controller.consumePendingInviteResume('${token}x'),
        isFalse,
      );
      expect(harness.controller.consumePendingInviteResume(token), isTrue);
      expect(harness.controller.consumePendingInviteResume(token), isFalse);

      await harness.controller.verifyOtp(
        phone: '777123456',
        purpose: 'LOGIN',
        code: '123456',
        resumeInviteToken: token,
      );
      await harness.controller.logout();
      expect(harness.controller.claimPendingInviteResumeRoute(), isNull);
    },
  );

  test(
    'completed app registration preserves a valid private invite for the new account boundary',
    () async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnRegister = true;

      expect(
        await harness.controller.register(
          name: 'أحمد',
          phone: '777123456',
          password: 'secret123',
          otpCode: '123456',
          resumeInviteToken: 'not-a-private-token',
        ),
        isTrue,
      );
      expect(harness.controller.hasPendingInviteResume, isFalse);

      expect(
        await harness.controller.register(
          name: 'أحمد',
          phone: '777123456',
          password: 'secret123',
          otpCode: '123456',
          resumeInviteToken: token,
        ),
        isTrue,
      );
      expect(harness.controller.status, AuthStatus.authenticated);
      expect(harness.controller.claimPendingInviteResumeRoute(), token);
      expect(harness.controller.claimPendingInviteResumeRoute(), isNull);
      expect(harness.controller.consumePendingInviteResume(token), isTrue);
    },
  );

  testWidgets(
    'explicit logout survives the account boundary and opens password login',
    (tester) async {
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      expect(
        await harness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
        ),
        isTrue,
      );
      final token = _testInviteToken();
      await _pumpBoundaryLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: _FakeSharingApi(),
      );
      expect(
        find.byKey(const Key('new-account-holding-route')),
        findsOneWidget,
      );

      await harness.controller.logout();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post-logout-login-route')), findsOneWidget);
      expect(harness.controller.loginRequestedAfterLogout, isFalse);
    },
  );

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

    await _tapVisible(tester, resend);
    await tester.pump();
    expect(harness.repository.requestCalls, 2);
    expect(find.text('إعادة الإرسال خلال 60 ث'), findsOneWidget);
  });

  testWidgets('pending invite OTP request never claims WhatsApp delivery', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.otpDeliveryStatus = 'PENDING';
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    expect(find.textContaining('طلبنا إرسال الرمز إلى'), findsOneWidget);
    expect(find.textContaining('لم نتأكد من وصوله'), findsWidgets);
    expect(find.textContaining('تم تسليم الرمز'), findsNothing);
  });

  testWidgets('uncertain invite OTP request stays explicitly unconfirmed', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.otpDeliveryStatus = 'UNCERTAIN';
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    expect(find.textContaining('طلبنا إرسال الرمز إلى'), findsOneWidget);
    expect(find.textContaining('لم نتأكد من وصوله'), findsWidgets);
    expect(find.textContaining('تم تسليم الرمز'), findsNothing);
  });

  testWidgets('delivered invite OTP request may confirm WhatsApp delivery', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository.otpDeliveryStatus = 'DELIVERED';
    await _pumpInviteScreen(tester, harness);
    await _openOtpStep(tester);

    expect(find.textContaining('تم تسليم الرمز إلى واتساب'), findsOneWidget);
    expect(find.textContaining('لم نتأكد من وصوله'), findsNothing);
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

    expect(harness.repository.requestCalls, 1);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('invite-otp-field')),
    );
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
    'a private invite survives an account switch and waits for explicit acceptance',
    (tester) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      expect(
        await harness.controller.verifyOtp(
          phone: '777000000',
          purpose: 'LOGIN',
          code: '123456',
        ),
        isTrue,
      );
      expect(harness.controller.user?.id, 'old-account');
      final sharingApi = _FakeSharingApi(
        invites: [_invite(token: token)],
        currentUserId: () => harness.controller.user?.id,
      );

      await _pumpBoundaryLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
      );
      await _openOtpStep(tester);

      expect(harness.repository.inviteRequestCalls, 1);
      expect(harness.repository.lastInviteToken, token);
      expect(find.text('تأكيد الرمز ومراجعة الدعوة'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('invite-otp-field')),
        '123456',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(harness.controller.user?.id, 'invitee-1');
      expect(sharingApi.inviteLookupUserIds, isNot(contains('old-account')));
      expect(sharingApi.inviteLookupUserIds, contains('invitee-1'));
      expect(sharingApi.acceptUserIds, isEmpty);
      expect(sharingApi.acceptCalls, 0);
      expect(find.text('عرس رشاد وسارة'), findsOneWidget);
      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('invite-accept-button')),
      );
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
      expect(find.byKey(const Key('contributor-dashboard')), findsNothing);

      await _tapVisible(tester, find.byKey(const Key('invite-accept-button')));
      await tester.pumpAndSettle();

      expect(sharingApi.acceptUserIds, ['invitee-1']);
      expect(sharingApi.acceptCalls, 1);
      await _tapVisible(
        tester,
        find.byKey(const Key('invite-open-plan-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contributor-dashboard')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an invite accepted on another session waits for explicit entry without duplicate acceptance',
    (tester) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      expect(
        await harness.controller.verifyOtp(
          phone: '777000000',
          purpose: 'LOGIN',
          code: '123456',
        ),
        isTrue,
      );
      final sharingApi = _FakeSharingApi(
        invites: [_invite(token: token, status: 'ACCEPTED')],
        currentUserId: () => harness.controller.user?.id,
      );

      await _pumpBoundaryLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
      );
      await _openOtpStep(tester);
      await tester.enterText(
        find.byKey(const Key('invite-otp-field')),
        '123456',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(harness.controller.user?.id, 'invitee-1');
      expect(sharingApi.acceptCalls, 0);
      expect(sharingApi.acceptUserIds, isEmpty);
      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('invite-open-plan-button')),
      );
      expect(find.byKey(const Key('invite-open-plan-button')), findsOneWidget);
      expect(find.byKey(const Key('contributor-dashboard')), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const Key('invite-open-plan-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contributor-dashboard')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new app registration resumes at the explicit invite decision', (
    tester,
  ) async {
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnRegister = true;
    final sharingApi = _FakeSharingApi(
      invites: [_invite(token: token)],
      currentUserId: () => harness.controller.user?.id,
    );

    await _pumpBoundaryLinkedInviteScreen(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
      startGuestAtInvite: true,
    );
    expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);

    expect(
      await harness.controller.register(
        name: 'أحمد',
        phone: '777123456',
        password: 'secret123',
        otpCode: '123456',
        resumeInviteToken: token,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(harness.controller.user?.id, 'invitee-1');
    expect(sharingApi.inviteLookupUserIds, ['invitee-1']);
    expect(sharingApi.acceptUserIds, isEmpty);
    expect(sharingApi.acceptCalls, 0);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('invite-accept-button')),
    );
    expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
    expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
    expect(find.byKey(const Key('contributor-dashboard')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a private invite link verifies its phone even when another account is signed in',
    (tester) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      expect(
        await harness.controller.verifyOtp(
          phone: '777000000',
          purpose: 'LOGIN',
          code: '123456',
        ),
        isTrue,
      );
      expect(harness.controller.status, AuthStatus.authenticated);

      await _pumpLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: _FakeSharingApi(invites: [_invite(token: token)]),
      );

      expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
      expect(harness.repository.inviteRequestCalls, 0);
      expect(find.byKey(const Key('contributor-dashboard')), findsNothing);
    },
  );

  testWidgets('a private invite link rejects a non-invited phone before OTP', (
    tester,
  ) async {
    final token = _testInviteToken();
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

  testWidgets(
    'first private invite creates a contributor password with the same OTP',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.inviteAccountSetupRequired = true;
      harness.repository.authenticateOnVerify = true;
      final sharingApi = _FakeSharingApi(invites: [_invite(token: token)]);
      await _pumpBoundaryLinkedInviteScreen(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
        startGuestAtInvite: true,
      );

      await _openOtpStep(tester);
      expect(find.text('أنشئ حساب المساهم مرة واحدة'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('invite-account-name-field')),
        'أحمد المساهم',
      );
      await tester.enterText(
        find.byKey(const ValueKey('invite-account-password-field')),
        'contributor-secret',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey('invite-account-password-confirmation-field'),
        ),
        'contributor-secret',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('invite-account-setup-continue')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invite-otp-field')),
        '123456',
      );
      await tester.pumpAndSettle();

      expect(harness.repository.lastVerifiedInviteToken, token);
      expect(harness.repository.lastAccountName, 'أحمد المساهم');
      expect(harness.repository.lastAccountPassword, 'contributor-secret');
      expect(sharingApi.acceptCalls, 0);
      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('invite-accept-button')),
      );
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
      expect(find.byKey(const Key('contributor-dashboard')), findsNothing);
    },
  );

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
  final accountContexts = await _accountContexts();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: harness.controller),
        ChangeNotifierProvider<SharingProvider>.value(value: sharing),
        ChangeNotifierProvider<AccountContextController>.value(
          value: accountContexts,
        ),
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

Future<GoRouter> _pumpLinkedInviteScreen(
  WidgetTester tester,
  _AuthHarness harness, {
  required String token,
  required SharingApi sharingApi,
}) async {
  final sharing = SharingProvider(sharingApi);
  final accountContexts = await _accountContexts();
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
      GoRoute(
        path: '/register',
        builder: (context, state) => const Scaffold(
          body: SizedBox(key: Key('invite-registration-route')),
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
        ChangeNotifierProvider<AccountContextController>.value(
          value: accountContexts,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _pumpBoundaryLinkedInviteScreen(
  WidgetTester tester,
  _AuthHarness harness, {
  required String token,
  required SharingApi sharingApi,
  bool startGuestAtInvite = false,
}) async {
  final accountContexts = await _accountContexts();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: harness.controller),
        ChangeNotifierProvider<AccountContextController>.value(
          value: accountContexts,
        ),
      ],
      child: _AccountBoundaryInviteHarness(
        token: token,
        sharingApi: sharingApi,
        startGuestAtInvite: startGuestAtInvite,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AccountBoundaryInviteHarness extends StatelessWidget {
  const _AccountBoundaryInviteHarness({
    required this.token,
    required this.sharingApi,
    this.startGuestAtInvite = false,
  });

  final String token;
  final SharingApi sharingApi;
  final bool startGuestAtInvite;

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthController, String?>(
      (auth) => auth.user?.id,
    );
    return AarastSessionBoundary(
      identity: 'account:${userId ?? 'guest'}',
      builder: (_) => _BoundaryInviteRouterApp(
        token: token,
        sharingApi: sharingApi,
        initialLocation:
            userId == 'old-account' || (userId == null && startGuestAtInvite)
            ? '/invites/$token'
            : '/holding',
      ),
    );
  }
}

class _BoundaryInviteRouterApp extends StatefulWidget {
  const _BoundaryInviteRouterApp({
    required this.token,
    required this.sharingApi,
    required this.initialLocation,
  });

  final String token;
  final SharingApi sharingApi;
  final String initialLocation;

  @override
  State<_BoundaryInviteRouterApp> createState() =>
      _BoundaryInviteRouterAppState();
}

class _BoundaryInviteRouterAppState extends State<_BoundaryInviteRouterApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/holding',
        builder: (context, state) => const Scaffold(
          body: SizedBox(key: Key('new-account-holding-route')),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: SizedBox(key: Key('post-logout-login-route'))),
      ),
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

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SharingProvider>(
      create: (_) => SharingProvider(widget.sharingApi),
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router,
        builder: (context, child) => AarastAuthFlowRedirector(
          router: _router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

Future<void> _openVerifiedInvite(WidgetTester tester) async {
  await _openOtpStep(tester);
  await _scrollUntilVisible(tester, find.byKey(const Key('invite-otp-field')));
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

Future<AccountContextController> _accountContexts() async {
  final preferences = await SharedPreferences.getInstance();
  return AccountContextController(
    contextsApi: _InviteContextsGateway([
      accountContext(role: AccountContextRole.contributor, planId: 'plan-1'),
    ]),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
}

class _InviteContextsGateway implements AccountContextsGateway {
  const _InviteContextsGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((context) => context.contextKey == contextKey);
}

class _AuthHarness {
  const _AuthHarness(this.controller, this.repository);

  final AuthController controller;
  final _FakeAuthRepository repository;
}

PlanInvite _invite({
  String token = 'token-1',
  String status = 'PENDING',
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
    contextKey: status == 'ACCEPTED' ? 'plan:plan-1:contributor' : null,
    role: 'HELPER',
    status: status,
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
  String? lastVerifiedInviteToken;
  String? lastAccountName;
  String? lastAccountPassword;
  bool failVerify = false;
  bool failInviteRequest = false;
  String? verifyErrorCode;
  bool authenticateOnVerify = false;
  bool authenticateOnRegister = false;
  bool inviteAccountSetupRequired = false;
  Completer<void>? verifyGate;
  String otpDeliveryStatus = 'PENDING';

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
  }) async {
    if (!authenticateOnRegister) {
      throw const ApiException('Unexpected registration');
    }
    return AuthResponse(
      accessToken: 'registered-access-token',
      refreshToken: 'registered-refresh-token',
      refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      user: const SafeUser(
        id: 'invitee-1',
        name: 'أحمد',
        phone: '+967777123456',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  }

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
      deliveryStatus: otpDeliveryStatus,
    );
  }

  @override
  Future<OtpVerifyResult> verifyInviteOtp({
    required String token,
    required String phone,
    required String code,
    String? name,
    String? password,
  }) {
    lastVerifiedInviteToken = token;
    lastAccountName = name;
    lastAccountPassword = password;
    return verifyOtp(phone: phone, purpose: 'LOGIN', code: code);
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
      deliveryStatus: otpDeliveryStatus,
      accountSetupRequired: inviteAccountSetupRequired,
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
    if (verifyErrorCode != null) {
      throw ApiException(
        'Account not found after phone proof',
        statusCode: 404,
        serverCode: verifyErrorCode,
      );
    }
    if (failVerify) {
      throw const ApiException('OTP code is invalid or expired');
    }
    return OtpVerifyResult(
      verified: true,
      phone: phone,
      purpose: purpose,
      user: authenticateOnVerify
          ? phone.replaceAll(RegExp(r'\D'), '').endsWith('000000')
                ? const SafeUser(
                    id: 'old-account',
                    name: 'الحساب السابق',
                    phone: '+967777000000',
                    role: 'USER',
                    status: 'ACTIVE',
                  )
                : const SafeUser(
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

  @override
  Future<void> logout() async {}
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({this.invites = const [], this.currentUserId})
    : super(ApiClient(tokenProvider: () async => null));

  final List<PlanInvite> invites;
  final String? Function()? currentUserId;
  int acceptCalls = 0;
  int declineCalls = 0;
  final List<String?> inviteLookupUserIds = [];
  final List<String?> acceptUserIds = [];

  @override
  Future<List<PlanInvite>> getMyInvites() async => invites;

  @override
  Future<PlanInvite> getInvite(String token) async {
    inviteLookupUserIds.add(currentUserId?.call());
    return invites.singleWhere((invite) => invite.token == token);
  }

  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) async {
    acceptCalls += 1;
    acceptUserIds.add(currentUserId?.call());
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
      contextKey: 'plan:${invite.weddingPlanId}:contributor',
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
