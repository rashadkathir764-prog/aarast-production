import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

typedef TokenProvider = Future<String?> Function();

const aarastBackendConnectionErrorMessage =
    'تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.';

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
          _debugAuthLoginRequest(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          _debugAuthLoginStatus(
            response.requestOptions.path,
            response.statusCode,
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _debugAuthLoginStatus(
            error.requestOptions.path,
            error.response?.statusCode,
          );
          handler.next(error);
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

  Future<List<dynamic>> getJsonList(String path) async {
    try {
      final response = await dio.get<Object?>(path);
      final data = response.data;
      if (data is List) {
        return data;
      }
      throw const ApiException(aarastBackendConnectionErrorMessage);
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

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.patch<Object?>(path, data: data);
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    try {
      final response = await dio.delete<Object?>(path);
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
    throw const ApiException(aarastBackendConnectionErrorMessage);
  }

  static void _debugAuthLoginRequest(RequestOptions options) {
    if (!kDebugMode || options.path != '/auth/login') return;
    debugPrint(
      '[AarastAuth] baseUrl=${options.baseUrl}; endpoint=${options.path}',
    );
  }

  static void _debugAuthLoginStatus(String path, int? statusCode) {
    if (!kDebugMode || path != '/auth/login') return;
    debugPrint(
      '[AarastAuth] statusCode=${statusCode?.toString() ?? 'no response'}',
    );
  }
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.isNetworkFailure = false,
    this.statusCode,
  });

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (statusCode == 401) {
      return const ApiException('بيانات الدخول غير صحيحة أو انتهت الجلسة.');
    }

    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is String) {
        return ApiException(
          _cleanServerMessage(message),
          statusCode: statusCode,
        );
      }
      if (message is List && message.isNotEmpty) {
        return ApiException(
          _cleanServerMessage(message.first.toString()),
          statusCode: statusCode,
        );
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      );
    }

    return const ApiException('حدث خطأ، يرجى المحاولة مرة أخرى.');
  }

  final String message;
  final bool isNetworkFailure;
  final int? statusCode;

  bool get isUnauthorized {
    return statusCode == 401 || message.contains('بيانات الدخول');
  }

  @override
  String toString() => message;

  static String _cleanServerMessage(String message) {
    final normalized = message.trim();
    if (normalized.startsWith('Cannot GET') ||
        normalized.startsWith('Cannot POST') ||
        normalized.startsWith('Cannot PATCH') ||
        normalized.startsWith('Cannot DELETE')) {
      return aarastBackendConnectionErrorMessage;
    }
    return normalized;
  }
}
