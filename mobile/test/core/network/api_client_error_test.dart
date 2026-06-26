import 'package:aarast_mobile/core/network/api_client.dart';
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
