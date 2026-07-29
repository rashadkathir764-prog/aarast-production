import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_controller.dart';
import '../routing/app_router.dart';
import 'push_notifications_controller.dart';

class AarastPushLifecycleBridge extends StatefulWidget {
  const AarastPushLifecycleBridge({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<AarastPushLifecycleBridge> createState() =>
      _AarastPushLifecycleBridgeState();
}

class _AarastPushLifecycleBridgeState extends State<AarastPushLifecycleBridge> {
  String? _lastBoundUserId;
  bool _permissionScheduled = false;
  bool _navigationScheduled = false;

  @override
  Widget build(BuildContext context) {
    final authenticatedUserId = context
        .select<AuthController, ({AuthStatus status, String? userId})>(
          (auth) => (status: auth.status, userId: auth.user?.id),
        );
    final effectiveUserId =
        authenticatedUserId.status == AuthStatus.authenticated
        ? authenticatedUserId.userId
        : null;
    final pendingOpen = context.select<PushNotificationsController, bool>(
      (push) => push.hasPendingNotificationsOpen,
    );

    if (!_permissionScheduled) {
      _permissionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<PushNotificationsController>()
            .requestPermissionOnFirstOpen();
      });
    }

    if (_lastBoundUserId != effectiveUserId) {
      _lastBoundUserId = effectiveUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PushNotificationsController>().bindAuthenticatedUser(
          effectiveUserId,
        );
      });
    }

    if (pendingOpen && effectiveUserId != null && !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigationScheduled = false;
        if (!mounted) return;
        final push = context.read<PushNotificationsController>();
        if (push.claimNotificationsOpen()) {
          // A notification tap never selects a plan context. The inbox and
          // existing route guards remain authoritative for any target action.
          widget.router.go(AppRouter.notifications);
        }
      });
    }

    return widget.child;
  }
}
