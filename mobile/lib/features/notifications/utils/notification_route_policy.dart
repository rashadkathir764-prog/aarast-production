import '../models/aarast_notification.dart';

String? resolveNotificationRouteTarget(AarastNotification notification) {
  final type = notification.type.toUpperCase();
  if (type.startsWith('PAYMENT_SCHEDULE_')) {
    final data = notification.data;
    final planId = _nonEmpty(
      notification.weddingPlanId ?? data?['weddingPlanId'],
    );
    final costId = _nonEmpty(data?['weddingCostId']);
    final scheduleId =
        _nonEmpty(
          notification.entityType == 'payment_schedule'
              ? notification.entityId
              : null,
        ) ??
        _nonEmpty(data?['paymentScheduleId']);
    if (planId != null && costId != null && scheduleId != null) {
      return Uri(
        path:
            '/wedding-plans/$planId/money/costs/$costId/schedules/$scheduleId',
      ).toString();
    }
  }

  return _nonEmpty(notification.routeTarget);
}

bool isSafeNotificationRouteTarget(String target) {
  if (!target.startsWith('/') || target.contains('://')) return false;
  return target == '/providers' ||
      target.startsWith('/providers/') ||
      target.startsWith('/conversations/') ||
      target.startsWith('/invites/') ||
      target.startsWith('/wedding-plans/');
}

bool isPlanShellNotificationRouteTarget(String target) {
  final uri = Uri.tryParse(target);
  final segments = uri?.pathSegments;
  if (segments == null ||
      segments.length < 3 ||
      segments[0] != 'wedding-plans') {
    return false;
  }

  final area = segments[2];
  if (segments.length == 3) {
    return area == 'dashboard' ||
        area == 'money' ||
        area == 'tasks' ||
        area == 'guests' ||
        area == 'providers';
  }
  return area == 'guests' && segments.length == 4 && segments[3] == 'add';
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
