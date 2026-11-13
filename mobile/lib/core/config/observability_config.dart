// ignore_for_file: experimental_member_use

import 'package:sentry_flutter/sentry_flutter.dart';

/// Compile-time observability settings and the fixed Aarast privacy policy.
///
/// The DSN and trace override are public client-side configuration. Upload
/// credentials such as `SENTRY_AUTH_TOKEN` must remain CI-only and are not read
/// by the application.
class ObservabilityConfig {
  const ObservabilityConfig({
    this.dsn = '',
    this.environment = 'development',
    this.tracesSampleRateOverride = '',
    this.release = '',
  });

  const ObservabilityConfig.fromEnvironment()
    : dsn = const String.fromEnvironment('AARAST_SENTRY_DSN'),
      environment = const String.fromEnvironment(
        'AARAST_ENVIRONMENT',
        defaultValue: 'development',
      ),
      tracesSampleRateOverride = const String.fromEnvironment(
        'AARAST_SENTRY_TRACES_SAMPLE_RATE',
      ),
      release = const String.fromEnvironment('SENTRY_RELEASE');

  final String dsn;
  final String environment;
  final String tracesSampleRateOverride;
  final String release;

  bool get isEnabled => dsn.trim().isNotEmpty;

  double get tracesSampleRate {
    final override = double.tryParse(tracesSampleRateOverride.trim());
    if (override != null && override >= 0 && override <= 1) {
      return override;
    }

    return environment.trim().toLowerCase() == 'staging' ? 1.0 : 0.1;
  }

  /// Applies settings which must not be weakened by a call site.
  void applyTo(
    SentryFlutterOptions options, {
    BeforeSendCallback? beforeSend,
    BeforeSendTransactionCallback? beforeSendTransaction,
    BeforeBreadcrumbCallback? beforeBreadcrumb,
  }) {
    options
      ..dsn = dsn.trim()
      ..environment = environment.trim()
      ..sampleRate = 1.0
      ..tracesSampleRate = tracesSampleRate
      ..profilesSampleRate = 0.0
      ..sendDefaultPii = false
      ..enableAutoNativeBreadcrumbs = false
      ..enablePrintBreadcrumbs = false
      ..recordHttpBreadcrumbs = false
      ..captureFailedRequests = false
      ..maxRequestBodySize = MaxRequestBodySize.never
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..reportViewHierarchyIdentifiers = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..beforeSend = beforeSend
      ..beforeSendTransaction = beforeSendTransaction
      ..beforeBreadcrumb = beforeBreadcrumb;

    options.replay
      ..sessionSampleRate = 0.0
      ..onErrorSampleRate = 0.0;

    final normalizedRelease = release.trim();
    if (normalizedRelease.isNotEmpty) {
      options.release = normalizedRelease;
    }
  }
}
