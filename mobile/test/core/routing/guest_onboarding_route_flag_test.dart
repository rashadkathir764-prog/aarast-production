import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guest onboarding route flag', () {
    test(
      'does not redirect when guest-first onboarding is enabled by default',
      () {
        expect(
          AppRouter.guestOnboardingRedirect(AppFeatureFlags.defaults),
          isNull,
        );
      },
    );

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
