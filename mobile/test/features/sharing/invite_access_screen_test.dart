import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/session_boundary.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

String _testInviteToken() => List.filled(43, 'a').join();

void main() {
  test(
    'private invite resume tokens are validated, memory-only, and one-shot',
    () async {
      final token = _testInviteToken();
      final invalidHarness = await _authHarness();
      invalidHarness.repository.authenticateOnVerify = true;

      expect(
        await invalidHarness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
          resumeInviteToken: 'not-a-private-token',
        ),
        isTrue,
      );
      expect(invalidHarness.controller.hasPendingInviteResume, isFalse);

      final validHarness = await _authHarness();
      validHarness.repository.authenticateOnVerify = true;

      expect(
        await validHarness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
          resumeInviteToken: token,
        ),
        isTrue,
      );
      expect(validHarness.controller.claimPendingInviteResumeRoute(), token);
      expect(validHarness.controller.claimPendingInviteResumeRoute(), isNull);
      expect(
        validHarness.controller.consumePendingInviteResume('${token}x'),
        isFalse,
      );
      expect(validHarness.controller.consumePendingInviteResume(token), isTrue);
      expect(
        validHarness.controller.consumePendingInviteResume(token),
        isFalse,
      );

      final logoutHarness = await _authHarness();
      logoutHarness.repository.authenticateOnVerify = true;

      await logoutHarness.controller.verifyOtp(
        phone: '777123456',
        purpose: 'LOGIN',
        code: '123456',
        resumeInviteToken: token,
      );
      await logoutHarness.controller.logout();
      expect(logoutHarness.controller.claimPendingInviteResumeRoute(), isNull);
    },
  );

  test(
    'completed app registration preserves a valid private invite for the new account boundary',
    () async {
      final token = _testInviteToken();
      final invalidHarness = await _authHarness();
      invalidHarness.repository.authenticateOnRegister = true;

      expect(
        await invalidHarness.controller.register(
          name: 'أحمد',
          phone: '777123456',
          otpCode: '123456',
          resumeInviteToken: 'not-a-private-token',
        ),
        isTrue,
      );
      expect(invalidHarness.controller.hasPendingInviteResume, isFalse);

      final validHarness = await _authHarness();
      validHarness.repository.authenticateOnRegister = true;

      expect(
        await validHarness.controller.register(
          name: 'أحمد',
          phone: '777123456',
          otpCode: '123456',
          resumeInviteToken: token,
        ),
        isTrue,
      );
      expect(validHarness.controller.status, AuthStatus.authenticated);
      expect(validHarness.controller.claimPendingInviteResumeRoute(), token);
      expect(validHarness.controller.claimPendingInviteResumeRoute(), isNull);
      expect(validHarness.controller.consumePendingInviteResume(token), isTrue);
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
    'q01: an invite link starts with the phone, nothing of the plan',
    (tester) async {
      final harness = await _authHarness();
      await _pumpGuestInvite(tester, harness);

      expect(find.text('دعوة للمشاركة'), findsOneWidget);
      expect(find.text('رقم جوالك'), findsOneWidget);
      expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
      expect(find.text('نفس الرقم اللي وصلته الدعوة عليه.'), findsOneWidget);
      // D75: a first visit's name is asked with the number; no password.
      expect(
        find.byKey(const ValueKey('invite-account-name-field')),
        findsOneWidget,
      );
      expect(find.textContaining('كلمة المرور'), findsNothing);
      expect(find.text('أرسل الرمز'), findsOneWidget);
      // Nothing of the plan or the inviter is read before the code (C35).
      expect(find.byKey(const ValueKey('invite-inviter-card')), findsNothing);
      expect(find.textContaining('يشتيك معه'), findsNothing);
      expect(find.text('إنشاء خطة'), findsNothing);
    },
  );

  testWidgets('the code resend waits the full 60 seconds', (tester) async {
    final harness = await _authHarness();
    await _pumpGuestInvite(tester, harness);
    await _openOtpStep(tester);

    expect(find.byKey(const Key('invite-otp-field')), findsOneWidget);
    expect(harness.repository.requestCalls, 1);
    expect(find.text('نرسله مرة ثانية بعد 1:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('otp-resend-button')));
    await tester.pump();
    expect(harness.repository.requestCalls, 1);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('نرسله مرة ثانية بعد 0:01'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('أرسله مرة ثانية'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey('otp-resend-button')));
    await tester.pump();
    expect(harness.repository.requestCalls, 2);
    expect(find.text('نرسله مرة ثانية بعد 1:00'), findsOneWidget);
  });

  for (final status in ['PENDING', 'UNCERTAIN']) {
    testWidgets('a $status code never claims WhatsApp delivery', (
      tester,
    ) async {
      final harness = await _authHarness();
      harness.repository.otpDeliveryStatus = status;
      await _pumpGuestInvite(tester, harness);
      await _openOtpStep(tester);

      expect(find.text('طلبنا لك رمز على واتساب'), findsOneWidget);
      expect(find.text('أرسلنا لك رمز على واتساب'), findsNothing);
    });
  }

  testWidgets('a delivered code says so', (tester) async {
    final harness = await _authHarness();
    harness.repository.otpDeliveryStatus = 'DELIVERED';
    await _pumpGuestInvite(tester, harness);
    await _openOtpStep(tester);

    expect(find.text('أرسلنا لك رمز على واتساب'), findsOneWidget);
    expect(find.text('طلبنا لك رمز على واتساب'), findsNothing);
  });

  testWidgets('a new attempt clears the last code error', (tester) async {
    final harness = await _authHarness();
    harness.repository.failVerify = true;
    await _pumpGuestInvite(tester, harness);
    await _openOtpStep(tester);

    await tester.enterText(find.byKey(const Key('invite-otp-field')), '999999');
    await tester.pumpAndSettle();
    expect(harness.controller.errorMessage, isNotNull);

    await tester.enterText(find.byKey(const Key('invite-otp-field')), '1');
    await tester.pump();
    expect(harness.controller.errorMessage, isNull);
  });

  testWidgets('the code is sent once while it is being checked', (
    tester,
  ) async {
    final harness = await _authHarness();
    harness.repository
      ..failVerify = true
      ..verifyGate = Completer<void>();
    await _pumpGuestInvite(tester, harness);
    await _openOtpStep(tester);

    // D75: there is no confirm button; six digits send the code, and the
    // boxes lock while it is checked.
    await tester.enterText(find.byKey(const Key('invite-otp-field')), '123456');
    await tester.pump();
    expect(harness.repository.verifyCalls, 1);
    expect(find.byKey(const Key('invite-verify-otp-button')), findsNothing);
    final otpField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('invite-otp-field')),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    );
    expect(otpField.enabled, isFalse);

    harness.repository.verifyGate!.complete();
    await tester.pumpAndSettle();
    expect(harness.repository.verifyCalls, 1);
  });

  testWidgets('the code step fits 320px at 1.3 text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _authHarness();
    await _pumpGuestInvite(tester, harness, textScale: 1.3);
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
    'q03: after the code the invite shows who asks, the role and each right',
    (tester) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      final sharingApi = _FakeSharingApi(
        invites: [
          _invite(
            token: token,
            canManageTasks: true,
            canManageGuests: true,
            weddingDate: DateTime(2027, 1, 21),
            weddingCity: 'صنعاء',
          ),
        ],
      );

      await _pumpGuestInvite(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
      );
      await _openVerifiedInvite(tester);

      expect(find.text('تأكدنا من رقمك.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('invite-inviter-card')),
          matching: find.text('رشاد يشتيك معه في عرسه'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('عرس رشاد وسارة · صنعاء · الخميس 21 يناير'),
        findsOneWidget,
      );
      expect(find.text('أنت مساعد'), findsOneWidget);
      expect(find.text('موعد العرس'), findsOneWidget);
      // C27: a participant adds tasks and finishes their own.
      expect(find.text('المهام: تضيف مهام وتخلّص اللي عليك'), findsOneWidget);
      expect(find.text('الضيوف: تضيف وترتب'), findsOneWidget);
      for (final closed in ['المال', 'المزودين']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('invite-right-$closed')),
            matching: find.byIcon(LucideIcons.x),
          ),
          findsOneWidget,
        );
      }
      expect(find.textContaining('الرفد'), findsNothing);
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
      expect(sharingApi.acceptCalls, 0);
      expect(find.byKey(const Key('participant-home')), findsNothing);
    },
  );

  for (final (persona, owner, title) in [
    ('BRIDE', true, 'سلمى تشتيك معها في عرسها'),
    ('GROOM', true, 'سلمى يشتيك معه في عرسه'),
    ('BRIDE', false, 'دعوة من سلمى للمشاركة في عرس سلمى'),
  ]) {
    testWidgets('D75: the invite speaks of the owner in their words ($title)', (
      tester,
    ) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.authenticateOnVerify = true;
      await _pumpGuestInvite(
        tester,
        harness,
        token: token,
        sharingApi: _FakeSharingApi(
          invites: [
            _invite(
              token: token,
              inviterName: 'سلمى',
              weddingPlanTitle: 'عرس سلمى',
              planPersona: persona,
              inviterIsOwner: owner,
            ),
          ],
        ),
      );
      await _openVerifiedInvite(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('invite-inviter-card')),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
      // A bride's plan speaks to the women she invites in their words.
      expect(
        find.text(persona == 'BRIDE' ? 'أنتِ مساعدة' : 'أنت مساعد'),
        findsOneWidget,
      );
    });
  }

  testWidgets('q03: money shows its real level, never more', (tester) async {
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: _FakeSharingApi(
        invites: [_invite(token: token, canViewMoney: true)],
      ),
    );
    await _openVerifiedInvite(tester);
    expect(find.text('المال: تشوف بس'), findsOneWidget);
    expect(find.text('المال: تشوف وتسجّل'), findsNothing);
  });

  testWidgets('joining selects the participant path and opens the plan home', (
    tester,
  ) async {
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(
      invites: [_invite(token: token, canManageTasks: true)],
    );

    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
    );
    await _openVerifiedInvite(tester);
    await _tapVisible(tester, find.byKey(const Key('invite-accept-button')));
    await tester.pumpAndSettle();

    expect(sharingApi.acceptCalls, 1);
    expect(find.byKey(const Key('participant-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      expect(find.text('رشاد يشتيك معه في عرسه'), findsOneWidget);
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
      expect(find.byKey(const Key('participant-home')), findsNothing);

      await _tapVisible(tester, find.byKey(const Key('invite-accept-button')));
      await tester.pumpAndSettle();

      expect(sharingApi.acceptUserIds, ['invitee-1']);
      expect(sharingApi.acceptCalls, 1);
      expect(find.byKey(const Key('participant-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an invite accepted on another session opens with «ادخل الخطة» and is not accepted twice',
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
      expect(find.text('ادخل الخطة'), findsOneWidget);
      expect(find.byKey(const Key('invite-accept-button')), findsNothing);
      expect(find.byKey(const Key('participant-home')), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const Key('invite-open-plan-button')),
      );
      await tester.pumpAndSettle();
      expect(sharingApi.acceptCalls, 0);
      expect(find.byKey(const Key('participant-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an accepted invite without a membership says it ended', (
    tester,
  ) async {
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(
      invites: [
        _invite(token: token, status: 'ACCEPTED', withContextKey: false),
      ],
      currentUserId: () => harness.controller.user?.id,
    );

    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
    );
    await _openVerifiedInvite(tester);

    expect(find.byKey(const Key('invite-membership-ended')), findsOneWidget);
    expect(find.textContaining('ما عاد لك وصول للخطة'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-rights')), findsNothing);
    expect(find.byKey(const Key('invite-open-plan-button')), findsNothing);
    expect(find.byKey(const Key('invite-accept-button')), findsNothing);
    expect(sharingApi.acceptCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new app account resumes at the explicit invite decision', (
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
        otpCode: '123456',
        resumeInviteToken: token,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(harness.controller.user?.id, 'invitee-1');
    expect(sharingApi.inviteLookupUserIds, ['invitee-1']);
    expect(sharingApi.acceptCalls, 0);
    expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
    expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
    expect(find.byKey(const Key('participant-home')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a private link proves its phone even when another account is signed in',
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
      expect(find.byKey(const ValueKey('invite-inviter-card')), findsNothing);
    },
  );

  testWidgets('a phone the invite was not sent to stops before the code', (
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

  testWidgets('q02: a first invite makes the account with the same code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.inviteAccountSetupRequired = true;
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(invites: [_invite(token: token)]);
    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
    );

    await _openOtpStep(tester);
    // D75: the code is on its way; a first visit names the account on the
    // same page as the number, and nothing asks for a password.
    expect(harness.repository.inviteRequestCalls, 1);
    expect(find.byKey(const Key('invite-otp-field')), findsNothing);
    expect(find.text('اكتب اسمك، أول مرة تدخل اعّرست'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
    expect(find.textContaining('كلمة المرور'), findsNothing);

    // Still no name: the step waits and the code is not asked again.
    await _tapVisible(
      tester,
      find.byKey(const Key('invite-request-otp-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-otp-field')), findsNothing);
    expect(harness.repository.inviteRequestCalls, 1);

    await tester.enterText(
      find.byKey(const ValueKey('invite-account-name-field')),
      'أحمد المساهم',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('invite-request-otp-button')),
    );
    await tester.pumpAndSettle();
    expect(harness.repository.inviteRequestCalls, 1);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('invite-otp-field')),
    );
    await tester.enterText(find.byKey(const Key('invite-otp-field')), '123456');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(harness.repository.lastVerifiedInviteToken, token);
    expect(harness.repository.lastAccountName, 'أحمد المساهم');
    expect(harness.repository.lastAccountPassword, isNull);
    expect(sharingApi.acceptCalls, 0);
    expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
    expect(find.byKey(const Key('invite-decline-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a code that proves a number the invite does not open with closes it',
    (tester) async {
      final token = _testInviteToken();
      final harness = await _authHarness();
      harness.repository.verifyErrorCode = 'INVITE_NOT_FOUND_FOR_PHONE';
      final sharingApi = _FakeSharingApi(invites: [_invite(token: token)]);
      await _pumpGuestInvite(
        tester,
        harness,
        token: token,
        sharingApi: sharingApi,
      );

      await _openVerifiedInvite(tester);

      expect(harness.repository.verifyCalls, 1);
      expect(find.text('الدعوة ما تفتح بهذا الرقم'), findsOneWidget);
      expect(find.byKey(const Key('invite-closed')), findsOneWidget);
      expect(find.byKey(const Key('invite-ask-new')), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-inviter-card')), findsNothing);
      expect(find.byKey(const Key('invite-accept-button')), findsNothing);
      expect(sharingApi.inviteLookupUserIds, isEmpty);

      // «تغيير الرقم» goes back to the number.
      await _tapVisible(tester, find.text('تغيير الرقم'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
    },
  );

  testWidgets('refusing asks first in a journey sheet', (tester) async {
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(invites: [_invite(token: token)]);

    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
    );
    await _openVerifiedInvite(tester);
    await _tapVisible(tester, find.byKey(const Key('invite-decline-button')));
    await tester.pumpAndSettle();

    expect(find.byType(JourneySheetBody), findsOneWidget);
    expect(find.text('ترفض الدعوة؟'), findsOneWidget);
    expect(sharingApi.declineCalls, 0);

    await tester.tap(find.byKey(const Key('invite-confirm-decline-button')));
    await tester.pumpAndSettle();

    expect(sharingApi.declineCalls, 1);
    expect(find.text('رفضت هذي الدعوة.'), findsOneWidget);
    expect(find.byKey(const Key('invite-accept-button')), findsNothing);
    expect(find.byKey(const Key('participant-home')), findsNothing);
  });

  testWidgets('every right fits 320px at 1.3 text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final token = _testInviteToken();
    final harness = await _authHarness();
    harness.repository.authenticateOnVerify = true;
    final sharingApi = _FakeSharingApi(
      invites: [
        _invite(
          token: token,
          canViewMoney: true,
          canManageMoney: true,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: true,
          canEditPlan: true,
        ),
      ],
    );

    await _pumpGuestInvite(
      tester,
      harness,
      token: token,
      sharingApi: sharingApi,
      textScale: 1.3,
    );
    await _openVerifiedInvite(tester);

    expect(find.text('المال: تشوف وتسجّل'), findsOneWidget);
    expect(find.text('المشاركين: تضيف ناس للخطة'), findsOneWidget);
    expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A guest opens the invite link and proves the phone; the verified account
/// then resumes the same link through the account boundary.
Future<void> _pumpGuestInvite(
  WidgetTester tester,
  _AuthHarness harness, {
  String? token,
  SharingApi? sharingApi,
  double textScale = 1,
}) {
  final link = token ?? _testInviteToken();
  return _pumpBoundaryLinkedInviteScreen(
    tester,
    harness,
    token: link,
    sharingApi: sharingApi ?? _FakeSharingApi(invites: [_invite(token: link)]),
    startGuestAtInvite: true,
    textScale: textScale,
  );
}

Future<_AuthHarness> _authHarness() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final repository = _FakeAuthRepository(authStorage);
  final controller = AuthController(repository);
  await controller.restoreSession();
  return _AuthHarness(controller, repository);
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
            InviteDecisionScreen(token: state.pathParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          key: Key('participant-home'),
          body: Text('رئيسية المشارك'),
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
  double textScale = 1,
}) async {
  _harnessTextScale = textScale;
  if (harness.controller.user != null) {
    harness.controller.claimPendingAuthenticatedEntry();
  }
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
            InviteDecisionScreen(token: state.pathParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          key: Key('participant-home'),
          body: Text('رئيسية المشارك'),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_harnessTextScale)),
          child: AarastAuthFlowRedirector(
            router: _router,
            child: child ?? const SizedBox.shrink(),
          ),
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

Future<AccountContextController> _accountContexts({
  List<String> planIds = const ['plan-1'],
}) async {
  final preferences = await SharedPreferences.getInstance();
  return AccountContextController(
    contextsApi: _InviteContextsGateway([
      for (final planId in planIds)
        accountContext(role: AccountContextRole.contributor, planId: planId),
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
  String id = 'invite-1',
  String weddingPlanId = 'plan-1',
  String weddingPlanTitle = 'عرس رشاد وسارة',
  String token = 'token-1',
  String status = 'PENDING',
  bool withContextKey = true,
  bool canViewMoney = false,
  bool canEditPlan = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
  bool canManageProviders = false,
  bool canInviteMembers = false,
  bool canManageMoney = false,
  DateTime? weddingDate,
  String? weddingCity,
  String inviterName = 'رشاد',
  String? planPersona,
  bool? inviterIsOwner,
}) {
  return PlanInvite(
    id: id,
    weddingPlanId: weddingPlanId,
    token: token,
    contextKey: status == 'ACCEPTED' && withContextKey
        ? 'plan:$weddingPlanId:contributor'
        : null,
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
    weddingPlanTitle: weddingPlanTitle,
    inviterName: inviterName,
    planPersona: planPersona,
    inviterIsOwner: inviterIsOwner,
    weddingDate: weddingDate,
    weddingCity: weddingCity,
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
    planPersona: invite.planPersona,
    inviterIsOwner: invite.inviterIsOwner,
    weddingDate: invite.weddingDate,
    weddingCity: invite.weddingCity,
  );
}

/// The text size the boundary app shows, set by each pump.
double _harnessTextScale = 1;
