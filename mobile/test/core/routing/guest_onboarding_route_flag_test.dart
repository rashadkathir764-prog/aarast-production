import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';

void main() {
  group('guest onboarding route flag', () {
    test('the dev preview route consumes the runtime feature flag', () {
      // The router's route trees live in per-area part files of the router
      // library (spec M6); the contract reads the whole library.
      final source = readLibrarySource('lib/core/routing/app_router.dart');
      expect(
        source,
        contains(
          'redirect: (context, state) => AppRouter.guestOnboardingRedirect(flags)',
        ),
      );
    });

    test(
      'does not redirect when guest-first onboarding is enabled by default',
      () {
        expect(
          AppRouter.guestOnboardingRedirect(AppFeatureFlags.defaults),
          isNull,
        );
      },
    );

    test('a release build never serves the dev preview route (R-02)', () {
      expect(
        AppRouter.guestOnboardingRedirect(
          AppFeatureFlags.defaults,
          release: true,
        ),
        AppRouter.welcome,
      );
      expect(
        AppRouter.guestOnboardingRedirect(
          AppFeatureFlags.defaults,
          release: false,
        ),
        isNull,
      );
    });

    test('redirects to current onboarding when feature flag is disabled', () {
      const flags = AppFeatureFlags(
        enableGuestFirstOnboarding: false,
        enableOfflineSync: true,
        enablePushNotifications: false,
      );

      expect(AppRouter.guestOnboardingRedirect(flags), AppRouter.onboarding);
    });
  });
}
