import 'package:flutter/foundation.dart';

/// Opt-in lifecycle logging for account sessions, contexts, and routes.
///
/// Access/refresh tokens, invite tokens, query values, and route identifiers
/// are never emitted. Account/context identifiers are logged only because
/// they are required to correlate lifecycle events during local diagnosis.
///
/// Release diagnostics are disabled unless the APK is built with
/// `--dart-define=AARAST_CONTEXT_DIAGNOSTICS=true`.
class ContextLifecycleLogger {
  const ContextLifecycleLogger._();

  static const bool _releaseDiagnosticsEnabled = bool.fromEnvironment(
    'AARAST_CONTEXT_DIAGNOSTICS',
    defaultValue: false,
  );

  static void event(
    String name, {
    String? userId,
    String? activeContextKey,
    String? activeContextType,
    String? weddingPlanId,
    String? shellType,
    String? selectedTab,
    String? screen,
    int? httpStatus,
    String? currentRoute,
    String? targetRoute,
    String? reason,
    String? source,
    String? fromContextKey,
    String? toContextKey,
  }) {
    if (!kDebugMode && !_releaseDiagnosticsEnabled) return;
    final contextKey = activeContextKey ?? toContextKey ?? fromContextKey;
    debugPrint(
      '[AarastLifecycle] $name'
      ' userId=${_safeIdentifier(userId)}'
      ' activeContextId=${_contextId(contextKey)}'
      ' activeContextType=${activeContextType ?? _contextType(contextKey)}'
      ' weddingPlanId=${_safeIdentifier(weddingPlanId)}'
      ' shellType=${_safeLabel(shellType)}'
      ' selectedTab=${_safeLabel(selectedTab)}'
      ' screen=${_safeLabel(screen)}'
      ' currentRoute=${_safeRoute(currentRoute)}'
      ' targetRoute=${_safeRoute(targetRoute)}'
      ' httpStatus=${httpStatus ?? 0}'
      ' reason=${_safeLabel(reason)}'
      ' source=${_safeLabel(source)}'
      ' fromContextId=${_contextId(fromContextKey)}'
      ' toContextId=${_contextId(toContextKey)}',
    );
  }

  static String _contextId(String? contextKey) {
    if (contextKey == null || contextKey.isEmpty) return 'none';
    final parts = contextKey.split(':');
    if (parts.length == 2 && parts.first == 'provider') {
      return _safeIdentifier(parts[1]);
    }
    if (parts.length < 3 || parts.first != 'plan') return 'invalid';
    return _safeIdentifier(parts.sublist(1, parts.length - 1).join(':'));
  }

  static String _contextType(String? contextKey) {
    if (contextKey == null || contextKey.isEmpty) return 'none';
    final parts = contextKey.split(':');
    if (parts.length == 2 && parts.first == 'provider') return 'provider';
    return parts.length < 2 ? 'invalid' : _safeLabel(parts.last);
  }

  static String _safeIdentifier(String? value) {
    if (value == null || value.isEmpty) return 'none';
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
  }

  static String _safeLabel(String? value) {
    if (value == null || value.isEmpty) return 'none';
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
  }

  static String _safeRoute(String? route) {
    if (route == null || route.isEmpty) return 'none';
    final uri = Uri.tryParse(route);
    if (uri == null) return 'invalid';
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/';

    if (segments.first == 'invites') return '/invites/:redacted';
    if (segments.first == 'api') {
      if (segments.length < 3) return '/api';
      final resource = segments[2];
      final safeSegments = <String>['api', segments[1], resource];
      if (resource == 'invites' && segments.length > 3) {
        safeSegments.add(':redacted');
        if (segments.length > 4) safeSegments.add(segments[4]);
      } else if (resource == 'wedding-plans' && segments.length > 3) {
        safeSegments.add(':plan');
        if (segments.length > 4) safeSegments.add(segments[4]);
      } else if (segments.length > 3) {
        safeSegments.add(segments[3]);
      }
      return '/${safeSegments.join('/')}';
    }

    final safeSegments = <String>[segments.first];
    if (segments.first == 'wedding-plans' && segments.length > 1) {
      safeSegments.add(':plan');
      if (segments.length > 2) safeSegments.add(segments[2]);
    } else if (segments.first == 'providers' && segments.length > 1) {
      safeSegments.add(':provider');
      if (segments.length > 2) safeSegments.add(segments[2]);
    } else if (segments.length > 1) {
      safeSegments.add(segments[1]);
    }
    return '/${safeSegments.join('/')}';
  }
}
