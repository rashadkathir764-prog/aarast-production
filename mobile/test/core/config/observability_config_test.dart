// ignore_for_file: experimental_member_use

import 'package:aarast_mobile/core/config/observability_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('ObservabilityConfig', () {
    test('uses the fixed privacy and error sampling policy', () {
      final options = SentryFlutterOptions();
      const config = ObservabilityConfig(
        dsn: 'https://public@example.invalid/1',
        environment: 'production',
      );

      config.applyTo(options);

      expect(options.dsn, 'https://public@example.invalid/1');
      expect(options.environment, 'production');
      expect(options.sampleRate, 1);
      expect(options.sendDefaultPii, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
      expect(options.enablePrintBreadcrumbs, isFalse);
      expect(options.recordHttpBreadcrumbs, isFalse);
      expect(options.captureFailedRequests, isFalse);
      expect(options.maxRequestBodySize, MaxRequestBodySize.never);
    });

    test('disables replay, profiling, screenshots, and view hierarchy', () {
      final options = SentryFlutterOptions();
      const config = ObservabilityConfig(
        dsn: 'https://public@example.invalid/1',
        environment: 'staging',
      );

      config.applyTo(options);

      expect(options.profilesSampleRate, 0);
      expect(options.replay.sessionSampleRate, 0);
      expect(options.replay.onErrorSampleRate, 0);
      expect(options.attachScreenshot, isFalse);
      expect(options.attachViewHierarchy, isFalse);
      expect(options.reportViewHierarchyIdentifiers, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableUserInteractionTracing, isFalse);
    });

    test('uses 100% staging traces and 10% production traces', () {
      final stagingOptions = SentryFlutterOptions();
      const ObservabilityConfig(environment: 'staging').applyTo(stagingOptions);

      final productionOptions = SentryFlutterOptions();
      const ObservabilityConfig(
        environment: 'production',
      ).applyTo(productionOptions);

      expect(stagingOptions.tracesSampleRate, 1);
      expect(productionOptions.tracesSampleRate, .1);
    });

    test('accepts a valid trace override and rejects invalid values', () {
      final overriddenOptions = SentryFlutterOptions();
      const ObservabilityConfig(
        environment: 'production',
        tracesSampleRateOverride: '0.35',
      ).applyTo(overriddenOptions);

      final tooHighOptions = SentryFlutterOptions();
      const ObservabilityConfig(
        environment: 'production',
        tracesSampleRateOverride: '1.01',
      ).applyTo(tooHighOptions);

      final malformedOptions = SentryFlutterOptions();
      const ObservabilityConfig(
        environment: 'staging',
        tracesSampleRateOverride: 'secret',
      ).applyTo(malformedOptions);

      expect(overriddenOptions.tracesSampleRate, .35);
      expect(tooHighOptions.tracesSampleRate, .1);
      expect(malformedOptions.tracesSampleRate, 1);
    });

    test('does not enable Sentry without a non-empty DSN', () {
      expect(
        const ObservabilityConfig(environment: 'production').isEnabled,
        isFalse,
      );
      expect(
        const ObservabilityConfig(
          dsn: '  ',
          environment: 'production',
        ).isEnabled,
        isFalse,
      );
      expect(
        const ObservabilityConfig(
          dsn: 'https://public@example.invalid/1',
          environment: 'production',
        ).isEnabled,
        isTrue,
      );
    });
  });
}
