import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum DiagnosticReportSendResult { sent, empty, failed }

abstract interface class DiagnosticReportService {
  bool get isAvailable;

  Future<DiagnosticReportSendResult> send();
}

/// Transport boundary for the consent-gated diagnostic report.
///
/// Implementations must not persist or retry [attachment]. A failed send is
/// terminal so the caller can ask the user to try again explicitly.
abstract interface class DiagnosticReportTransport {
  Future<bool> send({
    required SentryEvent event,
    required SentryAttachment attachment,
  });
}

final class DiagnosticReportSender implements DiagnosticReportService {
  DiagnosticReportSender({
    required MemoryRingBufferSink ringBuffer,
    required LogRedactor redactor,
    required DiagnosticReportTransport transport,
    DateTime Function()? clock,
  }) : _ringBuffer = ringBuffer,
       _redactor = redactor,
       _transport = transport,
       _clock = clock ?? DateTime.now;

  static const int schemaVersion = 1;
  static const String attachmentFileName = 'aarast-diagnostic-report.json';

  final MemoryRingBufferSink _ringBuffer;
  final LogRedactor _redactor;
  final DiagnosticReportTransport _transport;
  final DateTime Function() _clock;

  @override
  bool get isAvailable => true;

  /// Creates and sends a fresh snapshot only when explicitly invoked.
  ///
  /// The JSON bytes and attachment are local variables and are released when
  /// this future completes. A failure is never queued for retry.
  @override
  Future<DiagnosticReportSendResult> send() async {
    final snapshot = _ringBuffer.events;
    if (snapshot.isEmpty) return DiagnosticReportSendResult.empty;

    try {
      final generatedAt = _clock().toUtc();
      final safeEvents = snapshot
          .map(_redactor.redactEvent)
          .map((event) => event.toJson())
          .toList(growable: false);
      final report = _redactor.redactAttributes({
        'schemaVersion': schemaVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'eventCount': safeEvents.length,
        'events': safeEvents,
      });
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(report)));
      final attachment = SentryAttachment.fromUint8List(
        bytes,
        attachmentFileName,
        contentType: 'application/json',
      );
      final contexts = Contexts();
      contexts['aarast'] = <String, Object?>{
        'diagnostic_schema_version': schemaVersion,
        'diagnostic_event_count': safeEvents.length,
      };
      final event = SentryEvent(
        timestamp: generatedAt,
        logger: 'aarast',
        level: SentryLevel.info,
        message: SentryMessage('diagnostic_report'),
        tags: const {'category': 'support', 'event_name': 'diagnostic_report'},
        contexts: contexts,
      );

      final sent = await _transport.send(event: event, attachment: attachment);
      return sent
          ? DiagnosticReportSendResult.sent
          : DiagnosticReportSendResult.failed;
    } on Object {
      return DiagnosticReportSendResult.failed;
    }
  }
}

final class UnavailableDiagnosticReportService
    implements DiagnosticReportService {
  const UnavailableDiagnosticReportService();

  @override
  bool get isAvailable => false;

  @override
  Future<DiagnosticReportSendResult> send() async {
    return DiagnosticReportSendResult.failed;
  }
}

/// Sends one Sentry envelope directly from memory.
///
/// The standard mobile Sentry transport stores envelopes through the native
/// SDK. That behavior is correct for crash recovery but not for a
/// consent-scoped diagnostic attachment. This transport therefore performs
/// one direct HTTP request, has no retry queue, and never writes a file.
final class DirectSentryDiagnosticReportTransport
    implements DiagnosticReportTransport {
  DirectSentryDiagnosticReportTransport({
    required String dsn,
    Dio? dio,
    this.environment,
    this.release,
    this.timeout = const Duration(seconds: 10),
  }) : _dsnValue = dsn.trim(),
       _dsn = Dsn.parse(dsn.trim()),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               sendTimeout: timeout,
               receiveTimeout: timeout,
             ),
           );

  final String _dsnValue;
  final Dsn _dsn;
  final Dio _dio;
  final String? environment;
  final String? release;
  final Duration timeout;

  @override
  Future<bool> send({
    required SentryEvent event,
    required SentryAttachment attachment,
  }) async {
    try {
      final options = SentryOptions(dsn: _dsnValue)
        ..compressPayload = false
        ..sendDefaultPii = false;
      event
        ..environment = _nonEmpty(environment)
        ..release = _nonEmpty(release)
        ..sdk = options.sdk
        ..platform = 'other';

      final envelope = SentryEnvelope.fromEvent(
        event,
        options.sdk,
        dsn: _dsnValue,
        attachments: [attachment],
      );
      final builder = BytesBuilder(copy: false);
      await envelope.envelopeStream(options).forEach(builder.add);
      final response = await _dio.postUri<Object?>(
        _dsn.postUri,
        data: builder.takeBytes(),
        options: Options(
          contentType: 'application/x-sentry-envelope',
          responseType: ResponseType.plain,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
          headers: {'X-Sentry-Auth': _authorizationHeader(options.sdk)},
        ),
      );
      return response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  String _authorizationHeader(SdkVersion sdk) {
    final secret = _dsn.secretKey;
    return 'Sentry sentry_version=7, '
        'sentry_client=${sdk.name}/${sdk.version}, '
        'sentry_key=${_dsn.publicKey}'
        '${secret == null ? '' : ', sentry_secret=$secret'}';
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
