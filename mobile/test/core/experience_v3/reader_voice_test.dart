import 'package:aarast_mobile/app.dart' show AarastPlanProfileScope;
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/auth/auth_api.dart'
    show AuthActionGuard;
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-322: the layers with no screen (a provider's refusal, a guard's
// line) wrote the masculine for everyone, so a bride read «جرّب» and «سجّل».
// They say it as a screen does, in the reader's form, which the app root
// hands them with the open plan's profile.

class _NoFinanceApi implements FinanceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoMoneySharingApi extends SharingApi {
  _NoMoneySharingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async =>
      PlanAccessPermissions(
        weddingPlanId: planId,
        isOwner: false,
        canViewMoney: false,
        canManageMoney: false,
      );
}

Future<void> _pumpKeptPlan(WidgetTester tester, GuestPersona persona) async {
  SharedPreferences.setMockInitialValues({});
  final storage = GuestOnboardingStorage(await SharedPreferences.getInstance());
  await tester.runAsync(
    () => storage.saveDraft(
      GuestOnboardingDraft.quickLocalPlanSetup(
        planName: 'عرس سلمى',
        persona: persona,
        location: WeddingLocationDraft.fromLegacyFields(
          governorate: 'عدن',
          city: 'عدن',
        ),
        weddingDate: null,
        currency: 'YER',
        startingItemNames: const ['فستان العروسة'],
      ).copyWith(
        guestPlanId: 'local-guest-1',
        createdAt: DateTime(2026, 11, 2),
        isGuestPlan: true,
        needsSync: true,
      ),
    ),
  );
  await tester.pumpWidget(
    Provider<GuestOnboardingStorage>.value(
      value: storage,
      child: const MaterialApp(
        home: AarastPlanProfileScope(child: SizedBox()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() => ReaderVoice.speakTo(feminine: false));

  test('without a reader form, the layers speak the masculine', () {
    expect(ReaderVoice.say('جرّب', 'جرّبي'), 'جرّب');
    expect(AuthActionGuard.sharingLoginGateTitle, 'سجّل الدخول لمشاركة الخطة');
  });

  test('a layer says the sentence in the reader form it was handed', () async {
    ReaderVoice.speakTo(feminine: true);
    expect(ReaderVoice.say('جرّب', 'جرّبي'), 'جرّبي');
    expect(AuthActionGuard.sharingLoginGateTitle, 'سجّلي الدخول لمشاركة الخطة');

    final provider = FinanceProvider(
      _NoFinanceApi(),
      permissionsApi: _NoMoneySharingApi(),
    );
    await provider.loadMoney('plan-a');
    expect(
      provider.loadErrorMessage,
      'ما عندك صلاحية تشوفين المال في هذي الخطة.',
    );

    ReaderVoice.speakTo(feminine: false);
    final again = FinanceProvider(
      _NoFinanceApi(),
      permissionsApi: _NoMoneySharingApi(),
    );
    await again.loadMoney('plan-a');
    expect(
      again.loadErrorMessage,
      'ما عندك صلاحية تشوف المال في هذي الخطة.',
    );
  });

  testWidgets('the app root hands a kept bride plan\'s reader form to the '
      'layers, and takes it back when it goes', (tester) async {
    await _pumpKeptPlan(tester, GuestPersona.bride);
    expect(ReaderVoice.feminine, isTrue);
    expect(AuthActionGuard.sharingLoginGateTitle, 'سجّلي الدخول لمشاركة الخطة');

    await tester.pumpWidget(const SizedBox());
    expect(ReaderVoice.feminine, isFalse);
  });

  testWidgets('a kept groom plan keeps the masculine', (tester) async {
    await _pumpKeptPlan(tester, GuestPersona.groom);
    expect(ReaderVoice.feminine, isFalse);
  });
}
