import 'dart:async';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/diagnostics/crash_report_switch.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Narrow seam around the Sentry SDK so the sink can be verified without
/// network access or a real DSN.
abstract interface class SentryLogTransport {
  Future<void> captureEvent(SentryEvent event, {StackTrace? stackTrace});

  Future<void> addBreadcrumb(Breadcrumb breadcrumb);
}

final class SentryAppLogSink implements AppLogSink {
  SentryAppLogSink({
    required LogRedactor redactor,
    SentryLogTransport? transport,
  }) : _redactor = redactor,
       _transport = transport ?? const _SdkSentryLogTransport();

  final LogRedactor _redactor;
  final SentryLogTransport _transport;

  @override
  void add(AppLogEvent event) {
    // D63 (w40): reports off on this phone, nothing is sent.
    if (!CrashReportSwitch.enabled) return;
    final safeEvent = _redactor.redactEvent(event);
    if (safeEvent.level == AppLogLevel.error ||
        safeEvent.level == AppLogLevel.fatal) {
      unawaited(_ignoreTransportFailure(_captureEvent(safeEvent)));
      return;
    }

    unawaited(_ignoreTransportFailure(_addBreadcrumb(safeEvent)));
  }

  /// Defense-in-depth scrubber for automatic SDK events.
  ///
  /// This must be assigned to [SentryOptions.beforeSend] during initialization.
  SentryEvent? beforeSend(SentryEvent event, Hint hint) {
    // D63 (w40): reports off on this phone, the SDK's own events stay too.
    if (!CrashReportSwitch.enabled) return null;
    event
      ..serverName = null
      ..user = null
      ..request = null
      ..message = _scrubMessage(event.message)
      ..transaction = _scrubText(event.transaction)
      ..culprit = _scrubText(event.culprit)
      ..tags = _scrubStringMap(event.tags)
      ..fingerprint = event.fingerprint?.map(_scrubRequiredText).toList()
      ..breadcrumbs = event.breadcrumbs
          ?.map((breadcrumb) => beforeBreadcrumb(breadcrumb, hint))
          .whereType<Breadcrumb>()
          .toList();

    for (final exception in event.exceptions ?? const <SentryException>[]) {
      exception.value = _scrubText(exception.value);
    }

    // HTTP response contexts may contain headers or bodies. Aarast records
    // status/duration through its own allow-listed API log events instead.
    event.contexts.remove(SentryResponse.type);
    for (final key in List<String>.from(event.contexts.keys)) {
      final value = event.contexts[key];
      if (value is Map) {
        event.contexts[key] = _redactor.redactAttributes(
          value.map<String, Object?>(
            (mapKey, mapValue) =>
                MapEntry<String, Object?>(mapKey.toString(), mapValue),
          ),
        );
      }
    }

    // ignore: deprecated_member_use
    final extra = event.extra;
    if (extra != null) {
      // ignore: deprecated_member_use
      event.extra = _redactor.redactAttributes(
        extra.map<String, Object?>(
          (key, value) => MapEntry<String, Object?>(key, value),
        ),
      );
    }
    return event;
  }

  /// Defense-in-depth scrubber for SDK and application breadcrumbs.
  ///
  /// This must be assigned to [SentryOptions.beforeBreadcrumb].
  Breadcrumb? beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    final category = breadcrumb.category?.toLowerCase();
    final type = breadcrumb.type?.toLowerCase();
    if (category == 'console' ||
        category?.startsWith('console.') == true ||
        category == 'http' ||
        category?.startsWith('http.') == true ||
        type == 'http') {
      return null;
    }

    final data = breadcrumb.data;
    return Breadcrumb(
      timestamp: breadcrumb.timestamp,
      message: _scrubText(breadcrumb.message),
      category: _scrubText(breadcrumb.category),
      type: _scrubText(breadcrumb.type),
      level: breadcrumb.level,
      data: data == null
          ? null
          : _redactor.redactAttributes(
              data.map<String, Object?>(
                (key, value) => MapEntry<String, Object?>(key, value),
              ),
            ),
    );
  }

  Future<void> _captureEvent(AppLogEvent event) {
    final contexts = Contexts();
    contexts['aarast'] = <String, Object?>{
      if (event.attributes.isNotEmpty) 'attributes': event.attributes,
      if (event.error != null) 'error': event.error,
    };
    final sentryEvent = SentryEvent(
      timestamp: event.timestamp,
      logger: 'aarast',
      level: _toSentryLevel(event.level),
      message: SentryMessage('${event.category.wireName}.${event.name}'),
      throwable: event.error == null
          ? null
          : _RedactedLogException(event.error!),
      tags: {'category': event.category.wireName, 'event_name': event.name},
      contexts: contexts,
    );
    return _transport.captureEvent(
      sentryEvent,
      stackTrace: event.stackTrace == null
          ? null
          : StackTrace.fromString(event.stackTrace!),
    );
  }

  Future<void> _addBreadcrumb(AppLogEvent event) {
    return _transport.addBreadcrumb(
      Breadcrumb(
        timestamp: event.timestamp,
        category: 'aarast.${event.category.wireName}',
        message: event.name,
        level: _toSentryLevel(event.level),
        data: event.attributes,
      ),
    );
  }

  SentryMessage? _scrubMessage(SentryMessage? message) {
    if (message == null) return null;
    final params = message.params == null
        ? null
        : _redactor.redactAttributes({'params': message.params})['params'];
    return SentryMessage(
      _scrubRequiredText(message.formatted),
      template: _scrubText(message.template),
      params: params is List ? params : null,
    );
  }

  Map<String, String>? _scrubStringMap(Map<String, String>? input) {
    if (input == null) return null;
    final scrubbed = _redactor.redactAttributes(
      input.map<String, Object?>(
        (key, value) => MapEntry<String, Object?>(key, value),
      ),
    );
    return scrubbed.map(
      (key, value) => MapEntry<String, String>(key, value.toString()),
    );
  }

  String _scrubRequiredText(String value) {
    return _redactor.redactAttributes({'value': value})['value']?.toString() ??
        '[redacted]';
  }

  String? _scrubText(String? value) {
    return value == null ? null : _scrubRequiredText(value);
  }

  static SentryLevel _toSentryLevel(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.trace || AppLogLevel.debug => SentryLevel.debug,
      AppLogLevel.info => SentryLevel.info,
      AppLogLevel.warning => SentryLevel.warning,
      AppLogLevel.error => SentryLevel.error,
      AppLogLevel.fatal => SentryLevel.fatal,
    };
  }

  static Future<void> _ignoreTransportFailure(Future<void> operation) async {
    try {
      await operation;
    } on Object {
      // Observability must never interrupt a user-facing operation, and it
      // cannot safely log its own transport failure back into the same sink.
    }
  }
}

final class _SdkSentryLogTransport implements SentryLogTransport {
  const _SdkSentryLogTransport();

  @override
  Future<void> captureEvent(SentryEvent event, {StackTrace? stackTrace}) async {
    await Sentry.captureEvent(event, stackTrace: stackTrace);
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) {
    return Sentry.addBreadcrumb(breadcrumb);
  }
}

final class _RedactedLogException implements Exception {
  const _RedactedLogException(this.message);

  final String message;

  @override
  String toString() => message;
}
