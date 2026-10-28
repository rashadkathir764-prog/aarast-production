import '../models/aarast_notification.dart';

/// The screen a notice opens (B-19). The server writes the exact route of
/// every notice in one place (`backend/src/shared-kernel/routes/
/// notification-routes.ts`), and the notices written before moved to the
/// same routes by migration, so the phone opens the route as it is written;
/// [isSafeNotificationRouteTarget] keeps it to the app's own screens.
String? resolveNotificationRouteTarget(AarastNotification notification) {
  final text = notification.routeTarget?.trim();
  return text == null || text.isEmpty ? null : text;
}

final RegExp _safeRouteId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The portal tabs a link may open on.
const _providerPortalTabs = {'requests', 'calendar', 'profile'};

/// A path of exactly this shape (`:id` a bare route id), with no query.
bool _isBareIdPath(Uri uri, List<String> shape) {
  final segments = uri.pathSegments;
  if (uri.hasQuery || segments.length != shape.length) return false;
  for (var i = 0; i < shape.length; i++) {
    final part = shape[i];
    if (part == ':id') {
      if (!_safeRouteId.hasMatch(segments[i])) return false;
    } else if (segments[i] != part) {
      return false;
    }
  }
  return true;
}

/// The provider portal, on its home or on one of its tabs.
bool _isProviderPortalPath(Uri uri) {
  if (uri.path != '/provider/dashboard') return false;
  if (!uri.hasQuery) return true;
  final parameters = uri.queryParametersAll;
  final tabs = parameters['tab'];
  return parameters.length == 1 &&
      tabs != null &&
      tabs.length == 1 &&
      _providerPortalTabs.contains(tabs.single);
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

  return _isProviderPortalPath(uri) ||
      target == '/provider/apply' ||
      // B-16: a portfolio photo approved or refused opens p37.
      target == '/provider/gallery' ||
      _isBareIdPath(uri, const ['provider', 'requests', ':id']) ||
      _isBareIdPath(uri, const ['provider', 'reviews', ':id']) ||
      _isBareIdPath(uri, const ['quotes', ':id', 'conversation']) ||
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
