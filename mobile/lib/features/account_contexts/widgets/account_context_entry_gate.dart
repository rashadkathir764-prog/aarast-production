import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../shell/shell_api.dart' show MainShell;
import '../../welcome_gateway/welcome_gateway_api.dart' show SmartWelcomeScreen;
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';
import '../screens/account_context_selection_screen.dart';
import 'wedding_plan_context_gate.dart';

class AccountContextEntryGate extends StatelessWidget {
  const AccountContextEntryGate({this.resumeLocation, super.key});

  final String? resumeLocation;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();

    switch (resolveAccountContextEntry(controller)) {
      case AccountContextEntryState.loading:
        return const AarastScaffold(child: AarastScreenLoading());
      case AccountContextEntryState.error:
        return AarastScaffold(
          child: Align(
            alignment: Alignment.topCenter,
            child: AarastErrorState(
              title: 'ما قدرنا نفتح حسابك',
              message: controller.errorMessage!,
              onRetry: controller.refresh,
            ),
          ),
        );
      case AccountContextEntryState.choosePath:
        return const AccountContextSelectionScreen();
      case AccountContextEntryState.noPaths:
        final resume = _safeResumeForNoContext(resumeLocation);
        if (resume != null) return _ReplaceRoute(location: resume);
        return const SmartWelcomeScreen();
      case AccountContextEntryState.planDashboard:
      case AccountContextEntryState.providerDashboard:
        break;
    }

    final selected = controller.selectedContext!;

    final resume = compatibleAccountContextResume(selected, resumeLocation);
    if (resume != null) return _ReplaceRoute(location: resume);
    if (selected.isProvider) {
      return const _ReplaceRoute(location: AppRouter.providerDashboard);
    }
    return ContextGateHeldPage(
      covered: false,
      cover: const AarastScaffold(child: AarastScreenLoading()),
      child: MainShell(
        key: ValueKey('account-context-shell-${selected.contextKey}'),
      ),
    );
  }
}

enum AccountContextEntryState {
  loading,
  error,
  noPaths,
  choosePath,
  planDashboard,
  providerDashboard,
}

AccountContextEntryState resolveAccountContextEntry(
  AccountContextController controller,
) {
  if (controller.isRefreshing) {
    // D112 (Q-17): a plan already open stays open while its contexts are
    // read again, on the right last confirmed; it closes only when the
    // server answers that the right was withdrawn. The loading page in its
    // place rebuilt the shell on every return to the app (back on the first
    // tab, what was open in it gone: RA-MO-135), and without a connection
    // stayed for the whole timeout. A provider's portal still waits.
    final open = controller.selectedContext;
    if (controller.hasLoadedContexts &&
        open != null &&
        open.isAvailable &&
        open.isPlan) {
      return AccountContextEntryState.planDashboard;
    }
    return AccountContextEntryState.loading;
  }
  if (controller.errorMessage != null) return AccountContextEntryState.error;
  if (!controller.hasLoadedContexts) return AccountContextEntryState.loading;

  final selected = controller.selectedContext;
  if (selected != null && selected.isAvailable) {
    return selected.isProvider
        ? AccountContextEntryState.providerDashboard
        : AccountContextEntryState.planDashboard;
  }
  if (controller.needsSelection) {
    return AccountContextEntryState.choosePath;
  }
  return controller.availableContexts.isEmpty
      ? AccountContextEntryState.noPaths
      : AccountContextEntryState.loading;
}

class _ReplaceRoute extends StatefulWidget {
  const _ReplaceRoute({required this.location});

  final String location;

  @override
  State<_ReplaceRoute> createState() => _ReplaceRouteState();
}

class _ReplaceRouteState extends State<_ReplaceRoute> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final routerState = GoRouterState.of(context);
      appLogEvent(
        'NAVIGATION_REQUEST',
        category: AppLogCategory.navigation,
        currentRoute: routerState.uri.toString(),
        targetRoute: widget.location,
        reason: 'account_context_gate',
        source: 'AccountContextEntryGate',
      );
      context.go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AarastScaffold(child: AarastScreenLoading());
  }
}

String? _safeResumeForNoContext(String? location) {
  final path = _safePath(location);
  if (path == null) return null;
  if (path.startsWith('/invites/') || path == AppRouter.inviteAccess) {
    return location;
  }
  if (path == AppRouter.providerApply) return location;
  return null;
}

@visibleForTesting
String? compatibleAccountContextResume(
  AccountContext selected,
  String? location,
) {
  final path = _safePath(location);
  if (path == null || path == AppRouter.home) return null;

  const accountCommonPaths = {
    AppRouter.notifications,
    AppRouter.inviteAccess,
    AppRouter.more,
    AppRouter.settings,
    AppRouter.support,
  };
  if (accountCommonPaths.contains(path) || path.startsWith('/invites/')) {
    return location;
  }

  if (selected.isProvider) {
    return path.startsWith('/provider/') ||
            path.startsWith('/conversations/') ||
            path.startsWith('/quotes/')
        ? location
        : null;
  }

  if (path == AppRouter.providerMarketplace ||
      path == AppRouter.favoriteProviders ||
      path == AppRouter.conversations ||
      path.startsWith('/providers/') ||
      path.startsWith('/conversations/') ||
      path.startsWith('/quotes/')) {
    return selected.permissions.canManageProviders ? location : null;
  }

  final planId = selected.weddingPlanId;
  if (planId == null) return null;
  final encodedPlanId = Uri.encodeComponent(planId);
  if (!path.startsWith('/wedding-plans/$encodedPlanId/')) return null;
  // A participant's home is the entry's own shell: a resume to the plan's
  // home adds nothing to it, so none is made (as before RA-MO-96 opened
  // that route to them).
  if (selected.role == AccountContextRole.contributor &&
      path == AppRouter.weddingPlanDashboard(planId)) {
    return null;
  }
  final requiredAccess = weddingPlanRouteAccessForPath(path);
  return accountContextAllowsPlanAccess(selected, requiredAccess)
      ? location
      : null;
}

String? _safePath(String? location) {
  if (location == null ||
      location.trim().isEmpty ||
      !location.startsWith('/') ||
      location.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(location);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path == AppRouter.login ||
      uri.path == AppRouter.register ||
      uri.path == AppRouter.otp ||
      uri.path == AppRouter.resetPassword ||
      uri.path == AppRouter.welcome ||
      uri.path == AppRouter.onboarding) {
    return null;
  }
  return uri.path;
}
