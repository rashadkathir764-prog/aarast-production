import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../diagnostics/app_logger.dart';

typedef TokenProvider = Future<String?> Function();
typedef SessionRefresher = Future<bool> Function();

const aarastBackendConnectionErrorMessage =
    'تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.';
// A number without WhatsApp and a channel outage look the same to the server
// (field test Q07), so the message names what the user can check.
const aarastOtpDeliveryUnavailableMessage =
    'تعذر إرسال رمز التحقق عبر واتساب. تأكد أن الرقم صحيح وعليه واتساب، ثم حاول مرة أخرى.';
const _requestSessionGenerationKey = 'aarast_request_session_generation';
const _requestContextGenerationKey = 'aarast_request_context_generation';
const _requestClientIdKey = 'aarast_client_request_id';
const _requestAttemptKey = 'aarast_request_attempt';
const _requestAttemptTimerKey = 'aarast_request_attempt_timer';
const _requestAttemptFailureLoggedKey = 'aarast_request_attempt_failure_logged';
const _requestResponseLoggedKey = 'aarast_request_response_logged';
const _requestFinalFailureLoggedKey = 'aarast_request_final_failure_logged';

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
          final requestSessionGeneration =
              options.extra[_requestSessionGenerationKey] as int? ??
              _sessionGeneration;
          options.extra[_requestSessionGenerationKey] =
              requestSessionGeneration;
          options.extra[_requestContextGenerationKey] =
              options.extra[_requestContextGenerationKey] as int? ??
              _contextGeneration;
          _beginRequestAttempt(options);
          final token = await _tokenProvider();
          if (_requestUsesAStaleScope(options)) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error:
                    'The account session or context changed before the request started',
              ),
            );
            return;
          }
          if (token != null &&
              token.isNotEmpty &&
              options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          _logRequest(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (_requestUsesAStaleScope(response.requestOptions)) {
            final error = DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.cancel,
              error:
                  'The account context changed before the response completed',
            );
            _logAttemptFailure(error);
            _logFinalFailure(error);
            handler.reject(error);
            return;
          }
          _logResponse(response);
          handler.next(response);
        },
        onError: (error, handler) async {
          _logAttemptFailure(error);
          if (await _requestUsesAStaleSessionToken(error.requestOptions)) {
            _logFinalFailure(error);
            handler.next(error);
            return;
          }
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 || statusCode == 403) {
            _logAuthRejection(
              error,
              statusCode == 401 ? 'api_unauthorized' : 'api_forbidden',
            );
          }
          // A 401 outside the auth endpoints, or from the read-only session
          // restore endpoint, means the access token may need one refresh.
          // Auth mutations remain excluded to prevent refresh loops.
          if (_canRefresh(error)) {
            try {
              final refreshed = await _refreshOnce();
              if (_requestUsesAStaleScope(error.requestOptions)) {
                _logFinalFailure(error);
                handler.next(error);
                return;
              }
              if (refreshed) {
                final options = error.requestOptions;
                final token = await _tokenProvider();
                if (_requestUsesAStaleScope(options)) {
                  _logFinalFailure(error);
                  handler.next(error);
                  return;
                }
                options.extra[_refreshRetryKey] = true;
                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                _logRetry(error);
                handler.resolve(await dio.fetch<Object?>(options));
                return;
              }
            } on Object {
              _logFinalFailure(error);
              handler.next(error);
              return;
            }
            onSessionExpired?.call();
          } else if (_isFinalUnauthorized(error)) {
            onSessionExpired?.call();
          }
          _logFinalFailure(error);
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final Dio _uploadDio;
  final TokenProvider _tokenProvider;
  static const clientRequestIdHeader = 'X-Client-Request-Id';
  static const backendRequestIdHeader = 'X-Request-Id';
  static const _refreshRetryKey = 'aarast_refresh_retried';
  static final Random _secureRequestIdRandom = Random.secure();
  static final RegExp _safeRequestIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$',
  );
  Future<bool>? _refreshInFlight;
  int _sessionGeneration = 0;
  int _contextGeneration = 0;
  String? _sessionIdentity;
  String? _contextIdentity;

  SessionRefresher? refreshSession;

  /// Wired by the auth layer after construction; invoked when any
  /// non-auth request returns 401 so the app can force a clean re-login.
  void Function()? onSessionExpired;

  void _beginRequestAttempt(RequestOptions options) {
    final requestId =
        _safeRequestId(options.extra[_requestClientIdKey]?.toString()) ??
        _safeRequestId(_requestHeader(options, clientRequestIdHeader)) ??
        _newClientRequestId();
    final attempt = (options.extra[_requestAttemptKey] as int? ?? 0) + 1;

    options.headers.removeWhere(
      (name, _) => name.toLowerCase() == clientRequestIdHeader.toLowerCase(),
    );
    options.headers[clientRequestIdHeader] = requestId;
    options.extra[_requestClientIdKey] = requestId;
    options.extra[_requestAttemptKey] = attempt;
    options.extra[_requestAttemptTimerKey] = Stopwatch()..start();
  }

  void _logRequest(RequestOptions options) {
    _logApiEvent(
      name: 'api_request',
      level: AppLogLevel.debug,
      attributes: _baseRequestAttributes(options),
    );
  }

  void _logResponse(Response<Object?> response) {
    final options = response.requestOptions;
    final attempt = _attempt(options);
    if (options.extra[_requestResponseLoggedKey] == attempt) return;
    options.extra[_requestResponseLoggedKey] = attempt;
    _logApiEvent(
      name: 'api_response',
      level: AppLogLevel.info,
      attributes: {
        ..._baseRequestAttributes(options),
        'statusCode': response.statusCode ?? 0,
        'durationMs': _stopwatchElapsedMilliseconds(options),
        'backendRequestId': ?_backendRequestId(response.headers),
      },
    );
  }

  void _logAttemptFailure(DioException error) {
    final options = error.requestOptions;
    final attempt = _attempt(options);
    if (options.extra[_requestAttemptFailureLoggedKey] == attempt) return;
    options.extra[_requestAttemptFailureLoggedKey] = attempt;
    _logApiEvent(
      name: 'api_attempt_failure',
      level: AppLogLevel.warning,
      attributes: _failureAttributes(error),
    );
  }

  void _logFinalFailure(DioException error) {
    final options = error.requestOptions;
    if (options.extra[_requestFinalFailureLoggedKey] == true) return;
    options.extra[_requestFinalFailureLoggedKey] = true;
    _logApiEvent(
      name: 'api_final_failure',
      level: AppLogLevel.error,
      attributes: _failureAttributes(error),
    );
  }

  void _logRetry(DioException error) {
    _logApiEvent(
      name: 'api_retry',
      level: AppLogLevel.info,
      attributes: {
        ..._failureAttributes(error),
        'nextAttempt': _attempt(error.requestOptions) + 1,
        'reason': 'access_token_refreshed',
      },
    );
  }

  void _logAuthRejection(DioException error, String eventName) {
    _logApiEvent(
      name: eventName,
      level: AppLogLevel.warning,
      attributes: _failureAttributes(error),
    );
  }

  void _logApiEvent({
    required String name,
    required AppLogLevel level,
    required Map<String, Object?> attributes,
  }) {
    AppLogger.global?.log(
      level: level,
      category: AppLogCategory.api,
      name: name,
      attributes: attributes,
    );
  }

  Map<String, Object?> _baseRequestAttributes(RequestOptions options) {
    final logger = AppLogger.global;
    final routeTemplate =
        logger?.sanitizeRouteTemplate(options.uri.path) ?? 'unavailable';
    final clientRequestId =
        _safeRequestId(options.extra[_requestClientIdKey]?.toString()) ??
        'unavailable';
    return {
      'method': options.method.toUpperCase(),
      'routeTemplate': routeTemplate,
      'attempt': _attempt(options),
      'clientRequestId': clientRequestId,
      'userId': ?_sessionIdentity,
      'contextKey': ?_contextIdentity,
      'weddingPlanId': ?_planIdFromContextKey(_contextIdentity),
    };
  }

  Map<String, Object?> _failureAttributes(DioException error) {
    return {
      ..._baseRequestAttributes(error.requestOptions),
      'statusCode': error.response?.statusCode ?? 0,
      'durationMs': _stopwatchElapsedMilliseconds(error.requestOptions),
      'errorType': error.type.name,
      'backendRequestId': ?_backendRequestId(error.response?.headers),
    };
  }

  static int _attempt(RequestOptions options) {
    return options.extra[_requestAttemptKey] as int? ?? 1;
  }

  static int _stopwatchElapsedMilliseconds(RequestOptions options) {
    final stopwatch = options.extra[_requestAttemptTimerKey] as Stopwatch?;
    stopwatch?.stop();
    return stopwatch?.elapsedMilliseconds ?? 0;
  }

  static String? _requestHeader(RequestOptions options, String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) {
        return entry.value?.toString();
      }
    }
    return null;
  }

  static String? _backendRequestId(Headers? headers) {
    if (headers == null) return null;
    final normalizedName = backendRequestIdHeader.toLowerCase();
    for (final entry in headers.map.entries) {
      if (entry.key.toLowerCase() != normalizedName || entry.value.isEmpty) {
        continue;
      }
      return _safeRequestId(entry.value.first);
    }
    return null;
  }

  static String? _safeRequestId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || !_safeRequestIdPattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static String _newClientRequestId() {
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index += 1) {
      buffer.write(
        _secureRequestIdRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
      );
    }
    return buffer.toString();
  }

  void bindSessionIdentity(String? sessionIdentity) {
    if (_sessionIdentity == sessionIdentity) return;
    _sessionIdentity = sessionIdentity;
    _sessionGeneration += 1;
    _refreshInFlight = null;
  }

  /// Invalidates requests that started for a previous selected workspace.
  /// The access token remains account-scoped; only response delivery changes.
  void bindContextIdentity(String? contextIdentity) {
    if (_contextIdentity == contextIdentity) return;
    _contextIdentity = contextIdentity;
    _contextGeneration += 1;
  }

  static String? _planIdFromContextKey(String? contextKey) {
    if (contextKey == null || !contextKey.startsWith('plan:')) return null;
    final parts = contextKey.split(':');
    if (parts.length < 3) return null;
    return parts.sublist(1, parts.length - 1).join(':');
  }

  Future<String?> readCurrentAccessToken() => _tokenProvider();

  Future<bool> _requestUsesAStaleSessionToken(RequestOptions options) async {
    if (_requestUsesAStaleScope(options)) return true;
    final requestAuthorization = options.headers['Authorization']?.toString();
    if (requestAuthorization == null || requestAuthorization.isEmpty) {
      return false;
    }
    final currentToken = await _tokenProvider();
    if (currentToken == null || currentToken.isEmpty) return true;
    return requestAuthorization != 'Bearer $currentToken';
  }

  bool _requestUsesAStaleScope(RequestOptions options) {
    final requestSessionGeneration =
        options.extra[_requestSessionGenerationKey] as int?;
    if (requestSessionGeneration != null &&
        requestSessionGeneration != _sessionGeneration) {
      return true;
    }
    if (_isAccountSessionRestoreRequest(options)) return false;
    final requestContextGeneration =
        options.extra[_requestContextGenerationKey] as int?;
    return requestContextGeneration != null &&
        requestContextGeneration != _contextGeneration;
  }

  bool _isAccountSessionRestoreRequest(RequestOptions request) {
    return request.method.toUpperCase() == 'GET' &&
        request.path == '/api/v1/auth/me';
  }

  bool _canRefresh(DioException error) {
    final request = error.requestOptions;
    return error.response?.statusCode == 401 &&
        (!request.path.startsWith('/api/v1/auth') ||
            _isAccountSessionRestoreRequest(request)) &&
        request.extra[_refreshRetryKey] != true &&
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

  /// Uses credentials captured by a terminating session after local storage
  /// has already been cleared. The token is memory-only and is never added to
  /// diagnostics.
  Future<Map<String, dynamic>> postJsonWithBearer(
    String path,
    Map<String, dynamic> data, {
    required String bearerToken,
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await dio.post<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(headers: {'Authorization': 'Bearer $bearerToken'}),
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
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

  Future<Map<String, dynamic>> putJsonCancellable(
    String path,
    Map<String, dynamic> data, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await dio.put<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
      );
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

  Future<Map<String, dynamic>> deleteJsonWithData(
    String path,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {
    try {
      final response = await dio.delete<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: bearerToken == null || bearerToken.isEmpty
            ? null
            : Options(headers: {'Authorization': 'Bearer $bearerToken'}),
      );
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
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.isNetworkFailure = false,
    this.statusCode,
    this.serverCode,
    this.retryAfterSeconds,
  });

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final serverCode = _extractServerCode(data);
    final serverMessage = _extractServerMessage(data);
    final retryAfterSeconds = _extractRetryAfterSeconds(data);

    // Stable product error codes are translated at the network boundary so
    // screens that call repositories directly never leak backend English.
    // Keep the code as well so each feature can offer the correct safe action.
    final localizedMessage = _localizedServerMessage(serverCode);
    if (localizedMessage != null) {
      return ApiException(
        localizedMessage,
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
      );
    }

    if (statusCode == 401) {
      return ApiException(
        'بيانات الدخول غير صحيحة أو انتهت الجلسة.',
        statusCode: 401,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
      );
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

    // Framework validation and provider failures may carry English details.
    // Stable codes above are translated precisely; every other auth failure
    // stays deliberately generic and Arabic-only at the network boundary.
    if (_isAuthRequest(error.requestOptions.path)) {
      return ApiException(
        _genericAuthMessage(statusCode),
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
      );
    }

    // V1 checklist 5.4: the server's own Arabic messages reach the user; an
    // English framework or validation detail never does. It becomes an
    // Arabic message that says what happened and what to do.
    if (serverMessage != null && _hasArabic(serverMessage)) {
      return ApiException(
        serverMessage.trim(),
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
      );
    }
    if (serverMessage != null &&
        _cleanServerMessage(serverMessage) ==
            aarastBackendConnectionErrorMessage) {
      return ApiException(
        aarastBackendConnectionErrorMessage,
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
      );
    }

    return ApiException(
      _arabicMessageForStatus(statusCode),
      statusCode: statusCode,
      serverCode: serverCode,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  final String message;
  final bool isNetworkFailure;
  final int? statusCode;
  final String? serverCode;
  final int? retryAfterSeconds;

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

  static final _arabicLetter = RegExp(r'[؀-ۿ]');

  static bool _hasArabic(String message) => _arabicLetter.hasMatch(message);

  /// An Arabic message with a clear next step, by what kind of failure it is.
  static String _arabicMessageForStatus(int? statusCode) {
    return switch (statusCode) {
      400 || 422 => 'تعذّر الحفظ: راجع البيانات المدخلة ثم حاول مرة أخرى.',
      403 => 'لا تملك صلاحية لهذا الإجراء. اطلب الصلاحية من صاحب الخطة.',
      404 => 'العنصر غير موجود أو لم يعد متاحًا. حدّث الصفحة.',
      409 => 'تغيّرت البيانات قبل الحفظ. حدّث الصفحة ثم حاول مرة أخرى.',
      413 => 'الملف أكبر من المسموح. اختر ملفًا أصغر.',
      429 => 'طلبات كثيرة في وقت قصير. انتظر قليلًا ثم حاول مرة أخرى.',
      final code? when code >= 500 =>
        'حدث خطأ في الخادم. حاول بعد قليل، وإن تكرر فتواصل مع الدعم.',
      _ => 'حدث خطأ، يرجى المحاولة مرة أخرى.',
    };
  }

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

  static String? _extractServerCode(Object? data) {
    if (data is! Map) return null;
    final directCode = data['code'];
    if (directCode is String && directCode.trim().isNotEmpty) {
      return directCode.trim();
    }
    final nestedMessage = data['message'];
    if (nestedMessage is Map) {
      final nestedCode = nestedMessage['code'];
      if (nestedCode is String && nestedCode.trim().isNotEmpty) {
        return nestedCode.trim();
      }
    }
    return null;
  }

  static String? _extractServerMessage(Object? data) {
    if (data is! Map) return null;
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }
    if (message is Map) {
      final nestedMessage = message['message'];
      if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
        return nestedMessage;
      }
    }
    return null;
  }

  static int? _extractRetryAfterSeconds(Object? data) {
    if (data is! Map) return null;
    final raw = data['retryAfterSeconds'];
    final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;

    final nestedMessage = data['message'];
    if (nestedMessage is Map) {
      final nestedRaw = nestedMessage['retryAfterSeconds'];
      final nested = nestedRaw is int
          ? nestedRaw
          : int.tryParse(nestedRaw?.toString() ?? '');
      if (nested != null && nested > 0) return nested;
    }
    return null;
  }

  static String? _localizedServerMessage(String? code) {
    return switch (code) {
      'TASK_PERMISSION_REVOKED' => 'لم تعد لديك صلاحية لتنفيذ هذه المهمة',
      // V1 checklist 4.10: private costs and tasks.
      'COST_PRIVACY_NOT_ALLOWED' =>
        'التكلفة الخاصة متاحة لصاحب الخطة والشريك فقط.',
      'COST_PRIVACY_AT_CREATION_ONLY' =>
        'التكلفة المشتركة لا تصبح خاصة. اختر "تكلفة خاصة بي" عند إضافتها.',
      'TASK_PRIVACY_NOT_ALLOWED' =>
        'المهمة الخاصة متاحة لصاحب الخطة والشريك فقط.',
      'TASK_PRIVACY_AT_CREATION_ONLY' =>
        'المهمة المشتركة لا تصبح خاصة. اختر "مهمة خاصة بي" عند إضافتها.',
      'TASK_PRIVATE_ASSIGNMENT' =>
        'المهمة الخاصة تبقى لك وحدك. شاركها مع الخطة أولًا ثم اختر المسؤول.',
      // V1 checklist 4.12: the planning assistant.
      'ASSISTANT_CONSENT_REQUIRED' =>
        'وافق على إرسال بيانات خطتك للمساعد أولًا.',
      'ASSISTANT_OWNER_OR_PARTNER_ONLY' =>
        'المساعد متاح لصاحب الخطة وشريكه فقط.',
      'ASSISTANT_DAILY_LIMIT' => 'انتهت أسئلة اليوم. عد غدًا.',
      'ASSISTANT_DISABLED' => 'المساعد غير مفعّل بعد.',
      'ASSISTANT_BUDGET_EXHAUSTED' =>
        'المساعد متوقف مؤقتًا هذا الشهر. جرّب الشهر القادم.',
      'ASSISTANT_BUSY' => 'المساعد مشغول الآن. حاول بعد قليل.',
      'ASSISTANT_UNAVAILABLE' =>
        'المساعد غير متاح الآن. حاول لاحقًا، وإن تكرر فتواصل مع الدعم.',
      'INVALID_CREDENTIALS' => 'تعذر تسجيل الدخول بهذه البيانات.',
      'OTP_DELIVERY_UNAVAILABLE' => aarastOtpDeliveryUnavailableMessage,
      'PHONE_VERIFICATION_REQUIRED' =>
        'يحتاج حساب التطبيق إلى تأكيد رقم الهاتف.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'هذا الرقم مسجل بالفعل. انتقل إلى تسجيل الدخول أو استعد كلمة المرور.',
      'ADMIN_APP_PASSWORD_ALREADY_SET' =>
        'تم إعداد حساب التطبيق لهذا الرقم بالفعل. انتقل إلى تسجيل الدخول أو استعد كلمة مرور التطبيق.',
      'OTP_INVALID_OR_EXPIRED' =>
        'رمز التحقق غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا وحاول مرة أخرى.',
      'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، لكن لا يوجد حساب تطبيق مرتبط به. أنشئ حسابًا جديدًا للمتابعة.',
      'ACCOUNT_DISABLED_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، لكن الحساب معطل حاليًا. تواصل مع الدعم.',
      'INVITE_NOT_FOUND_FOR_PHONE' =>
        'لا توجد دعوة فعّالة مرتبطة بهذا الرقم. تأكد من الرقم أو اطلب دعوة جديدة.',
      'INVITE_ACCOUNT_SETUP_REQUIRED' =>
        'أنشئ اسمًا وكلمة مرور لحساب المساهم ثم أعد تأكيد الرمز نفسه.',
      _ => null,
    };
  }

  static bool _isAuthRequest(String path) {
    return path == '/api/v1/auth' || path.startsWith('/api/v1/auth/');
  }

  static String _genericAuthMessage(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return 'تعذر إكمال طلب المصادقة. تحقق من البيانات وحاول مرة أخرى.';
    }
    if (statusCode == 429) {
      return 'طلبات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مرة أخرى.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'تعذر إكمال طلب المصادقة الآن. حاول مرة أخرى بعد قليل.';
    }
    return 'تعذر إكمال طلب المصادقة. حاول مرة أخرى.';
  }
}
