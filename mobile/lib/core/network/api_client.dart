import 'package:dio/dio.dart';

import '../config/api_config.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({required TokenProvider tokenProvider})
    : _tokenProvider = tokenProvider,
      dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenProvider _tokenProvider;

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final response = await dio.get<Object?>(path);
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.post<Object?>(path, data: data);
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Map<String, dynamic> _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException('استجابة غير متوقعة من الخادم.');
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (statusCode == 401) {
      return const ApiException('بيانات الدخول غير صحيحة أو انتهت الجلسة.');
    }

    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is String) {
        return ApiException(message);
      }
      if (message is List && message.isNotEmpty) {
        return ApiException(message.first.toString());
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiException('تعذر الاتصال بالخادم. تأكد من تشغيل الخلفية.');
    }

    return const ApiException('حدث خطأ، يرجى المحاولة مرة أخرى.');
  }

  final String message;

  @override
  String toString() => message;
}
