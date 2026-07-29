import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/context_lifecycle_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';

enum WeddingPlanRouteAccess {
  viewPlan,
  ownerDashboard,
  viewMoney,
  manageMoney,
  manageTasks,
  manageGuests,
  manageProviders,
  inviteMembers,
  unknown,
}

class WeddingPlanContextGate extends StatelessWidget {
  const WeddingPlanContextGate({
    required this.weddingPlanId,
    required this.child,
    this.requiredAccess = WeddingPlanRouteAccess.viewPlan,
    super.key,
  });

  final String weddingPlanId;
  final Widget child;
  final WeddingPlanRouteAccess requiredAccess;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController?>();
    final auth = context.watch<AuthController?>();
    if (auth != null && auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth != null && auth.status == AuthStatus.unauthenticated) {
      if (AuthActionGuard.isLocalGuestPlanId(weddingPlanId)) {
        return child;
      }
      return _LoginRequiredPlanContext(planId: weddingPlanId);
    }
    if (controller == null) {
      _logBlockedRoute(null, weddingPlanId, 'context_controller_missing');
      return const _MismatchedPlanContext();
    }
    if (!controller.hasLoadedContexts &&
        !controller.isRefreshing &&
        controller.errorMessage != null) {
      return _MismatchedPlanContext(
        title: 'تعذر التحقق من مساحة الخطة',
        message: controller.errorMessage!,
      );
    }
    if (!controller.hasLoadedContexts || controller.isRefreshing) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (isWeddingPlanRouteCompatible(
      controller,
      weddingPlanId,
      requiredAccess: requiredAccess,
    )) {
      return child;
    }

    final selected = controller.selectedContext;
    final samePlan =
        selected?.isPlan == true && selected?.weddingPlanId == weddingPlanId;
    _logBlockedRoute(
      selected?.contextKey,
      weddingPlanId,
      samePlan
          ? 'selected_context_permission_denied'
          : 'selected_context_mismatch',
    );
    return _MismatchedPlanContext(
      title: samePlan ? 'هذا القسم غير متاح لصلاحيتك' : 'مساحة الخطة غير متاحة',
      message: samePlan
          ? 'سياق المساهم الحالي لا يمنح صلاحية فتح هذا القسم.'
          : 'لم تعد هذه الخطة ضمن مساحات حسابك المتاحة. ارجع للرئيسية واختر مساحة أخرى.',
    );
  }
}

bool isWeddingPlanRouteCompatible(
  AccountContextController controller,
  String routeWeddingPlanId, {
  WeddingPlanRouteAccess requiredAccess = WeddingPlanRouteAccess.viewPlan,
}) {
  final selected = controller.selectedContext;
  return selected?.isPlan == true &&
      selected?.weddingPlanId == routeWeddingPlanId &&
      selected != null &&
      accountContextAllowsPlanAccess(selected, requiredAccess);
}

bool accountContextAllowsPlanAccess(
  AccountContext selected,
  WeddingPlanRouteAccess requiredAccess,
) {
  if (!selected.isAvailable ||
      !selected.isPlan ||
      !selected.permissions.canViewPlan) {
    return false;
  }
  final permissions = selected.permissions;
  return switch (requiredAccess) {
    WeddingPlanRouteAccess.viewPlan => true,
    WeddingPlanRouteAccess.ownerDashboard =>
      selected.role == AccountContextRole.owner,
    WeddingPlanRouteAccess.viewMoney => permissions.canViewMoney,
    WeddingPlanRouteAccess.manageMoney => permissions.canManageMoney,
    WeddingPlanRouteAccess.manageTasks => permissions.canManageTasks,
    WeddingPlanRouteAccess.manageGuests => permissions.canManageGuests,
    WeddingPlanRouteAccess.manageProviders => permissions.canManageProviders,
    WeddingPlanRouteAccess.inviteMembers => permissions.canInviteMembers,
    WeddingPlanRouteAccess.unknown => false,
  };
}

class SelectedWeddingPlanContextGate extends StatelessWidget {
  const SelectedWeddingPlanContextGate({
    required this.child,
    this.requiredAccess = WeddingPlanRouteAccess.viewPlan,
    super.key,
  });

  final Widget child;
  final WeddingPlanRouteAccess requiredAccess;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController?>();
    if (auth != null && auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth != null && auth.status == AuthStatus.unauthenticated) {
      return child;
    }

    final controller = context.watch<AccountContextController?>();
    if (controller == null) {
      ContextLifecycleLogger.event(
        'ROUTE_BLOCKED',
        targetRoute: '/wedding-plans/:selected',
        reason: 'context_controller_missing',
        source: 'SelectedWeddingPlanContextGate',
      );
      return const _MismatchedPlanContext();
    }
    if (!controller.hasLoadedContexts &&
        !controller.isRefreshing &&
        controller.errorMessage != null) {
      return _MismatchedPlanContext(
        title: 'تعذر التحقق من مساحة الخطة',
        message: controller.errorMessage!,
      );
    }
    if (!controller.hasLoadedContexts || controller.isRefreshing) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    final selected = controller.selectedContext;
    if (selected != null &&
        accountContextAllowsPlanAccess(selected, requiredAccess)) {
      return child;
    }
    ContextLifecycleLogger.event(
      'ROUTE_BLOCKED',
      activeContextKey: selected?.contextKey,
      targetRoute: '/wedding-plans/:selected',
      reason: selected?.isPlan == true
          ? 'selected_context_permission_denied'
          : 'selected_context_is_not_plan',
      source: 'SelectedWeddingPlanContextGate',
    );
    return const _MismatchedPlanContext();
  }
}

void _logBlockedRoute(String? contextKey, String weddingPlanId, String reason) {
  ContextLifecycleLogger.event(
    'ROUTE_BLOCKED',
    activeContextKey: contextKey,
    targetRoute: '/wedding-plans/$weddingPlanId',
    reason: reason,
    source: 'WeddingPlanContextGate',
  );
}

class _LoginRequiredPlanContext extends StatelessWidget {
  const _LoginRequiredPlanContext({required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    return AarastScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AarastEmptyState(
                key: const ValueKey('wedding-plan-context-login'),
                icon: LucideIcons.lock,
                title: 'تسجيل الدخول مطلوب',
                message:
                    'سجّل الدخول للتحقق من مساحة خطة الزفاف قبل فتح هذا المسار.',
                action: AarastButton(
                  label: 'تسجيل الدخول',
                  icon: LucideIcons.logIn,
                  onPressed: () {
                    final resume = AppRouter.weddingPlanDashboard(planId);
                    context.go(
                      Uri(
                        path: AppRouter.login,
                        queryParameters: {'resume': resume},
                      ).toString(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MismatchedPlanContext extends StatelessWidget {
  const _MismatchedPlanContext({
    this.title = 'مساحة الخطة غير متاحة',
    this.message =
        'لم تعد هذه الخطة ضمن مساحات حسابك المتاحة. ارجع للرئيسية واختر مساحة أخرى.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AarastEmptyState(
                key: const ValueKey('wedding-plan-context-mismatch'),
                icon: LucideIcons.shieldAlert,
                title: title,
                message: message,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
