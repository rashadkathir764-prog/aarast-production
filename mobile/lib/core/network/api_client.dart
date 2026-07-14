import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

typedef TokenProvider = Future<String?> Function();
typedef SessionRefresher = Future<bool> Function();

const aarastBackendConnectionErrorMessage =
    'تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.';

class ApiClient {
  ApiClient({required TokenProvider tokenProvider, Dio? uploadDio})
    : _tokenProvider = tokenProvider,
      _uploadDio =
          uploadDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
            ),
          ),
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
          final requestSessionGeneration = _sessionGeneration;
          final token = await _tokenProvider();
          if (requestSessionGeneration != _sessionGeneration) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'The account session changed before the request started',
              ),
            );
            return;
          }
          if (token != null &&
              token.isNotEmpty &&
              options.headers['Authorization'] == null) {
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
        onError: (error, handler) async {
          _debugAuthLoginStatus(
            error.requestOptions.path,
            error.response?.statusCode,
          );
          if (await _requestUsesAStaleSessionToken(error.requestOptions)) {
            handler.next(error);
            return;
          }
          // A 401 outside the auth endpoints means the session token is no
          // longer valid — every screen would otherwise keep failing with
          // misleading errors until app restart.
          if (_canRefresh(error)) {
            try {
              final refreshed = await _refreshOnce();
              if (refreshed) {
                final options = error.requestOptions;
                options.extra[_refreshRetryKey] = true;
                final token = await _tokenProvider();
                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                handler.resolve(await dio.fetch<Object?>(options));
                return;
              }
            } on Object {
              handler.next(error);
              return;
            }
            onSessionExpired?.call();
          } else if (_isFinalUnauthorized(error)) {
            onSessionExpired?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final Dio _uploadDio;
  final TokenProvider _tokenProvider;
  static const clientRequestIdHeader = 'X-Client-Request-Id';
  static const _refreshRetryKey = 'aarast_refresh_retried';
  Future<bool>? _refreshInFlight;
  int _sessionGeneration = 0;
  String? _sessionIdentity;

  SessionRefresher? refreshSession;

  /// Wired by the auth layer after construction; invoked when any
  /// non-auth request returns 401 so the app can force a clean re-login.
  void Function()? onSessionExpired;

  void bindSessionIdentity(String? sessionIdentity) {
    if (_sessionIdentity == sessionIdentity) return;
    _sessionIdentity = sessionIdentity;
    _sessionGeneration += 1;
  }

  Future<String?> readCurrentAccessToken() => _tokenProvider();

  Future<bool> _requestUsesAStaleSessionToken(RequestOptions options) async {
    final requestAuthorization = options.headers['Authorization']?.toString();
    if (requestAuthorization == null || requestAuthorization.isEmpty) {
      return false;
    }
    final currentToken = await _tokenProvider();
    if (currentToken == null || currentToken.isEmpty) return true;
    return requestAuthorization != 'Bearer $currentToken';
  }

  bool _canRefresh(DioException error) {
    return error.response?.statusCode == 401 &&
        !error.requestOptions.path.startsWith('/api/v1/auth') &&
        error.requestOptions.extra[_refreshRetryKey] != true &&
        refreshSession != null;
  }

  bool _isFinalUnauthorized(DioException error) {
    return error.response?.statusCode == 401 &&
        !error.requestOptions.path.startsWith('/api/v1/auth');
  }

  Future<bool> _refreshOnce() async {
    final active = _refreshInFlight;
    if (active != null) return active;
    final callback = refreshSession;
    if (callback == null) return false;
    final future = callback();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

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
  ) {
    return _postJson(path, data);
  }

  Future<Map<String, dynamic>> postJsonWithReceiveTimeout(
    String path,
    Map<String, dynamic> data, {
    required Duration receiveTimeout,
  }) {
    return _postJson(path, data, receiveTimeout: receiveTimeout);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> data, {
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await dio.post<Object?>(
        path,
        data: data,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );
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

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.put<Object?>(path, data: data);
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Sends one authenticated mutation with a caller-owned idempotency key.
  ///
  /// The caller must persist [clientRequestId] if a lost response is queued,
  /// so the offline replay reaches the server with the exact same key.
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async {
    final normalizedRequestId = clientRequestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw ArgumentError.value(
        clientRequestId,
        'clientRequestId',
        'must not be empty',
      );
    }
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        options: Options(
          method: method.toUpperCase(),
          headers: {clientRequestIdHeader: normalizedRequestId},
        ),
      );
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

  Future<void> putBytes(
    String url,
    Uint8List bytes, {
    required String contentType,
  }) async {
    try {
      await _uploadDio.put<void>(
        url,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
            'If-None-Match': '*',
          },
        ),
      );
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
    if (!kDebugMode || options.path != '/api/v1/auth/login') return;
    debugPrint(
      '[AarastAuth] baseUrl=${options.baseUrl}; endpoint=${options.path}',
    );
  }

  static void _debugAuthLoginStatus(String path, int? statusCode) {
    if (!kDebugMode || path != '/api/v1/auth/login') return;
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
      return const ApiException(
        'بيانات الدخول غير صحيحة أو انتهت الجلسة.',
        statusCode: 401,
      );
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
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      );
    }

    return ApiException(
      'حدث خطأ، يرجى المحاولة مرة أخرى.',
      statusCode: statusCode,
    );
  }

  final String message;
  final bool isNetworkFailure;
  final int? statusCode;

  bool get isUnauthorized {
    return statusCode == 401 || message.contains('بيانات الدخول');
  }

  /// Whether a mutating request may have reached the server without the
  /// client receiving a durable result. Retrying these failures with the same
  /// client request id is the only safe option for financial writes.
  ///
  /// Client errors are deliberately excluded: validation/permission failures
  /// must be surfaced, not hidden inside the offline queue.
  bool get isAmbiguousMutationFailure {
    final code = statusCode;
    return isNetworkFailure || (code != null && code >= 500 && code <= 599);
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
