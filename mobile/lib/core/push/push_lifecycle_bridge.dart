import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routing/app_router.dart';
import '../widgets/aarast_toast.dart';
import 'push_messaging_gateway.dart';
import 'push_notifications_controller.dart';
import 'push_permission_sheet.dart';

final RegExp _pushNotificationId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The inbox a push tap opens, naming the notice to open when the push
/// carried a well-formed id.
String _inboxLocation({required bool provider, String? notificationId}) {
  final inbox = provider
      ? AppRouter.providerNotifications
      : AppRouter.notifications;
  if (notificationId == null || !_pushNotificationId.hasMatch(notificationId)) {
    return inbox;
  }
  return Uri(
    path: inbox,
    queryParameters: {AppRouter.openNotificationParameter: notificationId},
  ).toString();
}

class AarastPushLifecycleBridge extends StatefulWidget {
  const AarastPushLifecycleBridge({
    required this.router,
    required this.authenticatedUserId,
    this.isProviderAccount,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final String? authenticatedUserId;

  /// D87: a provider's notifications live in his portal, not the account
  /// inbox the couple reads. Asked at the tap, so the root never rebuilds
  /// on a context change.
  final bool Function()? isProviderAccount;
  final Widget child;

  @override
  State<AarastPushLifecycleBridge> createState() =>
      _AarastPushLifecycleBridgeState();
}

class _AarastPushLifecycleBridgeState extends State<AarastPushLifecycleBridge>
    with WidgetsBindingObserver {
  String? _lastBoundUserId;
  bool _explanationScheduled = false;
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
            // The bridge sits above the navigator (app.dart's builder), so
            // its own context has no overlay: the toast needs the
            // navigator's own overlay.
            AarastToast.showNotification(
              context,
              title: notification.title,
              message: notification.message,
              overlay: widget
                  .router
                  .routerDelegate
                  .navigatorKey
                  .currentState
                  ?.overlay,
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

    // RA-MO-360: the phone's question is not asked with the account, before
    // the person has a reason to say yes. A reminder set or the first plan
    // made says what the alerts are for, and only «اسمح» asks the phone.
    final explanationPending = context
        .select<PushNotificationsController, bool>(
          (push) => push.hasPendingPermissionExplanation,
        );
    if (explanationPending &&
        effectiveUserId != null &&
        !_explanationScheduled) {
      _explanationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _explainPermission());
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
        final tap = push.claimNotificationsOpen();
        if (tap != null) {
          // A notification tap never selects a plan context. The inbox opens
          // the notice the push named through its own route guards and marks
          // it read; with no notice named, or none the guards let through,
          // it stays on the inbox.
          widget.router.go(
            _inboxLocation(
              provider: widget.isProviderAccount?.call() ?? false,
              notificationId: tap.notificationId,
            ),
          );
        }
      });
    }

    return widget.child;
  }

  Future<void> _explainPermission() async {
    _explanationScheduled = false;
    if (!mounted) return;
    final push = context.read<PushNotificationsController>();
    // The bridge sits above the navigator: the sheet is the navigator's.
    final navigator = widget.router.routerDelegate.navigatorKey.currentContext;
    if (navigator == null || !push.claimPermissionExplanation()) return;
    if (await showPushPermissionSheet(navigator)) {
      await push.requestPermissionOnFirstOpen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_foregroundSubscription?.cancel());
    super.dispose();
  }
}
