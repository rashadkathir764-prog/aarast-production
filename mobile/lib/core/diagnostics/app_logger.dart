import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum AppLogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal;

  String get wireName => name;
}

enum AppLogCategory {
  auth,
  session,
  context,
  navigation,
  api,
  cache,
  database,
  state,
  lifecycle,
  provider,
  groom,
  contributor,
  push,
  chat,
  error;

  String get wireName => name;
}

final class AppLogEvent {
  AppLogEvent({
    required DateTime timestamp,
    required this.level,
    required this.category,
    required this.name,
    Map<String, Object?> attributes = const {},
    this.error,
    this.stackTrace,
  }) : timestamp = timestamp.toUtc(),
       attributes = Map.unmodifiable(attributes);

  final DateTime timestamp;
  final AppLogLevel level;
  final AppLogCategory category;
  final String name;
  final Map<String, Object?> attributes;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.wireName,
      'category': category.wireName,
      'name': name,
      if (attributes.isNotEmpty) 'attributes': attributes,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
  }
}

abstract interface class AppLogSink {
  void add(AppLogEvent event);
}

final class LogRedactor {
  LogRedactor({required String installationSalt})
    : _installationSalt = installationSalt {
    if (installationSalt.trim().isEmpty) {
      throw ArgumentError.value(
        installationSalt,
        'installationSalt',
        'must not be empty',
      );
    }
  }

  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _secretAssignmentPattern = RegExp(
    r'\b(?:access[_-]?token|refresh[_-]?token|token|password|passwd|secret|authorization|cookie|phone|mobile)'
    r'\s*[:=]\s*[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _jwtPattern = RegExp(
    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
  );
  static final RegExp _uuidPattern = RegExp(
    r'\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<![A-Za-z0-9])\+?[0-9\u0660-\u0669\u06F0-\u06F9]'
    r'[0-9\u0660-\u0669\u06F0-\u06F9 ()-]{6,}'
    r'[0-9\u0660-\u0669\u06F0-\u06F9](?![A-Za-z0-9])',
  );
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _embeddedUrlQueryPattern = RegExp(
    r'((?:https?://|/)[^\s?]+)\?[^\s]+',
    caseSensitive: false,
  );

  static const Set<String> _correlationIdentifierKeys = {
    'requestid',
    'clientrequestid',
    'backendrequestid',
    'correlationid',
    'xrequestid',
    'xclientrequestid',
  };

  static const List<String> _sensitiveKeyFragments = [
    'token',
    'password',
    'passwd',
    'secret',
    'authorization',
    'cookie',
    'phone',
    'mobile',
    'email',
    'contact',
    'credential',
    'body',
    'payload',
    'header',
    'query',
  ];

  final String _installationSalt;

  Map<String, Object?> redactAttributes(Map<String, Object?> attributes) {
    return _redactMap(attributes);
  }

  AppLogEvent redactEvent(AppLogEvent event) {
    return AppLogEvent(
      timestamp: event.timestamp,
      level: event.level,
      category: event.category,
      name: _sanitizeText(event.name),
      attributes: redactAttributes(event.attributes),
      error: event.error == null ? null : _sanitizeText(event.error!),
      stackTrace: event.stackTrace == null
          ? null
          : _sanitizeText(event.stackTrace!),
    );
  }

  String hashIdentifier(Object identifier) {
    final digest = Hmac(
      sha256,
      utf8.encode(_installationSalt),
    ).convert(utf8.encode(identifier.toString()));
    return digest.toString();
  }

  String? sanitizeRouteTemplate(String? route) {
    if (route == null || route.trim().isEmpty) return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return 'invalid';
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/';

    const dynamicResourceLabels = <String, String>{
      'invites': 'invite',
      'wedding-plans': 'plan',
      'providers': 'provider',
      'tasks': 'task',
      'members': 'member',
      'quotes': 'quote',
      'conversations': 'conversation',
      'requests': 'request',
      'installments': 'installment',
    };
    const staticResourceChildren = <String>{
      'active',
      'current',
      'me',
      'contexts',
      'validate',
      'refresh',
      'register',
      'login',
      'logout',
      'request-otp',
      'verify-otp',
      'dashboard-summary',
      'notifications',
      'sharing',
      'timeline',
      'create',
      'edit',
    };

    final safeSegments = <String>[];
    for (var index = 0; index < segments.length; index += 1) {
      final segment = segments[index];
      final previous = index == 0 ? null : segments[index - 1];
      final dynamicLabel = previous == null
          ? null
          : dynamicResourceLabels[previous];
      if (dynamicLabel != null && !staticResourceChildren.contains(segment)) {
        safeSegments.add(':$dynamicLabel');
      } else if (_looksLikeIdentifierSegment(segment)) {
        safeSegments.add(':id');
      } else {
        safeSegments.add(_sanitizeText(segment));
      }
    }
    return '/${safeSegments.join('/')}';
  }

