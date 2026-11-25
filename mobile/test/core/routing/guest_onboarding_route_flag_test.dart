import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('guest onboarding route flag', () {
    // RA-TS-24: this read app_router.dart for the redirect's text. The real
    // router, built with the flag off, is sent to the dev preview route.
    Future<GoRouter> openPreview(
      WidgetTester tester,
      AppFeatureFlags flags,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final auth = AuthController(
        AuthRepository(
          ApiClient(tokenProvider: storage.readAccessToken),
          storage,
        ),
      )..restoreSession();
      final router = AppRouter.create(flags: flags);
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<AuthStorage>.value(value: storage),
            Provider<GuestOnboardingStorage>.value(
              value: GuestOnboardingStorage(preferences),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go(AppRouter.guestOnboardingPreview);
      await tester.pump();
      await tester.pump();
      return router;
    }

    testWidgets('the dev preview route follows the runtime feature flag', (
      tester,
    ) async {
      final off = await openPreview(
        tester,
        const AppFeatureFlags(
          enableGuestFirstOnboarding: false,
          enableOfflineSync: true,
          enablePushNotifications: false,
        ),
      );
      // «/onboarding» is the legacy route that hands on to the welcome.
      expect(off.state.uri.path, AppRouter.welcome);

      final on = await openPreview(tester, AppFeatureFlags.defaults);
      expect(on.state.uri.path, AppRouter.guestOnboardingPreview);
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
