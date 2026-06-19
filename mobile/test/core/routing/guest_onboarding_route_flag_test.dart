import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guest onboarding dev route flag', () {
    test('redirects to current onboarding when feature flag is disabled', () {
      expect(
        AppRouter.guestOnboardingRedirect(AppFeatureFlags.defaults),
        AppRouter.onboarding,
      );
    });

    test('does not redirect when feature flag is enabled', () {
      const flags = AppFeatureFlags(
        enableGuestFirstOnboarding: true,
        enableProviderMode: false,
        enableProviderQuotes: false,
        enableGuestContacts: false,
        enableOfflineSync: true,
        enableAIHelper: false,
        enablePushNotifications: false,
        enableSubscriptions: false,
        enableMaps: false,
        enableAnalytics: false,
        enableNewUserBottomNavigation: false,
        enableProviderShell: false,
        enableSingleDashboardSummary: false,
      );

      expect(AppRouter.guestOnboardingRedirect(flags), isNull);
    });
  });
}
