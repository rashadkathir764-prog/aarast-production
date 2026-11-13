import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../diagnostics/app_logger.dart';
import '../utils/app_clock.dart';
import 'api_contract.dart';
import 'server_reachability.dart';

typedef TokenProvider = Future<String?> Function();
typedef SessionRefresher = Future<bool> Function();

const aarastBackendConnectionErrorMessage =
    'ما قدرنا نجيب البيانات. جرّب مرة ثانية.';

/// D88: the server answered that it does not know the route («Cannot GET
/// …»): the app is newer than the server. Retrying changes nothing; the
/// server must be updated, and the screen says so instead of «حاول».
const aarastServerOlderMessage =
    'الخادم أقدم من التطبيق. هذي الشاشة تشتغل بعد ما يتحدّث الخادم.';
const aarastServerOlderCode = 'SERVER_OLDER_THAN_APP';
// A number without WhatsApp and a channel outage look the same to the server
// (field test Q07), so the message names what the user can check.
const aarastOtpDeliveryUnavailableMessage =
    'ما قدرنا نرسل الرمز على واتساب. تأكد إن الرقم صحيح وعليه واتساب، وجرّب مرة ثانية.';
const _requestSessionGenerationKey = 'aarast_request_session_generation';
const _requestContextGenerationKey = 'aarast_request_context_generation';
const _requestClientIdKey = 'aarast_client_request_id';
const _requestAttemptKey = 'aarast_request_attempt';
const _requestAttemptTimerKey = 'aarast_request_attempt_timer';
const _requestAttemptFailureLoggedKey = 'aarast_request_attempt_failure_logged';
const _requestResponseLoggedKey = 'aarast_request_response_logged';
const _requestFinalFailureLoggedKey = 'aarast_request_final_failure_logged';

