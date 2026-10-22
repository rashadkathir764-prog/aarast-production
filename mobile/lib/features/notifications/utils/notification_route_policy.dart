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

  final originalTarget = _nonEmpty(notification.routeTarget);
  if (notification.entityType == 'quote_request' &&
      _isLegacyRequesterQuoteTarget(originalTarget)) {
    final data = notification.data;
    final quoteId = _nonEmpty(notification.entityId ?? data?['quoteRequestId']);
    if (quoteId != null && _safeRouteId.hasMatch(quoteId)) {
      final planId = _nonEmpty(
        notification.weddingPlanId ?? data?['weddingPlanId'],
      );
      if (planId != null && _safeRouteId.hasMatch(planId)) {
        return Uri(
          path: '/wedding-plans/$planId/providers',
          queryParameters: {'quoteId': quoteId},
        ).toString();
      }
      return Uri(
        path: '/providers',
        queryParameters: {'quoteId': quoteId},
      ).toString();
    }
  }

  return originalTarget;
}

final RegExp _safeRouteId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

bool _isLegacyRequesterQuoteTarget(String? target) {
  if (target == null) return false;
  final uri = Uri.tryParse(target);
  if (uri == null) return false;
  return uri.path.startsWith('/providers/') ||
      uri.path.endsWith('/plan-center');
}

bool isSafeNotificationRouteTarget(String target) {
  if (!target.startsWith('/') || target.contains('://')) return false;
  final uri = Uri.tryParse(target);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.fragment.isNotEmpty) {
    return false;
  }

  if (uri.path == '/providers') {
    if (!uri.hasQuery) return true;
    final parameters = uri.queryParametersAll;
    final quoteIds = parameters['quoteId'];
    return parameters.length == 1 &&
        quoteIds != null &&
        quoteIds.length == 1 &&
        _safeRouteId.hasMatch(quoteIds.single);
  }

  return
  // بوابة المزود: وجهة تنبيهات "طلب جديد" و"تم قبول عرضك" للمزود.
  target == '/provider/dashboard' ||
      uri.path.startsWith('/providers/') ||
      uri.path.startsWith('/conversations/') ||
      uri.path.startsWith('/invites/') ||
      uri.path.startsWith('/wedding-plans/');
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
