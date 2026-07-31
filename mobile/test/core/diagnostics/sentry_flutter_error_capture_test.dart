// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:aarast_mobile/core/config/observability_config.dart';
import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/diagnostics/sentry_log_sink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'FlutterError.reportError sends exactly one event envelope through SentryFlutter',
    () async {
      await Sentry.close();
      SentryFlutter.native = null;
      SentryFlutter.sentrySetupStartTime = null;

      final originalFlutterErrorHandler = FlutterError.onError;
      final originalPlatformErrorHandler = PlatformDispatcher.instance.onError;
      var forwardedFlutterErrors = 0;
      FlutterError.onError = (_) => forwardedFlutterErrors += 1;

      addTearDown(() async {
        await Sentry.close();
        SentryFlutter.native = null;
        SentryFlutter.sentrySetupStartTime = null;
        FlutterError.onError = originalFlutterErrorHandler;
        PlatformDispatcher.instance.onError = originalPlatformErrorHandler;
      });

      final transport = _RecordingTransport();
      final sink = SentryAppLogSink(
        redactor: LogRedactor(installationSalt: 'sentry-flutter-sdk-test-salt'),
      );

      await SentryFlutter.init((options) {
        const ObservabilityConfig(
          dsn: 'https://public@example.invalid/1',
          environment: 'test',
          tracesSampleRateOverride: '0',
        ).applyTo(
          options,
          beforeSend: sink.beforeSend,
          beforeBreadcrumb: sink.beforeBreadcrumb,
        );
        options
          ..transport = transport
          ..autoInitializeNativeSdk = false
          ..enableNativeCrashHandling = false
          ..enableAutoSessionTracking = false
          ..sendClientReports = false
          ..enableAppHangTracking = false
          ..enableFramesTracking = false
          ..enableTimeToFullDisplayTracing = false;
        for (final integration
            in options.integrations.whereType<LoadReleaseIntegration>()) {
          options.removeIntegration(integration);
        }
      }, appRunner: () {});

      final details = FlutterErrorDetails(
        exception: StateError('single Flutter SDK capture'),
        stack: StackTrace.current,
        library: 'aarast_test',
      );
      FlutterError.reportError(details);

      await transport.waitUntilIdle();

      expect(forwardedFlutterErrors, 1);
      expect(transport.envelopes, hasLength(1));
      final items = transport.envelopes.single.items.toList(growable: false);
      expect(items, hasLength(1));

      final payload =
          jsonDecode(utf8.decode(await items.single.dataFactory()))
              as Map<String, dynamic>;
      final exceptions =
          (payload['exception'] as Map<String, dynamic>)['values'] as List;
      expect(exceptions, hasLength(1));
      expect(
        (exceptions.single as Map<String, dynamic>)['mechanism'],
        containsPair('type', 'FlutterError'),
      );
    },
  );
}

final class _RecordingTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];
  final Completer<void> _firstEnvelope = Completer<void>();

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    if (!_firstEnvelope.isCompleted) {
      _firstEnvelope.complete();
    }
    return envelope.header.eventId ?? SentryId.empty();
  }

  Future<void> waitUntilIdle() async {
    await _firstEnvelope.future.timeout(const Duration(seconds: 5));
    var observedCount = -1;
    while (observedCount != envelopes.length) {
      observedCount = envelopes.length;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}