class ApiClient {
  ApiClient({
    required TokenProvider tokenProvider,
    Dio? uploadDio,
    ServerReachability? reachability,
  }) : _tokenProvider = tokenProvider,
       _reachability = reachability,
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
          // D84: the server answered, so the transport works.
          _reachability?.noteReached();
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
          final method = response.requestOptions.method.toUpperCase();
          if (method != 'GET' && method != 'HEAD') {
            _acceptedWrites.add(response.requestOptions.path);
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          _logAttemptFailure(error);
          // D84: an answer of any status is «reached»; a transport failure
          // is recorded with its measured cause.
          _reachability?.observe(error);
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
          // A 401 outside the auth endpoints, from the read-only session
          // restore endpoint, or from a signed-in auth write means the access
          // token may need one refresh. Other auth mutations remain excluded
          // to prevent refresh loops.
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
                // RA-MO-305: the retried request is outside the refresh
                // failure below. Its own answer (a 409, 422 or 403) passes on
                // as the server said it; read as the connection, it lost its
                // code and was queued for a retry that could never succeed.
                final Response<Object?> retried;
                try {
                  retried = await dio.fetch<Object?>(options);
                } on DioException catch (retryFailure) {
                  handler.next(retryFailure);
                  return;
                }
                handler.resolve(retried);
                return;
              }
            } on Object catch (refreshFailure) {
              _logFinalFailure(error);
              // RA-MO-100: the refresh did not reach an answer (no network,
              // a server down). Passing the first 401 on read as the server
              // refusing the session, and opening the app on a weak network
              // signed the person out; it is said as what it is, the
              // connection, and the session stays.
              handler.next(
                DioException(
                  requestOptions: error.requestOptions,
                  type: DioExceptionType.connectionError,
                  error: refreshFailure,
                ),
              );
              return;
            }
            onSessionExpired?.call();
          } else if (_isFinalUnauthorized(error)) {
            onSessionExpired?.call();
          } else if (_isAccountDeletionPending(error)) {
            onAccountDeletionPending?.call();
          } else if (_isAppUpdateRequired(error)) {
            // D93: the server no longer serves this app's contract.
            appUpdateRequired.value = true;
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
  final ServerReachability? _reachability;
  final _acceptedWrites = StreamController<String>.broadcast();

  /// D84 «فحص الاتصال»: one short request to the server's liveness route.
  /// Null when it answered; otherwise the measured failure.
  Future<ReachabilityFailure?> probeLive() async {
    try {
      final response = await dio.get<Object?>(
        '/live',
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 500) {
        return ReachabilityFailure(
          cause: ReachabilityCause.serverError,
          at: appNow(),
          path: '/live',
          detail: 'HTTP $status',
        );
      }
      return null;
    } on DioException catch (error) {
      if (error.response != null) {
        final status = error.response!.statusCode ?? 0;
        if (status < 500) return null;
        return ReachabilityFailure(
          cause: ReachabilityCause.serverError,
          at: appNow(),
          path: '/live',
          detail: 'HTTP $status',
        );
      }
      return ReachabilityFailure(
        cause: classifyTransportFailure(error) ?? ReachabilityCause.unknown,
        at: appNow(),
        path: '/live',
        detail: error.error?.toString() ?? error.message,
      );
    }
  }

  /// The path of every write the server accepted. Whatever is derived from
  /// the plan, such as the home, reads again from this one place, so a screen
  /// that saves never has to know who else shows its data.
  Stream<String> get acceptedWrites => _acceptedWrites.stream;
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

  /// Wired by the auth layer; invoked when the server answers `403
  /// ACCOUNT_DELETION_PENDING` (D63): the account asked to be deleted.
  void Function()? onAccountDeletionPending;

  bool _isAccountDeletionPending(DioException error) {
    final data = error.response?.data;
    return error.response?.statusCode == 403 &&
        data is Map &&
        data['code'] == 'ACCOUNT_DELETION_PENDING';
  }

  /// D93 (RA-BE-01): `426 APP_UPDATE_REQUIRED`, this app is older than the
  /// server serves.
  static bool isAppUpdateRequired(Object error) {
    final response = error is DioException ? error.response : null;
    final data = response?.data;
    return response?.statusCode == 426 &&
        data is Map &&
        data['code'] == appUpdateRequiredCode;
  }

  bool _isAppUpdateRequired(DioException error) => isAppUpdateRequired(error);

  void _beginRequestAttempt(RequestOptions options) {
    final requestId =
        _safeRequestId(options.extra[_requestClientIdKey]?.toString()) ??
        _safeRequestId(_requestHeader(options, clientRequestIdHeader)) ??
        newClientRequestId();
    final attempt = (options.extra[_requestAttemptKey] as int? ?? 0) + 1;

    options.headers.removeWhere(
      (name, _) => name.toLowerCase() == clientRequestIdHeader.toLowerCase(),
    );
    options.headers[clientRequestIdHeader] = requestId;
    // D93: the contract this app was built for, on every request.
    options.headers[apiContractHeader] = '$apiContractVersion';
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

  /// A fresh `X-Client-Request-Id`. A one-off action the person may retry by
  /// hand (RA-BE-71) keeps one for every try, so the server answers a retry
  /// of a request that already happened with its first answer.
  static String newClientRequestId() {
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

  /// Auth writes made from a live session: their 401 can be an expired access
  /// token, unless the server says the password itself was wrong.
  bool _isSignedInAuthWrite(DioException error) {
    final request = error.requestOptions;
    return request.method.toUpperCase() == 'POST' &&
        const {
          '/api/v1/auth/password',
          '/api/v1/auth/phone-change/request',
          '/api/v1/auth/phone-change/confirm',
        }.contains(request.path) &&
        ApiException._extractServerCode(error.response?.data) !=
            'INVALID_CREDENTIALS';
  }

  bool _canRefresh(DioException error) {
    final request = error.requestOptions;
    return error.response?.statusCode == 401 &&
        (!request.path.startsWith('/api/v1/auth') ||
            _isAccountSessionRestoreRequest(request) ||
            _isSignedInAuthWrite(error)) &&
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
    this.phoneProof,
    this.transportCause,
  });

  /// D84: the measured cause when [isNetworkFailure]; null otherwise.
  final ReachabilityCause? transportCause;

  /// The number this sign-in code proved, for signing up without a second
  /// code (ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF); null otherwise.
  final String? phoneProof;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    // D75: a number proven by a sign-in code but with no account comes back
    // with a short proof, so signing up needs no second code.
    final proof = data is Map ? data['phoneProof'] : null;
    final phoneProof = proof is String && proof.isNotEmpty ? proof : null;
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
        phoneProof: phoneProof,
      );
    }

    if (statusCode == 401) {
      return ApiException(
        'بيانات الدخول غلط أو انتهى دخولك.',
        statusCode: 401,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
        phoneProof: phoneProof,
      );
    }

    // D84: a transport failure says what was measured (no net, a slow or
    // refused server, the secure connection) instead of blaming the net.
    final transportCause = classifyTransportFailure(error);
    if (transportCause != null) {
      return ApiException(
        transportCause == ReachabilityCause.unknown
            ? 'ما وصلنا للخادم. تأكد من النت وجرّب مرة ثانية.'
            : '${reachabilityCauseLabel(transportCause)}. '
                  '${reachabilityCauseAdvice(transportCause)}',
        isNetworkFailure: true,
        transportCause: transportCause,
      );
    }

    // Framework validation and provider failures may carry English details.
    // Stable codes above are translated precisely; every other auth failure
    // stays deliberately generic and Arabic-only at the network boundary.
    if (_isAuthRequest(error.requestOptions.path)) {
      // D112 (Q-14): the code limits are the one auth refusal whose words
      // are the server's own: it names the limit that was reached and how
      // long is left, which the phone cannot know («انتظر شوي» was said for
      // a minute's wait and for a day's alike, RA-MO-110).
      final saysTheLimit =
          serverCode != null &&
          serverCode.startsWith('OTP_LIMIT_') &&
          serverMessage != null &&
          hasArabic(serverMessage);
      return ApiException(
        saysTheLimit ? serverMessage.trim() : _genericAuthMessage(statusCode),
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
        phoneProof: phoneProof,
      );
    }

    // V1 checklist 5.4: the server's own Arabic messages reach the user; an
    // English framework or validation detail never does. It becomes an
    // Arabic message that says what happened and what to do.
    if (serverMessage != null && hasArabic(serverMessage)) {
      return ApiException(
        serverMessage.trim(),
        statusCode: statusCode,
        serverCode: serverCode,
        retryAfterSeconds: retryAfterSeconds,
        phoneProof: phoneProof,
      );
    }
    if (serverMessage != null && _isUnknownRoute(serverMessage)) {
      return ApiException(
        aarastServerOlderMessage,
        statusCode: statusCode,
        serverCode: aarastServerOlderCode,
        retryAfterSeconds: retryAfterSeconds,
        phoneProof: phoneProof,
      );
    }

    return ApiException(
      _arabicMessageForStatus(statusCode),
      statusCode: statusCode,
      serverCode: serverCode,
      retryAfterSeconds: retryAfterSeconds,
      phoneProof: phoneProof,
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

  /// RA-MO-29: an answer that says «not now» about the request, never «no»
  /// about the change: a timeout (408), too many requests (429, also the
  /// server's limit on messages, RA-BE-81), and a 401 the session refresh
  /// could not cure (a weak network, or a 429 on the refresh itself; a
  /// refresh the server refused ends the session instead). What waits on the
  /// phone keeps waiting, as for a network failure.
  bool get isNotNow =>
      !isNetworkFailure && const {401, 408, 429}.contains(statusCode);

  @override
  String toString() => message;

  static final _arabicLetter = RegExp(r'[؀-ۿ]');

  /// Whether [message] is words a person may read (V1 checklist 5.4): the
  /// server's Arabic reaches the user, an English detail never does.
  static bool hasArabic(String message) => _arabicLetter.hasMatch(message);

  /// An Arabic message with a clear next step, by what kind of failure it is.
  static String _arabicMessageForStatus(int? statusCode) {
    return switch (statusCode) {
      400 || 422 => 'ما قدرنا نحفظ. راجع اللي كتبته وجرّب مرة ثانية.',
      403 => 'ما عندك صلاحية لهذي. اطلبها من صاحب الخطة.',
      404 => 'هذا ما عاد موجود. ارجع وحدّث الشاشة.',
      409 => 'تغيّرت البيانات قبل ما نحفظ. حدّث الشاشة وجرّب مرة ثانية.',
      413 => 'الملف أكبر من المسموح. اختر ملف أصغر.',
      429 => 'طلبات كثيرة ورا بعض. انتظر شوي وجرّب مرة ثانية.',
      final code? when code >= 500 => 'الخادم ما رد زي ما لازم. جرّب بعد شوي.',
      _ => 'صار خطأ عندنا. جرّب مرة ثانية.',
    };
  }

  static bool _isUnknownRoute(String message) {
    final normalized = message.trim();
    return normalized.startsWith('Cannot GET') ||
        normalized.startsWith('Cannot POST') ||
        normalized.startsWith('Cannot PUT') ||
        normalized.startsWith('Cannot PATCH') ||
        normalized.startsWith('Cannot DELETE');
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
      'TASK_PERMISSION_REVOKED' => 'ما عاد عندك صلاحية على هذي المهمة',
      // B-01, B-02, B-10, B-12: the provider lifecycle.
      'PROVIDER_SERVICE_REQUIRED' => 'اكتب خدمتك وسعرها قبل ما ترسل.',
      'PROVIDER_NOT_AWAITING_CHANGES' =>
        'ملفك وصل فريق المراجعة. اسحب الصفحة عشان تتحدّث حالته.',
      'PROVIDER_NOT_REJECTED' => 'تغيّرت حالة ملفك. اسحب الصفحة عشان تتحدّث.',
      'PROVIDER_JOINING_SERVICE_ONLY' =>
        'قبل الموافقة تعدّل اسم خدمتك وسعرها بس. الخدمات الثانية بعد الموافقة.',
      'PROVIDER_CATEGORY_LOCKED' =>
        'القسم يتغير قبل الموافقة بس. كلّم الدعم لو تحتاج تغيّره.',
      'PROVIDER_CLAIM_PENDING' => 'طلب استلام هذا الملف وصل الإدارة وينتظر.',
      // B-33: a provider hands over or cancels his coming weddings first.
      'PROVIDER_HAS_UPCOMING_BOOKINGS' =>
        'عندك حجوزات مؤكدة جاية. الغها أو سلّمها قبل ما تحذف حسابك.',
      // D63: the 30 days before an account is erased, and its data download.
      'ACCOUNT_DELETION_PENDING' => 'حسابك ينتظر الحذف. تراجع عنه عشان تكمل.',
      // RA-BE-95: said for what it is, not as a missing permission.
      'PROVIDER_NOT_ACTIVE' => 'المزود موقوف الحين، ما يستقبل رسائل ولا طلبات.',
      // RA-BE-26: the provider's owner is waiting out the account's deletion.
      'PROVIDER_LEAVING' => 'هذا المزود يقفل حسابه وما يستقبل طلبات جديدة.',
      // RA-MO-263: it came in English.
      'PROVIDER_NOT_CLAIMED' =>
        'هذا المزوّد ما فعّل حسابه بعد، فما يستقبل طلبات.',
      // RA-MO-297: said as «اطلبها من صاحب الخطة», the 403 for a plan.
      'PROVIDER_PROFILE_READ_ONLY' => 'ملفك ما يتعدّل وهو موقوف أو مرفوض.',
      'CONVERSATION_CLOSED' => 'هذي المحادثة انقفلت، ما تستقبل رسائل.',
      'CONVERSATION_BLOCKED' => 'المراسلة في هذي المحادثة موقوفة.',
      'CONFIRM_WORD_MISMATCH' => 'اكتب «حذف» كما هي للتأكيد.',
      'DELETION_NOT_PENDING' => 'حسابك ما ينتظر الحذف.',
      'EXPORT_RATE_LIMITED' => 'نزّلت بياناتك كثير اليوم. جرّب بكرة.',
      'PROVIDER_REVIEW_CHANGED' =>
        'فريق المراجعة غيّر ملاحظاته قبل ما يوصلهم تعديلك. الملاحظات الجديدة تحت، والإرسال بعد تعديلها.',
      'PROVIDER_JOINING_CURRENCY' => 'سعر خدمتك يكون بالريال اليمني.',
      // V1 checklist 4.10: private costs and tasks.
      'COST_PRIVACY_NOT_ALLOWED' =>
        'التكلفة الخاصة متاحة لصاحب الخطة والشريك فقط.',
      'COST_PRIVACY_AT_CREATION_ONLY' =>
        'التكلفة المشتركة ما تصير خاصة. اختر "تكلفة خاصة بي" وأنت تضيفها.',
      'TASK_PRIVACY_NOT_ALLOWED' =>
        'المهمة الخاصة متاحة لصاحب الخطة والشريك فقط.',
      'TASK_PRIVACY_AT_CREATION_ONLY' =>
        'المهمة المشتركة ما تصير خاصة. اختر "مهمة خاصة بي" وأنت تضيفها.',
      'TASK_PRIVATE_ASSIGNMENT' =>
        'المهمة الخاصة تبقى لك وحدك. شاركها مع الخطة أولًا ثم اختر المسؤول.',
      // D65: the wedding's events.
      'EVENT_TYPE_EXISTS' => 'هذي المناسبة موجودة في خطتك.',
      'EVENT_CUSTOM_TITLE_REQUIRED' => 'اكتب اسم المناسبة.',
      'EVENT_WEDDING_DATE_IS_PLAN_DATE' =>
        'يوم العرس يتغير من «أجّل العرس» في الخطة.',
      'EVENT_IS_MAIN' => 'العرس نفسه ما ينحذف. موعده يتغير من الخطة.',
      'EVENT_EXACT_TIME_REQUIRED' ||
      'EVENT_EXACT_TIME_INVALID' => 'اختر الساعة.',
      'EVENT_DATE_INVALID' => 'اختر يوم المناسبة.',
      'EVENT_LIMIT_REACHED' => 'خطتك فيها مناسبات كثيرة. احذف وحدة قبل.',
      // V1 checklist 4.12: the planning assistant.
      'ASSISTANT_CONSENT_REQUIRED' =>
        'وافق على إرسال بيانات خطتك للمساعد أولًا.',
      'ASSISTANT_OWNER_OR_PARTNER_ONLY' =>
        'المساعد متاح لصاحب الخطة وشريكه فقط.',
      'ASSISTANT_DAILY_LIMIT' => 'خلصت أسئلة اليوم. ارجع بكرة.',
      'ASSISTANT_DISABLED' => 'المساعد ما اشتغل لسا.',
      'ASSISTANT_BUDGET_EXHAUSTED' =>
        'المساعد واقف هذا الشهر. جرّب الشهر الجاي.',
      'ASSISTANT_BUSY' => 'المساعد مشغول الحين. جرّب بعد شوي.',
      'ASSISTANT_UNAVAILABLE' =>
        'المساعد مو متاح الحين. جرّب بعدين، ولو تكرر كلّم الدعم.',
      // RA-MO-116, 117: the app's dialect, no technical word.
      'INVALID_CREDENTIALS' => 'الرقم أو كلمة المرور غلط.',
      'OTP_DELIVERY_UNAVAILABLE' => aarastOtpDeliveryUnavailableMessage,
      'PHONE_VERIFICATION_REQUIRED' => 'حساب التطبيق يحتاج تأكيد رقم الجوال.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'هذا الرقم عليه حساب من قبل. سجّل دخول، أو استرجع كلمة المرور.',
      'ADMIN_APP_PASSWORD_ALREADY_SET' =>
        'حساب التطبيق لهذا الرقم جاهز من قبل. سجّل دخول، أو استرجع كلمة مرور التطبيق.',
      'OTP_INVALID_OR_EXPIRED' =>
        'الرمز غلط أو انتهى وقته. اكتبه مرة ثانية أو اطلب رمز جديد.',
      'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF' =>
        'تأكدنا من رقمك، وما عليه حساب في التطبيق. سوّ حساب جديد وكمّل.',
      'ACCOUNT_DISABLED_AFTER_PHONE_PROOF' =>
        'تأكدنا من رقمك، لكن الحساب موقوف الحين. تواصل مع الدعم.',
      'INVITE_NOT_FOUND_FOR_PHONE' =>
        'ما في دعوة شغالة على هذا الرقم. تأكد من الرقم، أو اطلب دعوة جديدة.',
      'INVITE_ACCOUNT_SETUP_REQUIRED' =>
        'أول مرة تدخل اعّرست: اكتب اسمك، ونفس الرمز يسوي لك حساب.',
      'ADMIN_APP_PASSWORD_REQUIRED' => adminAppPasswordRequiredMessage,
      // J2-11: sharing refusals, each said as what happened.
      'CANNOT_INVITE_SELF' => 'هذا رقمك أنت، الدعوة لغيرك',
      'ALREADY_A_MEMBER' => 'هذا الرقم مشارك في الخطة من قبل',
      'INVITE_ALREADY_PENDING' =>
        'الدعوة مرسلة لهذا الرقم من قبل. التذكير يكفي بدل دعوة ثانية',
      'PLAN_ARCHIVED_READ_ONLY' => 'الخطة في الذكريات، ما تنعدل',
      'VIEWER_CANNOT_EDIT' =>
        '«يشوف بس» ما يعدّل شي. الدور الثاني هو اللي يعدّل',
      // J2-10: the rights changed between opening the sheet and leaving.
      'MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST' =>
        'تغيّرت صلاحياتك قبل شوي، حدّثنا الخطة. جرّب الخروج مرة ثانية.',
      _ => null,
    };
  }

  static bool _isAuthRequest(String path) {
    return path == '/api/v1/auth' || path.startsWith('/api/v1/auth/');
  }

  static String _genericAuthMessage(int? statusCode) {
    // RA-MO-116: «المصادقة» is the developer's word. Said as what happened.
    if (statusCode == 400 || statusCode == 422) {
      return 'ما قدرنا نكمل الطلب. تأكد من اللي كتبته وجرّب مرة ثانية.';
    }
    if (statusCode == 429) {
      return 'طلبات كثيرة ورا بعض. انتظر شوي وجرّب مرة ثانية.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'الخادم ما رد زي ما لازم. جرّب بعد شوي.';
    }
    return 'ما قدرنا نكمل الطلب. جرّب مرة ثانية.';
  }
}

/// D75: an admin's number without an app password cannot get an app account
/// by number and code (its app account needs a password, which no screen
/// takes), so a sign-up or an invite stops here and says what is left.
const adminAppPasswordRequiredMessage =
    'هذا الرقم لحساب إدارة في اعّرست، وما يتسوى له حساب في التطبيق من هنا. الحل رقم ثاني، أو التواصل مع الدعم.';