  Map<String, Object?> _redactMap(Map<Object?, Object?> input) {
    final result = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key.toString();
      final normalizedKey = _normalizeKey(key);
      if (_isSensitiveKey(normalizedKey)) continue;

      if (_isIdentifierKey(key, normalizedKey)) {
        if (entry.value != null) {
          result[_hashedKey(key)] = hashIdentifier(entry.value!);
        }
        continue;
      }

      final value = _redactValue(entry.value);
      if (value != null) result[key] = value;
    }
    return result;
  }

  Object? _redactValue(Object? value) {
    return switch (value) {
      null => null,
      String text => _sanitizeText(text),
      num number => number,
      bool boolean => boolean,
      Map<Object?, Object?> map => _redactMap(map),
      Iterable<Object?> values => List<Object?>.unmodifiable(
        values.map(_redactValue).where((value) => value != null),
      ),
      _ => _sanitizeText(value.toString()),
    };
  }

  bool _isSensitiveKey(String normalizedKey) {
    return _sensitiveKeyFragments.any(normalizedKey.contains);
  }

  bool _isIdentifierKey(String key, String normalizedKey) {
    if (_correlationIdentifierKeys.contains(normalizedKey)) return false;
    if (normalizedKey.endsWith('hash')) return false;
    if (normalizedKey == 'fid') return true;
    return RegExp(r'(?:Id|ID|Key)$').hasMatch(key) ||
        RegExp(r'(?:_id|_key)$', caseSensitive: false).hasMatch(key);
  }

  String _hashedKey(String key) {
    if (key.endsWith('_id')) {
      return '${key.substring(0, key.length - 3)}IdHash';
    }
    if (key.endsWith('_key')) {
      return '${key.substring(0, key.length - 4)}KeyHash';
    }
    return '$key${key.endsWith('Hash') ? '' : 'Hash'}';
  }

  String _normalizeKey(String key) {
    return key.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  }

  String _sanitizeText(String value) {
    var safe = value;
    if (_looksLikeRouteOrUrl(safe)) {
      final queryStart = safe.indexOf('?');
      if (queryStart >= 0) safe = safe.substring(0, queryStart);
    }
    safe = safe.replaceAllMapped(
      _embeddedUrlQueryPattern,
      (match) => match.group(1)!,
    );
    safe = safe.replaceAll(_bearerPattern, '[redacted]');
    safe = safe.replaceAll(_jwtPattern, '[redacted]');
    safe = safe.replaceAll(_secretAssignmentPattern, '[redacted]');
    safe = safe.replaceAll(_uuidPattern, '[id]');
    safe = safe.replaceAll(_phonePattern, '[redacted]');
    safe = safe.replaceAll(_emailPattern, '[redacted]');
    return safe;
  }

  bool _looksLikeRouteOrUrl(String value) {
    return value.startsWith('/') ||
        value.startsWith('http://') ||
        value.startsWith('https://');
  }

  bool _looksLikeIdentifierSegment(String segment) {
    return _uuidPattern.hasMatch(segment) ||
        RegExp(r'^\d+$').hasMatch(segment) ||
        RegExp(r'^[A-Za-z0-9_-]{24,}$').hasMatch(segment);
  }
}

final class AppLogger {
  AppLogger({
    required LogRedactor redactor,
    required Iterable<AppLogSink> sinks,
    DateTime Function()? clock,
  }) : _redactor = redactor,
       _sinks = List.unmodifiable(sinks),
       _clock = clock ?? DateTime.now;

  final LogRedactor _redactor;
  final List<AppLogSink> _sinks;
  final DateTime Function() _clock;
  String? _sessionCorrelationId;

  static AppLogger? _global;

  static AppLogger? get global => _global;

  static void installGlobal(AppLogger logger) {
    _global = logger;
  }

  @visibleForTesting
  static void clearGlobal() {
    _global = null;
  }

  String? sanitizeRouteTemplate(String? route) {
    return _redactor.sanitizeRouteTemplate(route);
  }

  String ensureSessionCorrelation() {
    return _sessionCorrelationId ?? startSessionCorrelation();
  }

