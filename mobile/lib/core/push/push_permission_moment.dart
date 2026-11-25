import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'push_notifications_controller.dart';

/// RA-MO-360: a moment that gives the phone's notification question a
/// reason, said from where it happens: a reminder just set, the first plan
/// just made, a provider's application sent, a plan joined. The app then
/// says in one line what the alerts are for ([reason]), and only «اسمح»
/// asks the phone ([PushNotificationsController.permissionMomentReached]
/// decides whether there is anything to ask).
extension PushPermissionMoment on BuildContext {
  void reachPushPermissionMoment({
    PushPermissionReason reason = PushPermissionReason.plan,
  }) {
    final PushNotificationsController push;
    try {
      push = read<PushNotificationsController>();
    } on ProviderNotFoundException {
      // Isolated screens may omit the production push controller.
      return;
    }
    unawaited(push.permissionMomentReached(reason: reason));
  }
}
