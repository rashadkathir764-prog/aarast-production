import 'dart:convert';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogRedactor', () {
    test(
      'removes secrets, contact data, and HTTP payload data recursively',
      () {
        final redactor = LogRedactor(installationSalt: 'installation-salt-a');

        final safe = redactor.redactAttributes({
          'method': 'POST',
          'statusCode': 201,
          'accessToken': 'access-secret',
          'password': 'correct horse battery staple',
          'phone': '+967 777 123 456',
          'requestBody': {'message': 'private body'},
          'headers': {'Authorization': 'Bearer header-secret'},
          'queryParameters': {'invite': 'private-query'},
          'nested': {
            'refresh_token': 'refresh-secret',
            'mobileNumber': '777123456',
            'safeResult': 'success',
          },
        });

        expect(safe, {
          'method': 'POST',
          'statusCode': 201,
          'nested': {'safeResult': 'success'},
        });
        expect(
          jsonEncode(safe),
          isNot(
            anyOf(
              contains('access-secret'),
              contains('correct horse'),
              contains('777123456'),
              contains('private body'),
              contains('Bearer'),
              contains('private-query'),
            ),
          ),
        );
      },
    );

    test('hashes user and context identifiers with the installation salt', () {
      final first = LogRedactor(installationSalt: 'installation-salt-a')
          .redactAttributes({
            'userId': 'user-123',
            'contextKey': 'provider:provider-789',
          });
      final repeated = LogRedactor(installationSalt: 'installation-salt-a')
          .redactAttributes({
            'userId': 'user-123',
            'contextKey': 'provider:provider-789',
          });
      final otherInstallation =
          LogRedactor(installationSalt: 'installation-salt-b').redactAttributes(
            {'userId': 'user-123', 'contextKey': 'provider:provider-789'},
          );

      expect(first.keys, containsAll(<String>['userIdHash', 'contextKeyHash']));
      expect(first, repeated);
      expect(first['userIdHash'], isNot(otherInstallation['userIdHash']));
      expect(
        first['contextKeyHash'],
        isNot(otherInstallation['contextKeyHash']),
      );
      expect(jsonEncode(first), isNot(contains('user-123')));
      expect(jsonEncode(first), isNot(contains('provider-789')));
    });

    test(
      'does not emit raw identifiers or sensitive values hidden in text',
      () {
        const rawId = '550e8400-e29b-41d4-a716-446655440000';
        final redactor = LogRedactor(installationSalt: 'installation-salt-a');

        final safe = redactor.redactAttributes({
          'weddingPlanId': rawId,
          'providerId': 'provider-42',
          'requestId': 'request-correlation-1',
          'message':
              'failed for $rawId; Authorization: Bearer token-value; '
              'phone=+967777123456',
          'route': '/api/v1/providers/$rawId?phone=777123456&token=secret',
        });

        expect(safe['weddingPlanIdHash'], isA<String>());
        expect(safe['providerIdHash'], isA<String>());
        expect(safe['requestId'], 'request-correlation-1');
        expect(safe['route'], '/api/v1/providers/[id]');
        final encoded = jsonEncode(safe);
        expect(encoded, isNot(contains(rawId)));
        expect(encoded, isNot(contains('provider-42')));
        expect(encoded, isNot(contains('token-value')));
        expect(encoded, isNot(contains('777123456')));
        expect(encoded, isNot(contains('secret')));
      },
    );

    test('removes embedded URL query values and email addresses from text', () {
      final redactor = LogRedactor(installationSalt: 'installation-salt-a');

      final safe = redactor.redactAttributes({
        'message':
            'GET https://api.example.test/users/me?invite=private-value '
            'failed for bride@example.test',
      });
      final encoded = jsonEncode(safe);

      expect(encoded, contains('https://api.example.test/users/me'));
      expect(encoded, isNot(contains('private-value')));
      expect(encoded, isNot(contains('bride@example.test')));
    });
  });

  group('AppLogger', () {
    test('redacts an event before any sink receives it', () {
      final sink = _CollectingSink();
      final logger = AppLogger(
        redactor: LogRedactor(installationSalt: 'installation-salt-a'),
        sinks: [sink],
        clock: () => DateTime.utc(2026, 7, 30, 10),
      );

      logger.log(
        level: AppLogLevel.info,
        category: AppLogCategory.auth,
        name: 'login_success',
        attributes: {
          'userId': 'user-123',
          'accessToken': 'do-not-emit',
          'method': 'POST',
        },
        error: StateError('Bearer do-not-emit +967777123456'),
      );

      expect(sink.events, hasLength(1));
      final event = sink.events.single;
      expect(event.timestamp, DateTime.utc(2026, 7, 30, 10));
      expect(event.category, AppLogCategory.auth);
      expect(event.name, 'login_success');
      expect(event.attributes['method'], 'POST');
      expect(event.attributes['userIdHash'], isA<String>());
      expect(event.attributes, isNot(contains('accessToken')));
      expect(event.error, isNot(contains('do-not-emit')));
      expect(event.error, isNot(contains('777123456')));
    });

    test(
      'adds a stable hashed session correlation and rotates it explicitly',
      () {
        final sink = _CollectingSink();
        final logger = AppLogger(
          redactor: LogRedactor(installationSalt: 'installation-salt-a'),
          sinks: [sink],
        );

        final firstRaw = logger.startSessionCorrelation();
        logger.log(
          level: AppLogLevel.info,
          category: AppLogCategory.session,
          name: 'first',
        );
        logger.log(
          level: AppLogLevel.info,
          category: AppLogCategory.navigation,
          name: 'second',
        );
        final secondRaw = logger.startSessionCorrelation();
        logger.log(
          level: AppLogLevel.info,
          category: AppLogCategory.api,
          name: 'third',
        );

        final firstHash = sink.events[0].attributes['sessionIdHash'];
        expect(firstHash, isA<String>());
        expect(sink.events[1].attributes['sessionIdHash'], firstHash);
        expect(sink.events[2].attributes['sessionIdHash'], isNot(firstHash));
        expect(firstRaw, isNot(secondRaw));
        expect(
          jsonEncode(sink.events.map((event) => event.toJson()).toList()),
          isNot(anyOf(contains(firstRaw), contains(secondRaw))),
        );
      },
    );

    test('serializes every required category by its stable wire name', () {
      expect(
        AppLogCategory.values.map((category) => category.wireName).toList(),
        [
          'auth',
          'session',
          'context',
          'navigation',
          'api',
          'cache',
          'database',
          'state',
          'lifecycle',
          'provider',
          'groom',
          'contributor',
          'push',
          'chat',
          'error',
        ],
      );
    });

    test('debug console sink emits one structured JSON event', () {
      final messages = <String>[];
      final sink = DebugConsoleAppLogSink(writer: messages.add);

      sink.add(
        AppLogEvent(
          timestamp: DateTime.utc(2026, 7, 30, 10),
          level: AppLogLevel.warning,
          category: AppLogCategory.navigation,
          name: 'navigation_redirect',
          attributes: const {'fromRoute': '/login', 'toRoute': '/home'},
        ),
      );

      expect(messages, hasLength(1));
      expect(jsonDecode(messages.single), {
        'timestamp': '2026-07-30T10:00:00.000Z',
        'level': 'warning',
        'category': 'navigation',
        'name': 'navigation_redirect',
        'attributes': {'fromRoute': '/login', 'toRoute': '/home'},
      });
    });
  });

  group('MemoryRingBufferSink', () {
    test('keeps at most the newest 300 events', () {
      var now = DateTime.utc(2026, 7, 30, 10);
      final sink = MemoryRingBufferSink(clock: () => now);

      for (var index = 0; index < 305; index += 1) {
        sink.add(_event(index, now));
        now = now.add(const Duration(milliseconds: 1));
      }

      expect(sink.events, hasLength(300));
      expect(sink.events.first.name, 'event-5');
      expect(sink.events.last.name, 'event-304');
    });

    test('evicts oldest events until encoded content is at most 256KB', () {
      final now = DateTime.utc(2026, 7, 30, 10);
      final sink = MemoryRingBufferSink(clock: () => now);
      final payload = 'x' * (90 * 1024);

      sink
        ..add(_event(1, now, payload: payload))
        ..add(_event(2, now, payload: payload))
        ..add(_event(3, now, payload: payload));

      expect(sink.totalBytes, lessThanOrEqualTo(256 * 1024));
      expect(sink.events.map((event) => event.name), ['event-2', 'event-3']);
    });

    test('drops one event that cannot fit within the byte budget', () {
      final now = DateTime.utc(2026, 7, 30, 10);
      final sink = MemoryRingBufferSink(maxBytes: 512, clock: () => now);

      sink.add(_event(1, now, payload: 'x' * 1024));

      expect(sink.events, isEmpty);
      expect(sink.totalBytes, 0);
    });

    test('keeps only events from the latest 15 minutes', () {
      var now = DateTime.utc(2026, 7, 30, 10);
      final sink = MemoryRingBufferSink(clock: () => now);
      sink.add(_event(1, now));

      now = now.add(const Duration(minutes: 14, seconds: 59));
      sink.add(_event(2, now));
      expect(sink.events.map((event) => event.name), ['event-1', 'event-2']);

      now = now.add(const Duration(seconds: 2));
      expect(sink.events.map((event) => event.name), ['event-2']);
    });
  });
}

AppLogEvent _event(int index, DateTime timestamp, {String? payload}) {
  return AppLogEvent(
    timestamp: timestamp,
    level: AppLogLevel.info,
    category: AppLogCategory.state,
    name: 'event-$index',
    attributes: payload == null ? const {} : {'payloadText': payload},
  );
}

class _CollectingSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) {
    events.add(event);
  }
}