  String startSessionCorrelation() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index += 1) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    final sessionId = buffer.toString();
    _sessionCorrelationId = sessionId;
    return sessionId;
  }

  void clearSessionCorrelation() {
    _sessionCorrelationId = null;
  }

  void log({
    required AppLogLevel level,
    required AppLogCategory category,
    required String name,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final event = _redactor.redactEvent(
      AppLogEvent(
        timestamp: _clock(),
        level: level,
        category: category,
        name: name,
        attributes: {...attributes, 'sessionId': ?_sessionCorrelationId},
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );

    for (final sink in _sinks) {
      try {
        sink.add(event);
      } on Object {
        // Logging must never interrupt the user-facing operation.
      }
    }
  }
}

void appLogEvent(
  String name, {
  AppLogCategory? category,
  AppLogLevel level = AppLogLevel.info,
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
  Map<String, Object?> attributes = const {},
  Object? error,
  StackTrace? stackTrace,
}) {
  final logger = AppLogger.global;
  if (logger == null) return;
  logger.log(
    level: level,
    category: category ?? _categoryForEventName(name),
    name: name.toLowerCase(),
    attributes: <String, Object?>{
      ...attributes,
      'userId': ?userId,
      'activeContextKey': ?activeContextKey,
      'activeContextType': ?activeContextType,
      'weddingPlanId': ?weddingPlanId,
      'shellType': ?shellType,
      'selectedTab': ?selectedTab,
      'screen': ?screen,
      'httpStatus': ?httpStatus,
      if (currentRoute != null)
        'currentRoute': logger.sanitizeRouteTemplate(currentRoute),
      if (targetRoute != null)
        'targetRoute': logger.sanitizeRouteTemplate(targetRoute),
      'reason': ?reason,
      'source': ?source,
      'fromContextKey': ?fromContextKey,
      'toContextKey': ?toContextKey,
    },
    error: error,
    stackTrace: stackTrace,
  );
}

AppLogCategory _categoryForEventName(String name) {
  final normalized = name.toUpperCase();
  if (normalized.startsWith('API_') ||
      normalized == 'UNAUTHORIZED_401' ||
      normalized == 'FORBIDDEN_403') {
    return AppLogCategory.api;
  }
  if (normalized.startsWith('PUSH_')) return AppLogCategory.push;
  if (normalized.contains('ROUTE') || normalized.contains('NAVIGATION')) {
    return AppLogCategory.navigation;
  }
  if (normalized.contains('CONTEXT') ||
      normalized.contains('WORKSPACE') ||
      normalized.startsWith('WORKSPACES_')) {
    return AppLogCategory.context;
  }
  if (normalized.contains('LOGIN') ||
      normalized.contains('LOGOUT') ||
      normalized.contains('AUTH')) {
    return AppLogCategory.auth;
  }
  if (normalized.contains('SESSION')) return AppLogCategory.session;
  return AppLogCategory.lifecycle;
}

/// A note for whoever runs a debug build. `debugPrint` writes to the phone's
/// log in a release build too, and these notes name plans, providers and
/// requests by their ids (RA-MO-104); a release build keeps them to itself.
void appDebugNote(String message) {
  if (kDebugMode) debugPrint(message);
}

final class DebugConsoleAppLogSink implements AppLogSink {
  DebugConsoleAppLogSink({void Function(String message)? writer})
    : _writer = writer ?? ((message) => debugPrint(message));

  final void Function(String message) _writer;

  @override
  void add(AppLogEvent event) {
    if (!kDebugMode) return;
    _writer(jsonEncode(event.toJson()));
  }
}

final class MemoryRingBufferSink implements AppLogSink {
  MemoryRingBufferSink({
    this.maxEvents = 300,
    this.maxBytes = 256 * 1024,
    this.maxAge = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxEvents <= 0) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'must be positive');
    }
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }
    if (maxAge <= Duration.zero) {
      throw ArgumentError.value(maxAge, 'maxAge', 'must be positive');
    }
  }

  final int maxEvents;
  final int maxBytes;
  final Duration maxAge;
  final DateTime Function() _clock;
  final Queue<_BufferedLogEvent> _buffer = Queue();
  int _totalBytes = 0;

  List<AppLogEvent> get events {
    _pruneExpired();
    return List<AppLogEvent>.unmodifiable(_buffer.map((entry) => entry.event));
  }

  int get totalBytes {
    _pruneExpired();
    return _totalBytes;
  }

  @override
  void add(AppLogEvent event) {
    _pruneExpired();
    final encodedBytes = utf8.encode(jsonEncode(event.toJson())).length;
    if (encodedBytes > maxBytes) return;

    _buffer.addLast(_BufferedLogEvent(event, encodedBytes));
    _totalBytes += encodedBytes;
    while (_buffer.length > maxEvents || _totalBytes > maxBytes) {
      _removeOldest();
    }
  }

  void _pruneExpired() {
    final cutoff = _clock().toUtc().subtract(maxAge);
    while (_buffer.isNotEmpty &&
        _buffer.first.event.timestamp.isBefore(cutoff)) {
      _removeOldest();
    }
  }

  void _removeOldest() {
    final removed = _buffer.removeFirst();
    _totalBytes -= removed.encodedBytes;
  }
}

final class _BufferedLogEvent {
  const _BufferedLogEvent(this.event, this.encodedBytes);

  final AppLogEvent event;
  final int encodedBytes;
}
