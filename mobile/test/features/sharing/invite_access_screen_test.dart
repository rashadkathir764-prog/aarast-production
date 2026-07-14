import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  double textScale = 1,
}) async {
  final sharing = SharingProvider(_FakeSharingApi());
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

Future<void> _openOtpStep(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('invite-phone-field')),
    '777123456',
  );
  await tester.tap(find.byKey(const Key('invite-request-otp-button')));
  await tester.pumpAndSettle();
}

class _AuthHarness {
  const _AuthHarness(this.controller, this.repository);

  final AuthController controller;
  final _FakeAuthRepository repository;
}

PlanInvite _invite({
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
    token: 'token-1',
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
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => null), storage);

  int requestCalls = 0;
  int verifyCalls = 0;
  bool failVerify = false;
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
    return OtpVerifyResult(verified: true, phone: phone, purpose: purpose);
  }
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi() : super(ApiClient(tokenProvider: () async => null));
}
