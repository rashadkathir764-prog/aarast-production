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

    test('typed cooldown errors preserve the server retry window', () {
      final requestOptions = RequestOptions(
        path: '/api/v1/wedding-plans/plan-1/invites/invite-1/reissue',
      );
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 429,
            data: const {
              'statusCode': 429,
              'code': 'INVITE_REISSUE_COOLDOWN',
              'message': 'Invite delivery was attempted recently.',
              'retryAfterSeconds': 37,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.serverCode, 'INVITE_REISSUE_COOLDOWN');
      expect(exception.retryAfterSeconds, 37);
      expect(exception.isAmbiguousMutationFailure, isFalse);
    });

    test('401 keeps the typed server code and hides credential details', () {
      final requestOptions = RequestOptions(path: '/api/v1/auth/login');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: const {
              'statusCode': 401,
              'code': 'INVALID_CREDENTIALS',
              'message': 'Invalid credentials',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.statusCode, 401);
      expect(exception.serverCode, 'INVALID_CREDENTIALS');
      expect(exception.message, 'تعذر تسجيل الدخول بهذه البيانات.');
      expect(exception.message, isNot(contains('Invalid')));
    });

    test('401 preserves non-credential auth guidance codes', () {
      final requestOptions = RequestOptions(path: '/api/v1/auth/login');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: const {
              'statusCode': 401,
              'code': 'PHONE_VERIFICATION_REQUIRED',
              'message': 'Phone verification is required',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.serverCode, 'PHONE_VERIFICATION_REQUIRED');
      expect(exception.statusCode, 401);
    });

    test('OTP transport failure keeps its code and uses product Arabic', () {
      final requestOptions = RequestOptions(path: '/api/v1/auth/login');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 503,
            data: const {
              'statusCode': 503,
              'code': 'OTP_DELIVERY_UNAVAILABLE',
              'message': 'OTP delivery is temporarily unavailable',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.serverCode, 'OTP_DELIVERY_UNAVAILABLE');
      expect(exception.statusCode, 503);
      expect(
        exception.message,
        'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
      );
      expect(exception.message, isNot(contains('OTP delivery')));
    });

    test('OTP transport failure code is read from a nested envelope', () {
      final requestOptions = RequestOptions(
        path: '/api/v1/auth/password-reset/request',
      );
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 503,
            data: const {
              'statusCode': 503,
              'message': {
                'code': 'OTP_DELIVERY_UNAVAILABLE',
                'message': 'OTP delivery is temporarily unavailable',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.serverCode, 'OTP_DELIVERY_UNAVAILABLE');
      expect(
        exception.message,
        'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
      );
    });

    test('untyped English 401 copy is replaced by generic Arabic', () {
      final requestOptions = RequestOptions(path: '/api/v1/auth/login');
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: const {'message': 'Invalid credentials'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.statusCode, 401);
      expect(exception.serverCode, isNull);
      expect(exception.message, 'بيانات الدخول غير صحيحة أو انتهت الجلسة.');
      expect(exception.message, isNot(contains('Invalid')));
    });

    test('untyped English auth validation copy is replaced by Arabic', () {
      final requestOptions = RequestOptions(
        path: '/api/v1/auth/password-reset/confirm',
      );
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 400,
            data: const {
              'message': [
                'newPassword must be longer than or equal to 6 characters',
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.statusCode, 400);
      expect(exception.message, contains('تحقق من البيانات'));
      expect(exception.message, isNot(contains('newPassword')));
      expect(exception.message, isNot(contains('characters')));
    });

    test('post-proof missing account guidance is always Arabic', () {
      final requestOptions = RequestOptions(
        path: '/api/v1/auth/password-reset/confirm',
      );
      final exception = ApiException.fromDio(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 404,
            data: const {
              'statusCode': 404,
              'code': 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
              'message': 'No account exists for this verified phone',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(exception.serverCode, 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF');
      expect(exception.message, contains('لا يوجد حساب تطبيق'));
      expect(exception.message, contains('أنشئ حسابًا'));
      expect(exception.message, isNot(contains('No account')));
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
