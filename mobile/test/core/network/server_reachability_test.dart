import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// D84: the cause of a failed connection is measured from the failure, and
// «بدون نت» is said only when the phone's own network refused.

DioException _dio(DioExceptionType type, {Object? error, Response? response}) =>
    DioException(
      requestOptions: RequestOptions(path: '/api/v1/live'),
      type: type,
      error: error,
      response: response,
    );

void main() {
  group('classifyTransportFailure', () {
    test('a timeout is the server being slow, not a missing net', () {
      expect(
        classifyTransportFailure(_dio(DioExceptionType.receiveTimeout)),
        ReachabilityCause.timeout,
      );
    });

    test('an unreachable network is the phone without net', () {
      expect(
        classifyTransportFailure(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException(
              'Connection failed',
              osError: OSError('Network is unreachable', 101),
            ),
          ),
        ),
        ReachabilityCause.noNetwork,
      );
    });

    test('a failed host lookup is a name problem on this network', () {
      expect(
        classifyTransportFailure(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException(
              "Failed host lookup: 'api.example.test'",
            ),
          ),
        ),
        ReachabilityCause.dns,
      );
    });

    test('a refused connection is the server, not the net', () {
      expect(
        classifyTransportFailure(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException(
              'Connection refused',
              osError: OSError('Connection refused', 111),
            ),
          ),
        ),
        ReachabilityCause.refused,
      );
    });

    test('a handshake failure is the secure connection', () {
      expect(
        classifyTransportFailure(
          _dio(
            DioExceptionType.unknown,
            error: const HandshakeException('Handshake error in client'),
          ),
        ),
        ReachabilityCause.tls,
      );
      expect(
        classifyTransportFailure(_dio(DioExceptionType.badCertificate)),
        ReachabilityCause.tls,
      );
    });

    test('a server answer, whatever its status, is not a transport failure', () {
      final options = RequestOptions(path: '/x');
      expect(
        classifyTransportFailure(
          _dio(
            DioExceptionType.badResponse,
            response: Response<Object?>(requestOptions: options, statusCode: 500),
          ),
        ),
        isNull,
      );
      expect(classifyTransportFailure(_dio(DioExceptionType.cancel)), isNull);
    });
  });

  group('ApiException wording follows the cause', () {
    test('a timeout says the server is slow', () {
      final exception = ApiException.fromDio(
        _dio(DioExceptionType.receiveTimeout),
      );
      expect(exception.isNetworkFailure, isTrue);
      expect(exception.transportCause, ReachabilityCause.timeout);
      expect(exception.message, 'الخادم تأخر في الرد. جرّب مرة ثانية بعد شوي.');
    });

    test('no network says so', () {
      final exception = ApiException.fromDio(
        _dio(
          DioExceptionType.connectionError,
          error: const SocketException(
            'x',
            osError: OSError('Network is unreachable', 101),
          ),
        ),
      );
      expect(exception.transportCause, ReachabilityCause.noNetwork);
      expect(exception.message, 'ما فيه نت في الجوال الحين. شغّل النت وجرّب مرة ثانية.');
    });

    test('an unrecognised transport failure keeps the generic wording', () {
      final exception = ApiException.fromDio(
        _dio(DioExceptionType.connectionError, error: Exception('Socket closed')),
      );
      expect(exception.transportCause, ReachabilityCause.unknown);
      expect(exception.message, aarastBackendConnectionErrorMessage);
    });
  });

  group('ServerReachability', () {
    test('a transport failure marks it unreachable with the cause', () {
      final reachability = ServerReachability(clock: () => DateTime(2026, 11, 3));
      var notified = 0;
      reachability.addListener(() => notified++);

      reachability.observe(_dio(DioExceptionType.connectionTimeout));

      expect(reachability.reachable, isFalse);
      expect(reachability.lastFailure?.cause, ReachabilityCause.timeout);
      expect(reachability.lastFailure?.path, '/api/v1/live');
      expect(notified, 1);
    });

    test('any answer from the server makes it reachable again', () {
      final reachability = ServerReachability(clock: () => DateTime(2026, 11, 3));
      reachability.observe(_dio(DioExceptionType.connectionTimeout));
      var notified = 0;
      reachability.addListener(() => notified++);

      final options = RequestOptions(path: '/x');
      reachability.observe(
        _dio(
          DioExceptionType.badResponse,
          response: Response<Object?>(requestOptions: options, statusCode: 500),
        ),
      );

      expect(reachability.reachable, isTrue);
      expect(reachability.lastReachedAt, DateTime(2026, 11, 3));
      // The last failure stays readable for the report.
      expect(reachability.lastFailure?.cause, ReachabilityCause.timeout);
      expect(notified, 1);
    });

    test('a cancelled request changes nothing', () {
      final reachability = ServerReachability();
      reachability.observe(_dio(DioExceptionType.cancel));
      expect(reachability.reachable, isTrue);
      expect(reachability.lastFailure, isNull);
    });
  });
}
