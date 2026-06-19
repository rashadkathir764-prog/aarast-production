enum RouteGuardOutcome { allow, redirect, blocked }

enum RouteGuardReason {
  allowed,
  guestAllowed,
  authRequired,
  currentPlanRequired,
  financePermissionRequired,
  taskPermissionRequired,
  guestPermissionRequired,
  providerOnly,
  userOnly,
  featureDisabled,
}

extension RouteGuardReasonMessages on RouteGuardReason {
  String get technicalCode {
    return switch (this) {
      RouteGuardReason.allowed => 'allowed',
      RouteGuardReason.guestAllowed => 'guest_allowed',
      RouteGuardReason.authRequired => 'auth_required',
      RouteGuardReason.currentPlanRequired => 'current_plan_required',
      RouteGuardReason.financePermissionRequired =>
        'finance_permission_required',
      RouteGuardReason.taskPermissionRequired => 'task_permission_required',
      RouteGuardReason.guestPermissionRequired => 'guest_permission_required',
      RouteGuardReason.providerOnly => 'provider_only',
      RouteGuardReason.userOnly => 'user_only',
      RouteGuardReason.featureDisabled => 'feature_disabled',
    };
  }

  String get arabicMessage {
    return switch (this) {
      RouteGuardReason.allowed => 'مسموح',
      RouteGuardReason.guestAllowed => 'مسموح للضيف',
      RouteGuardReason.authRequired => 'تسجيل الدخول مطلوب',
      RouteGuardReason.currentPlanRequired => 'خطة زفاف حالية مطلوبة',
      RouteGuardReason.financePermissionRequired => 'صلاحية المال مطلوبة',
      RouteGuardReason.taskPermissionRequired => 'صلاحية المهام مطلوبة',
      RouteGuardReason.guestPermissionRequired => 'صلاحية الضيوف مطلوبة',
      RouteGuardReason.providerOnly => 'متاح للمورد فقط',
      RouteGuardReason.userOnly => 'متاح لمستخدم الزفاف فقط',
      RouteGuardReason.featureDisabled => 'الميزة غير مفعلة',
    };
  }
}

class RouteGuardResult {
  const RouteGuardResult._({
    required this.outcome,
    required this.reason,
    this.targetLocation,
  });

  const RouteGuardResult.allow()
    : this._(
        outcome: RouteGuardOutcome.allow,
        reason: RouteGuardReason.allowed,
      );

  const RouteGuardResult.redirect({
    required String targetLocation,
    required RouteGuardReason reason,
  }) : this._(
         outcome: RouteGuardOutcome.redirect,
         reason: reason,
         targetLocation: targetLocation,
       );

  const RouteGuardResult.blocked({required RouteGuardReason reason})
    : this._(outcome: RouteGuardOutcome.blocked, reason: reason);

  final RouteGuardOutcome outcome;
  final RouteGuardReason reason;
  final String? targetLocation;
}
