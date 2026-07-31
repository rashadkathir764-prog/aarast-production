import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/diagnostics/diagnostic_report_sender.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('DiagnosticReportSender', () {
    late DateTime now;
    late MemoryRingBufferSink ringBuffer;
    late _FakeDiagnosticReportTransport transport;
    late DiagnosticReportSender sender;

    setUp(() {
      now = DateTime.utc(2026, 7, 30, 20);
      ringBuffer = MemoryRingBufferSink(clock: () => now);
      transport = _FakeDiagnosticReportTransport();
      sender = DiagnosticReportSender(
        ringBuffer: ringBuffer,
        redactor: LogRedactor(installationSalt: 'test-installation-salt'),
        transport: transport,
        clock: () => now,
      );
    });

    test('does not send anything until send is explicitly invoked', () {
      _addSensitiveEvent(ringBuffer, now);

      expect(transport.callCount, 0);
    });

    test('sends a defensively redacted in-memory JSON attachment', () async {
      _addSensitiveEvent(ringBuffer, now);

      final result = await sender.send();

      expect(result, DiagnosticReportSendResult.sent);
      expect(transport.callCount, 1);
      expect(transport.event!.message?.formatted, 'diagnostic_report');
      expect(transport.event!.tags?['event_name'], 'diagnostic_report');
      expect(transport.attachment!.filename, 'aarast-diagnostic-report.json');
      expect(transport.attachment!.contentType, 'application/json');

      final report =
          jsonDecode(utf8.decode(transport.attachmentBytes!))
              as Map<String, dynamic>;
      expect(report['schemaVersion'], 1);
      expect(report['eventCount'], 1);
      expect(report['generatedAt'], now.toIso8601String());

      final payload = jsonEncode(report);
      expect(payload, contains('safe-request-id'));
      expect(payload, isNot(contains('raw-access-token')));
      expect(payload, isNot(contains('super-secret')));
      expect(payload, isNot(contains('+967777123456')));
    });

    test('does not call the transport when the ring buffer is empty', () async {
      final result = await sender.send();

      expect(result, DiagnosticReportSendResult.empty);
      expect(transport.callCount, 0);
    });

    test('returns failure and rebuilds a fresh report on retry', () async {
      _addSensitiveEvent(ringBuffer, now);
      transport.shouldThrow = true;

      final firstResult = await sender.send();

      expect(firstResult, DiagnosticReportSendResult.failed);
      expect(transport.callCount, 1);

      now = now.add(const Duration(seconds: 1));
      ringBuffer.add(
        AppLogEvent(
          timestamp: now,
          level: AppLogLevel.info,
          category: AppLogCategory.session,
          name: 'retry_context',
          attributes: const {'requestId': 'second-request-id'},
        ),
      );
      transport.shouldThrow = false;

      final retryResult = await sender.send();

      expect(retryResult, DiagnosticReportSendResult.sent);
      expect(transport.callCount, 2);
      final retriedReport =
          jsonDecode(utf8.decode(transport.attachmentBytes!))
              as Map<String, dynamic>;
      expect(retriedReport['eventCount'], 2);
      expect(retriedReport['generatedAt'], now.toIso8601String());
      expect(jsonEncode(retriedReport), contains('second-request-id'));
    });
  });

  group('DirectSentryDiagnosticReportTransport', () {
    test('posts one in-memory Sentry envelope to the DSN endpoint', () async {
      RequestOptions? capturedRequest;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: '{"id":"accepted"}',
              ),
            );
          },
        ),
      );
      final transport = DirectSentryDiagnosticReportTransport(
        dsn: 'https://public@example.invalid/42',
        dio: dio,
        environment: 'staging',
        release: 'aarast@1.0.0+7',
      );

      final sent = await transport.send(
        event: SentryEvent(message: SentryMessage('diagnostic_report')),
        attachment: SentryAttachment.fromUint8List(
          Uint8List.fromList(utf8.encode('{"events":[]}')),
          'aarast-diagnostic-report.json',
          contentType: 'application/json',
        ),
      );

      expect(sent, isTrue);
      expect(
        capturedRequest?.uri,
        Uri.parse('https://example.invalid/api/42/envelope/'),
      );
      expect(
        capturedRequest?.headers['X-Sentry-Auth'],
        contains('sentry_key=public'),
      );
      expect(capturedRequest?.contentType, 'application/x-sentry-envelope');
      final envelopeBytes = capturedRequest?.data as Uint8List;
      final envelopeText = utf8.decode(envelopeBytes);
      expect(envelopeText, contains('diagnostic_report'));
      expect(envelopeText, contains('aarast-diagnostic-report.json'));
      expect(envelopeText, contains('{"events":[]}'));
    });

    test('returns false for a rejected envelope without retrying', () async {
      var requests = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests += 1;
            handler.resolve(
              Response<Object?>(requestOptions: options, statusCode: 503),
            );
          },
        ),
      );
      final transport = DirectSentryDiagnosticReportTransport(
        dsn: 'https://public@example.invalid/42',
        dio: dio,
      );

      final sent = await transport.send(
        event: SentryEvent(message: SentryMessage('diagnostic_report')),
        attachment: SentryAttachment.fromUint8List(
          Uint8List(0),
          'aarast-diagnostic-report.json',
          contentType: 'application/json',
        ),
      );

      expect(sent, isFalse);
      expect(requests, 1);
    });
  });
}

void _addSensitiveEvent(MemoryRingBufferSink sink, DateTime timestamp) {
  sink.add(
    AppLogEvent(
      timestamp: timestamp,
      level: AppLogLevel.error,
      category: AppLogCategory.auth,
      name: 'login_failure',
      attributes: const {
        'requestId': 'safe-request-id',
        'accessToken': 'raw-access-token',
        'phone': '+967777123456',
      },
      error: 'Bearer super-secret for +967777123456',
    ),
  );
}

final class _FakeDiagnosticReportTransport
    implements DiagnosticReportTransport {
  int callCount = 0;
  bool shouldThrow = false;
  SentryEvent? event;
  SentryAttachment? attachment;
  Uint8List? attachmentBytes;

  @override
  Future<bool> send({
    required SentryEvent event,
    required SentryAttachment attachment,
  }) async {
    callCount += 1;
    this.event = event;
    this.attachment = attachment;
    final loadedBytes = attachment.bytes;
    attachmentBytes = loadedBytes is Future<Uint8List>
        ? await loadedBytes
        : loadedBytes;
    if (shouldThrow) throw StateError('simulated network failure');
    return true;
  }
}
