import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart'
    show AarastInlineSpinner, AarastScreenFrame;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
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
      return const _GateLoading();
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
    if (!controller.isRefreshing && controller.errorMessage != null) {
      return _MismatchedPlanContext(
        title: 'ما قدرنا نتأكد من الخطة',
        message: controller.errorMessage!,
      );
    }
    if (!controller.hasLoadedContexts) {
      return const _GateLoading();
    }
    // While the contexts are read again (each return to the app, each pull
    // to refresh) the page stays closed to the eye, as before, and is kept
    // alive under the spinner: drawing the spinner in its place tore the
    // page down with whatever was being typed in it (RA-MO-135). The answer
    // then decides: confirmed, the page is shown as it was left; withdrawn,
    // it is removed.
    if (isWeddingPlanRouteCompatible(
      controller,
      weddingPlanId,
      requiredAccess: requiredAccess,
    )) {
      return ContextGateHeldPage(
        covered: controller.isRefreshing,
        cover: const _GateLoading(),
        child: child,
      );
    }
    if (controller.isRefreshing) {
      return const _GateLoading();
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
      title: samePlan ? 'هذا القسم مو مفتوح لك' : 'هذي الخطة ما عادت لك',
      message: samePlan
          ? 'صلاحيتك في هذي الخطة ما تفتح هذا القسم.'
          : 'ما عادت ضمن خططك. ارجع للرئيسية واختر خطة ثانية.',
    );
  }
}

/// A page the gates keep alive while they cannot show it: [child] stays in
/// the tree with its state, unpainted, untouchable and silent to the screen
/// reader, under [cover], for as long as [covered]. Both gates always put
/// their page here, covered or not, so it is the same element either way.
class ContextGateHeldPage extends StatelessWidget {
  const ContextGateHeldPage({
    required this.covered,
    required this.cover,
    required this.child,
    super.key,
  });

  final bool covered;
  final Widget cover;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(
          offstage: covered,
          child: TickerMode(enabled: !covered, child: child),
        ),
        if (covered) cover,
      ],
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
      return const _GateLoading();
    }
    if (auth != null && auth.status == AuthStatus.unauthenticated) {
      return child;
    }

    final controller = context.watch<AccountContextController?>();
    if (controller == null) {
      appLogEvent(
        'ROUTE_BLOCKED',
        category: AppLogCategory.navigation,
        targetRoute: '/wedding-plans/:selected',
        reason: 'context_controller_missing',
        source: 'SelectedWeddingPlanContextGate',
      );
      return const _MismatchedPlanContext();
    }
    if (!controller.isRefreshing && controller.errorMessage != null) {
      return _MismatchedPlanContext(
        title: 'ما قدرنا نتأكد من الخطة',
        message: controller.errorMessage!,
      );
    }
    if (!controller.hasLoadedContexts) {
      return const _GateLoading();
    }
    // As above: the open page is kept alive, unseen, while the contexts
    // are read again.
    final selected = controller.selectedContext;
    if (selected != null &&
        accountContextAllowsPlanAccess(selected, requiredAccess)) {
      return ContextGateHeldPage(
        covered: controller.isRefreshing,
        cover: const _GateLoading(),
        child: child,
      );
    }
    if (controller.isRefreshing) {
      return const _GateLoading();
    }
    appLogEvent(
      'ROUTE_BLOCKED',
      category: AppLogCategory.navigation,
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
  appLogEvent(
    'ROUTE_BLOCKED',
    category: AppLogCategory.navigation,
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
    return _GatePage(
      child: JourneyListState(
        key: const ValueKey('wedding-plan-context-login'),
        phase: JourneyListPhase.empty,
        section: JourneySection.home,
        emptyIcon: LucideIcons.lock,
        emptyTitle: 'ادخل أول',
        emptyMessage: 'ادخل بحسابك عشان نفتح لك هذي الخطة.',
        emptyAction: 'تسجيل الدخول',
        onEmptyAction: () {
          final resume = AppRouter.weddingPlanDashboard(planId);
          context.go(
            Uri(
              path: AppRouter.login,
              queryParameters: {'resume': resume},
            ).toString(),
          );
        },
      ),
    );
  }
}

class _MismatchedPlanContext extends StatelessWidget {
  const _MismatchedPlanContext({
    this.title = 'هذي الخطة ما عادت لك',
    this.message = 'ما عادت ضمن خططك. ارجع للرئيسية واختر خطة ثانية.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _GatePage(
      child: JourneyListState(
        key: const ValueKey('wedding-plan-context-mismatch'),
        phase: JourneyListPhase.empty,
        section: JourneySection.home,
        emptyIcon: LucideIcons.shieldAlert,
        emptyTitle: title,
        emptyMessage: message,
      ),
    );
  }
}

/// The gate's own page: the canvas and the kit's padding.
class _GatePage extends StatelessWidget {
  const _GatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(padding: AarastV3Density.pageInsets, children: [child]),
    );
  }
}

/// While the plan is checked: the kit's spinner on the canvas.
class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Center(
        child: AarastInlineSpinner(
          key: ValueKey('wedding-plan-context-loading'),
          dimension: 28,
          color: AarastV3Color.primary,
        ),
      ),
    );
  }
}
