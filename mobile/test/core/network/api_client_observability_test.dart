import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _CollectingSink sink;

  setUp(() {
    sink = _CollectingSink();
    AppLogger.installGlobal(
      AppLogger(
        redactor: LogRedactor(installationSalt: 'api-observability-test'),
        sinks: [sink],
      ),
    );
  });

  tearDown(AppLogger.clearGlobal);

  test(
    'adds a safe client request id and logs only safe HTTP metadata',
    () async {
      final adapter = _SuccessAdapter();
      final client = ApiClient(
        tokenProvider: () async => 'private-access-token',
      );
      client.dio.httpClientAdapter = adapter;

      await client.postJson(
        '/api/v1/wedding-plans/private-plan-id/tasks'
        '?phone=%2B967777123456&token=private-query-token',
        const {
          'password': 'private-password',
          'message': 'private-request-body',
        },
      );

      final clientRequestId = adapter
          .options!
          .headers[ApiClient.clientRequestIdHeader]
          ?.toString();
      expect(clientRequestId, matches(RegExp(r'^[a-f0-9]{32}$')));

      final request = sink.singleNamed('api_request');
      expect(request.attributes, {
        'method': 'POST',
        'routeTemplate': '/api/v1/wedding-plans/:plan/tasks',
        'attempt': 1,
        'clientRequestId': clientRequestId,
      });

      final response = sink.singleNamed('api_response');
      expect(response.attributes, {
        'method': 'POST',
        'routeTemplate': '/api/v1/wedding-plans/:plan/tasks',
        'statusCode': 200,
        'durationMs': isA<int>(),
        'attempt': 1,
        'clientRequestId': clientRequestId,
        'backendRequestId': 'backend-request-1',
      });
      expect(response.attributes['durationMs'], greaterThanOrEqualTo(0));

      final encodedEvents = jsonEncode(
        sink.events.map((event) => event.toJson()).toList(),
      );
      expect(encodedEvents, isNot(contains('private-access-token')));
      expect(encodedEvents, isNot(contains('private-password')));
      expect(encodedEvents, isNot(contains('private-request-body')));
      expect(encodedEvents, isNot(contains('private-query-token')));
      expect(encodedEvents, isNot(contains('967777123456')));
      expect(encodedEvents, isNot(contains('Authorization')));
      expect(encodedEvents, isNot(contains('headers')));
      expect(encodedEvents, isNot(contains('body')));
      expect(encodedEvents, isNot(contains('query')));
    },
  );

  test(
    '401 retry keeps one request id and records attempt failure without final failure',
    () async {
      var token = 'old-access-token';
      final adapter = _RefreshThenSuccessAdapter();
      final client = ApiClient(tokenProvider: () async => token);
      client.dio.httpClientAdapter = adapter;
      client.refreshSession = () async {
        token = 'new-access-token';
        return true;
      };

      final result = await client.getJson('/api/v1/wedding-plans/current');

      expect(result, {'ok': true});
      expect(adapter.clientRequestIds, hasLength(2));
      expect(adapter.clientRequestIds.toSet(), hasLength(1));

      final requests = sink.named('api_request');
      expect(requests.map((event) => event.attributes['attempt']), [1, 2]);
      expect(
        requests.map((event) => event.attributes['clientRequestId']).toSet(),
        hasLength(1),
      );

      final attemptFailure = sink.singleNamed('api_attempt_failure');
      expect(attemptFailure.attributes['statusCode'], 401);
      expect(attemptFailure.attributes['attempt'], 1);
      expect(
        attemptFailure.attributes['backendRequestId'],
        'backend-request-attempt-1',
      );
      expect(attemptFailure.attributes['durationMs'], isA<int>());

      final retry = sink.singleNamed('api_retry');
      expect(retry.attributes['attempt'], 1);
      expect(retry.attributes['nextAttempt'], 2);
      expect(retry.attributes['statusCode'], 401);
      expect(retry.attributes['durationMs'], isA<int>());
      expect(retry.attributes['backendRequestId'], 'backend-request-attempt-1');
      expect(
        retry.attributes['clientRequestId'],
        adapter.clientRequestIds.first,
      );

      final response = sink.singleNamed('api_response');
      expect(response.attributes['attempt'], 2);
      expect(response.attributes['statusCode'], 200);
      expect(
        response.attributes['backendRequestId'],
        'backend-request-attempt-2',
      );
      expect(sink.named('api_final_failure'), isEmpty);
    },
  );

  test(
    'generates a different client request id for unrelated requests',
    () async {
      final adapter = _ClientRequestIdCaptureAdapter();
      final client = ApiClient(tokenProvider: () async => null);
      client.dio.httpClientAdapter = adapter;

      await client.getJson('/api/v1/contexts');
      await client.getJson('/api/v1/notifications');

      expect(adapter.clientRequestIds, hasLength(2));
      expect(adapter.clientRequestIds.toSet(), hasLength(2));
      expect(
        adapter.clientRequestIds,
        everyElement(matches(RegExp(r'^[a-f0-9]{32}$'))),
      );
    },
  );

  test('logs attempt failure and final failure separately', () async {
    final adapter = _FinalFailureAdapter();
    final client = ApiClient(tokenProvider: () async => 'private-token');
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      client.getJson('/api/v1/providers/private-provider-id/quotes'),
      throwsA(isA<ApiException>()),
    );

    final attemptFailure = sink.singleNamed('api_attempt_failure');
    final finalFailure = sink.singleNamed('api_final_failure');
    expect(attemptFailure.attributes['statusCode'], 503);
    expect(finalFailure.attributes['statusCode'], 503);
    expect(attemptFailure.attributes['attempt'], 1);
    expect(finalFailure.attributes['attempt'], 1);
    expect(
      attemptFailure.attributes['clientRequestId'],
      finalFailure.attributes['clientRequestId'],
    );
    expect(
      finalFailure.attributes['routeTemplate'],
      '/api/v1/providers/:provider/quotes',
    );
    expect(
      finalFailure.attributes['backendRequestId'],
      'backend-request-final',
    );
    expect(finalFailure.attributes['durationMs'], isA<int>());
  });
}

class _SuccessAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'X-Request-Id': ['backend-request-1'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshThenSuccessAdapter implements HttpClientAdapter {
  final List<String> clientRequestIds = [];
  var _attempt = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _attempt += 1;
    clientRequestIds.add(
      options.headers[ApiClient.clientRequestIdHeader]!.toString(),
    );
    if (_attempt == 1) {
      return ResponseBody.fromString(
        '{"message":"expired"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'X-Request-Id': ['backend-request-attempt-1'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'X-Request-Id': ['backend-request-attempt-2'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ClientRequestIdCaptureAdapter implements HttpClientAdapter {
  final List<String> clientRequestIds = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    clientRequestIds.add(
      options.headers[ApiClient.clientRequestIdHeader]!.toString(),
    );
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FinalFailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"message":"private backend failure detail"}',
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'X-Request-Id': ['backend-request-final'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CollectingSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) {
    events.add(event);
  }

  Iterable<AppLogEvent> named(String name) {
    return events.where((event) => event.name == name);
  }

  AppLogEvent singleNamed(String name) => named(name).single;
}
