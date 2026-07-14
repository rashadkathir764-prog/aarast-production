import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/cache_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException backend error copy', () {
    test('network failures use the required product copy', () {
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/providers'),
          type: DioExceptionType.connectionError,
          error: Exception('Socket closed'),
        ),
      );

      expect(exception.message, aarastBackendConnectionErrorMessage);
      expect(exception.isNetworkFailure, isTrue);
      expect(exception.isAmbiguousMutationFailure, isTrue);
    });

    test('send timeout is an ambiguous mutation failure', () {
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/costs'),
          type: DioExceptionType.sendTimeout,
        ),
      );

      expect(exception.isNetworkFailure, isTrue);
      expect(exception.isAmbiguousMutationFailure, isTrue);
    });

    test('server errors preserve status and are ambiguous for mutations', () {
      final requestOptions = RequestOptions(path: '/api/v1/costs');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.statusCode, 500);
      expect(exception.isNetworkFailure, isFalse);
      expect(exception.isAmbiguousMutationFailure, isTrue);
      expect(CachePolicy.shouldQueueWrite(exception), isFalse);
      expect(CachePolicy.shouldQueueReplay(exception), isTrue);
    });

    test('client errors are never ambiguous mutation failures', () {
      final requestOptions = RequestOptions(path: '/api/v1/costs');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 422,
            data: const {'message': 'المبلغ غير صحيح'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.statusCode, 422);
      expect(exception.isAmbiguousMutationFailure, isFalse);
      expect(CachePolicy.shouldQueueWrite(exception), isFalse);
      expect(CachePolicy.shouldQueueReplay(exception), isFalse);
    });

    test('technical Cannot route responses are hidden from users', () {
      final requestOptions = RequestOptions(path: '/providers');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 404,
            data: const {'message': 'Cannot GET /providers'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.message, aarastBackendConnectionErrorMessage);
      expect(exception.message, isNot(contains('Cannot GET')));
    });
  });
}
