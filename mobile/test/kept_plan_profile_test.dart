import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D75: with no plan open, the plan kept on this phone gives every screen
// before the account its owner's colour and voice: a bride's plan is saved
// in her rose and her words.

GuestOnboardingDraft _keptPlan(GuestPersona persona) =>
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
    );

void main() {
  test('a kept bride plan, no plan open: her profile', () {
    final profile = planJourneyProfile(keptPlanPersona: 'BRIDE');
    expect(profile.isBride, isTrue);
    expect(profile.say('احفظ', 'احفظي'), 'احفظي');
  });

  test('nothing kept and nothing open: the app own profile', () {
    final profile = planJourneyProfile();
    expect(profile.isBride, isFalse);
  });

  testWidgets('saving a bride plan turns the root rose; clearing it reverts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = GuestOnboardingStorage(
      await SharedPreferences.getInstance(),
    );
    late JourneyProfile seen;
    await tester.pumpWidget(
      Provider<GuestOnboardingStorage>.value(
        value: storage,
        child: AarastPlanProfileScope(
          child: Builder(
            builder: (context) {
              seen = context.journeyProfile;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen.isBride, isFalse);

    await tester.runAsync(
      () => storage.saveDraft(_keptPlan(GuestPersona.bride)),
    );
    await tester.pump();
    expect(seen.isBride, isTrue);

    await tester.runAsync(storage.clearDraft);
    await tester.pump();
    expect(seen.isBride, isFalse);
  });
}
