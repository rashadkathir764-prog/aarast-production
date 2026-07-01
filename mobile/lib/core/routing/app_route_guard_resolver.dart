import '../config/app_feature_flags.dart';
import 'route_guard_policy.dart';
import 'route_guard_result.dart';
import 'route_guard_types.dart';

class AppRouteGuardResolver {
  const AppRouteGuardResolver._();

  static String? redirectFor(
    RouteGuardResult result, {
    String? blockedFallbackLocation,
  }) {
    return switch (result.outcome) {
      RouteGuardOutcome.allow => null,
      RouteGuardOutcome.redirect => result.targetLocation,
      RouteGuardOutcome.blocked => blockedFallbackLocation,
    };
  }

  static String? featureFlagRedirect({
    required AppFeatureFlags flags,
    required String flagName,
    required String disabledRedirect,
  }) {
    final policy = RouteGuardPolicy([
      RouteGuardRule.featureFlagRequired(flagName: flagName),
    ]);
    final result = policy.evaluate(
      RouteGuardContext(featureFlags: flags.toMap()),
    );

    return redirectFor(result, blockedFallbackLocation: disabledRedirect);
  }
}
