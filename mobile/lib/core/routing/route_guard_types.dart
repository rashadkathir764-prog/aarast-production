enum RouteGuardType {
  guestAllowed,
  authRequired,
  currentPlanRequired,
  financePermissionRequired,
  taskPermissionRequired,
  guestPermissionRequired,
  providerOnly,
  userOnly,
  featureFlagRequired,
}

enum RouteGuardUserMode { guest, user, provider }

class RouteGuardRule {
  const RouteGuardRule._(this.type, {this.flagName});

  const RouteGuardRule.guestAllowed() : this._(RouteGuardType.guestAllowed);

  const RouteGuardRule.authRequired() : this._(RouteGuardType.authRequired);

  const RouteGuardRule.currentPlanRequired()
    : this._(RouteGuardType.currentPlanRequired);

  const RouteGuardRule.financePermissionRequired()
    : this._(RouteGuardType.financePermissionRequired);

  const RouteGuardRule.taskPermissionRequired()
    : this._(RouteGuardType.taskPermissionRequired);

  const RouteGuardRule.guestPermissionRequired()
    : this._(RouteGuardType.guestPermissionRequired);

  const RouteGuardRule.providerOnly() : this._(RouteGuardType.providerOnly);

  const RouteGuardRule.userOnly() : this._(RouteGuardType.userOnly);

  const RouteGuardRule.featureFlagRequired({required String flagName})
    : this._(RouteGuardType.featureFlagRequired, flagName: flagName);

  final RouteGuardType type;
  final String? flagName;
}

class RouteGuardContext {
  const RouteGuardContext({
    this.isAuthenticated = false,
    this.hasCurrentPlan = false,
    this.canAccessFinance = false,
    this.canManageTasks = false,
    this.canManageGuests = false,
    this.userMode = RouteGuardUserMode.guest,
    this.featureFlags = const {},
  });

  final bool isAuthenticated;
  final bool hasCurrentPlan;
  final bool canAccessFinance;
  final bool canManageTasks;
  final bool canManageGuests;
  final RouteGuardUserMode userMode;
  final Map<String, bool> featureFlags;

  bool isFeatureEnabled(String flagName) {
    return featureFlags[flagName] ?? false;
  }
}
