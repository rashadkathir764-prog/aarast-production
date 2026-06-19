import 'route_guard_result.dart';
import 'route_guard_types.dart';

class RouteGuardPolicy {
  const RouteGuardPolicy(this.rules);

  final List<RouteGuardRule> rules;

  RouteGuardResult evaluate(RouteGuardContext context) {
    for (final rule in rules) {
      final result = _evaluateRule(rule, context);
      if (result.outcome != RouteGuardOutcome.allow) {
        return result;
      }
    }

    return const RouteGuardResult.allow();
  }

  RouteGuardResult _evaluateRule(
    RouteGuardRule rule,
    RouteGuardContext context,
  ) {
    return switch (rule.type) {
      RouteGuardType.guestAllowed => const RouteGuardResult.allow(),
      RouteGuardType.authRequired =>
        context.isAuthenticated
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.redirect(
                targetLocation: '/login',
                reason: RouteGuardReason.authRequired,
              ),
      RouteGuardType.currentPlanRequired =>
        context.hasCurrentPlan
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.currentPlanRequired,
              ),
      RouteGuardType.financePermissionRequired =>
        context.canAccessFinance
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.financePermissionRequired,
              ),
      RouteGuardType.taskPermissionRequired =>
        context.canManageTasks
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.taskPermissionRequired,
              ),
      RouteGuardType.guestPermissionRequired =>
        context.canManageGuests
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.guestPermissionRequired,
              ),
      RouteGuardType.providerOnly =>
        context.userMode == RouteGuardUserMode.provider
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.providerOnly,
              ),
      RouteGuardType.userOnly =>
        context.userMode == RouteGuardUserMode.user
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(reason: RouteGuardReason.userOnly),
      RouteGuardType.featureFlagRequired =>
        context.isFeatureEnabled(rule.flagName ?? '')
            ? const RouteGuardResult.allow()
            : const RouteGuardResult.blocked(
                reason: RouteGuardReason.featureDisabled,
              ),
    };
  }
}
