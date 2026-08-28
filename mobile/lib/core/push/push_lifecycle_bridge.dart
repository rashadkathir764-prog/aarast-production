import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routing/app_router.dart';
import '../widgets/aarast_toast.dart';
import 'push_messaging_gateway.dart';
import 'push_notifications_controller.dart';

class AarastPushLifecycleBridge extends StatefulWidget {
  const AarastPushLifecycleBridge({
    required this.router,
    required this.authenticatedUserId,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final String? authenticatedUserId;
  final Widget child;

  @override
  State<AarastPushLifecycleBridge> createState() =>
      _AarastPushLifecycleBridgeState();
}

class _AarastPushLifecycleBridgeState extends State<AarastPushLifecycleBridge>
    with WidgetsBindingObserver {
  String? _lastBoundUserId;
  bool _permissionScheduled = false;
  bool _navigationScheduled = false;
  StreamSubscription<PushForegroundNotification>? _foregroundSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_foregroundSubscription != null) return;
    try {
      _foregroundSubscription = context
          .read<PushNotificationsController>()
          .foregroundNotifications
          .listen((notification) {
            if (!mounted) return;
            AarastToast.showNotification(
              context,
              title: notification.title,
              message: notification.message,
            );
          });
    } on ProviderNotFoundException {
      // Isolated shell tests may omit the production push controller.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(
      context.read<PushNotificationsController>().refreshCurrentRegistration(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUserId = widget.authenticatedUserId;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_foregroundSubscription?.cancel());
    super.dispose();
  }
}
