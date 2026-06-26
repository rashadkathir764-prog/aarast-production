import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('user navigation shell dev route flag', () {
    test('keeps the new user navigation disabled by default', () {
      expect(AppFeatureFlags.defaults.enableNewUserBottomNavigation, isFalse);
    });

    test('redirects to current home route when feature flag is disabled', () {
      expect(
        AppRouter.userNavigationShellRedirect(AppFeatureFlags.defaults),
        AppRouter.home,
      );
    });

    test('does not redirect when feature flag is enabled', () {
      const flags = AppFeatureFlags(
        enableGuestFirstOnboarding: false,
        enableProviderMode: false,
        enableProviderQuotes: false,
        enableGuestContacts: false,
        enableOfflineSync: true,
        enableAIHelper: false,
        enablePushNotifications: false,
        enableSubscriptions: false,
        enableMaps: false,
        enableAnalytics: false,
        enableNewUserBottomNavigation: true,
        enableProviderShell: false,
        enableSingleDashboardSummary: false,
      );

      expect(AppRouter.userNavigationShellRedirect(flags), isNull);
    });

    test('keeps the default app route unchanged', () {
      expect(AppRouter.splash, '/');
    });

    test('default create starts at splash and uses safe default flags', () {
      final router = AppRouter.create();
      addTearDown(router.dispose);

      expect(router.routeInformationProvider.value.uri.path, AppRouter.splash);
      expect(
        AppRouter.guestOnboardingRedirect(AppFeatureFlags.defaults),
        isNull,
      );
      expect(
        AppRouter.userNavigationShellRedirect(AppFeatureFlags.defaults),
        AppRouter.home,
      );
    });
  });
}
