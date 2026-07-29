import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/routing/app_route_guard_resolver.dart';
import 'package:aarast_mobile/core/routing/route_guard_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouteGuardResolver', () {
    test('returns null when guard result allows navigation', () {
      expect(
        AppRouteGuardResolver.redirectFor(const RouteGuardResult.allow()),
        isNull,
      );
    });

    test('returns explicit redirect target when guard result redirects', () {
      const result = RouteGuardResult.redirect(
        targetLocation: '/login',
        reason: RouteGuardReason.authRequired,
      );

      expect(AppRouteGuardResolver.redirectFor(result), '/login');
    });

    test('returns fallback redirect when guard result is blocked', () {
      const result = RouteGuardResult.blocked(
        reason: RouteGuardReason.featureDisabled,
      );

      expect(
        AppRouteGuardResolver.redirectFor(
          result,
          blockedFallbackLocation: '/home',
        ),
        '/home',
      );
    });

    test('default push feature flag allows navigation', () {
      expect(
        AppRouteGuardResolver.featureFlagRedirect(
          flags: AppFeatureFlags.defaults,
          flagName: 'enablePushNotifications',
          disabledRedirect: '/home',
        ),
        isNull,
      );
    });

    test('feature flag guard redirects when push is explicitly disabled', () {
      const flags = AppFeatureFlags(
        enableGuestFirstOnboarding: true,
        enableOfflineSync: true,
        enablePushNotifications: false,
      );

      expect(
        AppRouteGuardResolver.featureFlagRedirect(
          flags: flags,
          flagName: 'enablePushNotifications',
          disabledRedirect: '/home',
        ),
        '/home',
      );
    });

    test('feature flag guard allows when feature is enabled', () {
      const flags = AppFeatureFlags(
        enableGuestFirstOnboarding: true,
        enableOfflineSync: true,
        enablePushNotifications: false,
      );

      expect(
        AppRouteGuardResolver.featureFlagRedirect(
          flags: flags,
          flagName: 'enableGuestFirstOnboarding',
          disabledRedirect: '/onboarding',
        ),
        isNull,
      );
    });
  });
}
