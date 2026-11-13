import 'dart:convert';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/diagnostics/crash_report_switch.dart';
import 'package:aarast_mobile/core/diagnostics/sentry_log_sink.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SentryAppLogSink', () {
    late _FakeSentryLogTransport transport;
    late SentryAppLogSink sink;

    setUp(() {
      transport = _FakeSentryLogTransport();
      sink = SentryAppLogSink(
        redactor: LogRedactor(installationSalt: 'test-installation-salt'),
        transport: transport,
      );
    });

    test('sends errors as redacted events, never as breadcrumbs', () {
      sink.add(
        AppLogEvent(
          timestamp: DateTime.utc(2026, 7, 30),
          level: AppLogLevel.error,
          category: AppLogCategory.auth,
          name: 'login_failure',
          attributes: const {
            'requestId': 'request-safe-123',
            'accessToken': 'token-must-not-leave',
            'phone': '+967777123456',
          },
          error: 'Bearer top-secret-token for +967777123456',
          stackTrace: 'trace token=stack-secret',
        ),
      );

      expect(transport.events, hasLength(1));
      expect(transport.breadcrumbs, isEmpty);
      final event = transport.events.single;
      expect(event.level, SentryLevel.error);
      expect(event.tags?['category'], 'auth');
      expect(event.tags?['event_name'], 'login_failure');
      final payload = jsonEncode(event.toJson());
      expect(payload, contains('request-safe-123'));
      expect(payload, isNot(contains('token-must-not-leave')));
      expect(payload, isNot(contains('top-secret-token')));
      expect(payload, isNot(contains('+967777123456')));
      expect(transport.stackTraces.single, isNot(contains('stack-secret')));
    });

    test('sends non-errors as structured redacted breadcrumbs', () {
      sink.add(
        AppLogEvent(
          timestamp: DateTime.utc(2026, 7, 30),
          level: AppLogLevel.info,
          category: AppLogCategory.navigation,
          name: 'effective_transition',
          attributes: const {
            'fromRoute': '/login?phone=+967777123456',
            'toRoute': '/home',
            'authorization': 'Bearer secret',
          },
        ),
      );

      expect(transport.events, isEmpty);
      expect(transport.breadcrumbs, hasLength(1));
      final breadcrumb = transport.breadcrumbs.single;
      expect(breadcrumb.category, 'aarast.navigation');
      expect(breadcrumb.message, 'effective_transition');
      expect(breadcrumb.level, SentryLevel.info);
      expect(jsonEncode(breadcrumb.toJson()), isNot(contains('967777123456')));
      expect(jsonEncode(breadcrumb.toJson()), isNot(contains('Bearer secret')));
    });

    test('beforeSend removes request and user PII and scrubs messages', () {
      final event = SentryEvent(
        message: SentryMessage(
          'token=event-secret phone=+967777123456',
          params: const ['Bearer parameter-secret'],
        ),
        transaction: '/login?phone=+967777123456',
        user: SentryUser(id: 'user-private-id', email: 'private@example.com'),
        request: SentryRequest(
          url: 'https://api.example.test/login?phone=+967777123456',
          queryString: 'phone=+967777123456',
          headers: const {'Authorization': 'Bearer request-secret'},
          data: const {'refreshToken': 'request-body-secret'},
        ),
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'refreshToken=exception-secret +967777123456',
          ),
        ],
      );

      final scrubbed = sink.beforeSend(event, Hint());

      expect(scrubbed, isNotNull);
      expect(scrubbed!.user, isNull);
      expect(scrubbed.request, isNull);
      final payload = jsonEncode(scrubbed.toJson());
      expect(payload, isNot(contains('event-secret')));
      expect(payload, isNot(contains('parameter-secret')));
      expect(payload, isNot(contains('request-secret')));
      expect(payload, isNot(contains('request-body-secret')));
      expect(payload, isNot(contains('exception-secret')));
      expect(payload, isNot(contains('+967777123456')));
      expect(scrubbed.transaction, '/login');
    });

    test('beforeBreadcrumb drops raw console and HTTP breadcrumbs', () {
      expect(
        sink.beforeBreadcrumb(
          Breadcrumb.console(message: 'token=console-secret'),
          Hint(),
        ),
        isNull,
      );
      expect(
        sink.beforeBreadcrumb(
          Breadcrumb.http(
            url: Uri.parse('https://api.example.test/login?token=http-secret'),
            method: 'POST',
          ),
          Hint(),
        ),
        isNull,
      );
    });

    test('beforeBreadcrumb redacts retained structured breadcrumbs', () {
      final scrubbed = sink.beforeBreadcrumb(
        Breadcrumb(
          category: 'aarast.session',
          message: 'Bearer breadcrumb-secret for +967777123456',
          data: const {
            'requestId': 'safe-correlation-id',
            'headers': {'Authorization': 'Bearer header-secret'},
          },
        ),
        Hint(),
      );

      expect(scrubbed, isNotNull);
      final payload = jsonEncode(scrubbed!.toJson());
      expect(payload, contains('safe-correlation-id'));
      expect(payload, isNot(contains('breadcrumb-secret')));
      expect(payload, isNot(contains('header-secret')));
      expect(payload, isNot(contains('+967777123456')));
    });

    // RA-MO-102 (D63, w40): the reporter's performance traces never asked
    // the phone's switch.
    test('performance traces stay on the phone while reports are off', () {
      addTearDown(() => CrashReportSwitch.set(true));
      final transaction = _FakeTransaction();

      CrashReportSwitch.set(false);
      expect(sink.beforeSendTransaction(transaction, Hint()), isNull);
      CrashReportSwitch.set(true);
      expect(
        sink.beforeSendTransaction(transaction, Hint()),
        same(transaction),
      );
    });
  });

  // RA-MO-102: the reporter starts before the app's preferences; the choice
  // is read from the same place first.
  test('the stored choice is read before the preferences exist', () async {
    SharedPreferences.setMockInitialValues({});
    expect(
      DevicePreferences.storedCrashReports(
        await SharedPreferences.getInstance(),
      ),
      isTrue,
    );
    final preferences = DevicePreferences(
      await SharedPreferences.getInstance(),
    );
    addTearDown(() => CrashReportSwitch.set(true));
    await preferences.setCrashReports(false);
    expect(
      DevicePreferences.storedCrashReports(
        await SharedPreferences.getInstance(),
      ),
      isFalse,
    );
  });
}

final class _FakeSentryLogTransport implements SentryLogTransport {
  final List<SentryEvent> events = [];
  final List<StackTrace?> stackTraces = [];
  final List<Breadcrumb> breadcrumbs = [];

  @override
  Future<void> captureEvent(SentryEvent event, {StackTrace? stackTrace}) async {
    events.add(event);
    stackTraces.add(stackTrace);
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    breadcrumbs.add(breadcrumb);
  }
}

/// A performance trace; the switch only decides whether it leaves.
class _FakeTransaction extends Fake implements SentryTransaction {}
