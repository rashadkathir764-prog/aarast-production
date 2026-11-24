import 'package:aarast_mobile/app.dart' show AarastPlanProfileScope;
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_loading_state.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-323: one colour per plan. The bride's plan is rose end to end: the
// Material widgets (a text button, a dialog's buttons) take the theme's
// colour, and the first frame of her home is the loading state; neither may
// show the groom's teal.

Widget _inBridePlan(Widget child) => JourneyProfileScope(
  profile: JourneyProfile.of(planPersona: 'BRIDE', readerFeminine: true),
  child: Theme(
    data: AppTheme.light(accent: JourneyAccent.bride),
    child: Directionality(textDirection: TextDirection.rtl, child: child),
  ),
);

void main() {
  test('the theme takes the plan accent; without one it stays the app teal', () {
    final bride = AppTheme.light(accent: JourneyAccent.bride);
    expect(bride.colorScheme.primary, JourneyAccent.bride.primary);
    expect(AppTheme.light().colorScheme.primary, AppTheme.brand);
  });

  testWidgets('the app root dresses a kept bride plan in her rose theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = GuestOnboardingStorage(
      await SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => storage.saveDraft(
        GuestOnboardingDraft.quickLocalPlanSetup(
          planName: 'عرس سلمى',
          persona: GuestPersona.bride,
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
    late ThemeData seen;
    await tester.pumpWidget(
      Provider<GuestOnboardingStorage>.value(
        value: storage,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AarastPlanProfileScope(
            child: Builder(
              builder: (context) {
                seen = Theme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(seen.colorScheme.primary, JourneyAccent.bride.primary);
    expect(seen.textButtonTheme.style?.foregroundColor?.resolve({}),
        JourneyAccent.bride.primary);
  });

  testWidgets('a whole-screen loading state uses the plan colour', (
    tester,
  ) async {
    await tester.pumpWidget(_inBridePlan(const AarastScreenLoading()));
    final spinner = tester.widget<AarastInlineSpinner>(
      find.byType(AarastInlineSpinner),
    );
    expect(spinner.color, JourneyAccent.bride.primary);
  });

  testWidgets('a text button in the bride plan is rose, not teal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _inBridePlan(
        Scaffold(
          body: TextButton(onPressed: () {}, child: const Text('من جهات الاتصال')),
        ),
      ),
    );
    final theme = Theme.of(tester.element(find.text('من جهات الاتصال')));
    expect(
      theme.textButtonTheme.style?.foregroundColor?.resolve({}),
      JourneyAccent.bride.primary,
    );
  });
}
