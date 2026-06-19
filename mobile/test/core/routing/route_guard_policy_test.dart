import 'package:aarast_mobile/core/routing/route_guard_policy.dart';
import 'package:aarast_mobile/core/routing/route_guard_result.dart';
import 'package:aarast_mobile/core/routing/route_guard_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteGuardResult', () {
    test('can represent allow, redirect, and blocked outcomes', () {
      const allow = RouteGuardResult.allow();
      const redirect = RouteGuardResult.redirect(
        targetLocation: '/login',
        reason: RouteGuardReason.authRequired,
      );
      const blocked = RouteGuardResult.blocked(
        reason: RouteGuardReason.featureDisabled,
      );

      expect(allow.outcome, RouteGuardOutcome.allow);
      expect(redirect.outcome, RouteGuardOutcome.redirect);
      expect(redirect.targetLocation, '/login');
      expect(blocked.outcome, RouteGuardOutcome.blocked);
      expect(blocked.reason.arabicMessage, isNotEmpty);
    });
  });

  group('RouteGuardPolicy', () {
    test('blocks a disabled feature flag requirement', () {
      const policy = RouteGuardPolicy([
        RouteGuardRule.featureFlagRequired(flagName: 'enableAIHelper'),
      ]);

      final result = policy.evaluate(
        const RouteGuardContext(featureFlags: {'enableAIHelper': false}),
      );

      expect(result.outcome, RouteGuardOutcome.blocked);
      expect(result.reason, RouteGuardReason.featureDisabled);
    });

    test('providerOnly blocks user mode in theoretical evaluation', () {
      const policy = RouteGuardPolicy([RouteGuardRule.providerOnly()]);

      final result = policy.evaluate(
        const RouteGuardContext(userMode: RouteGuardUserMode.user),
      );

      expect(result.outcome, RouteGuardOutcome.blocked);
      expect(result.reason, RouteGuardReason.providerOnly);
    });

    test('authRequired redirects an unauthenticated user', () {
      const policy = RouteGuardPolicy([RouteGuardRule.authRequired()]);

      final result = policy.evaluate(
        const RouteGuardContext(isAuthenticated: false),
      );

      expect(result.outcome, RouteGuardOutcome.redirect);
      expect(result.targetLocation, '/login');
      expect(result.reason, RouteGuardReason.authRequired);
    });

    test('allows when every required guard is satisfied', () {
      const policy = RouteGuardPolicy([
        RouteGuardRule.authRequired(),
        RouteGuardRule.providerOnly(),
        RouteGuardRule.featureFlagRequired(flagName: 'enableProviderShell'),
      ]);

      final result = policy.evaluate(
        const RouteGuardContext(
          isAuthenticated: true,
          userMode: RouteGuardUserMode.provider,
          featureFlags: {'enableProviderShell': true},
        ),
      );

      expect(result.outcome, RouteGuardOutcome.allow);
    });
  });
}
