import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/session/session_teardown_coordinator.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../data/auth_repository.dart';
import '../models/auth_otp.dart';
import '../models/safe_user.dart';

enum AuthStatus {
  checking,
  authenticated,
  terminating,
  terminationFailed,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  static final RegExp _privateInviteTokenPattern = RegExp(
    r'^[A-Za-z0-9_-]{43}$',
  );

  AuthController(
    AuthRepository authRepository, {
    OfflineSyncService? offlineSyncService,
    GuestOnboardingStorage? guestOnboardingStorage,
    SessionTeardownCoordinator? sessionTeardownCoordinator,
    Future<void> Function(String userId)? clearPushOnSessionEnd,
  }) : _authRepository = authRepository,
       _offlineSyncService = offlineSyncService,
       _guestOnboardingStorage = guestOnboardingStorage,
       _sessionTeardownCoordinator =
           sessionTeardownCoordinator ??
           SessionTeardownCoordinator(
             auth: authRepository,
             clearLocalAccountData: () async {
               await offlineSyncService?.clearLocalData();
             },
             clearGuestDraft: () async {
               await guestOnboardingStorage?.clearDraft();
             },
           ),
       _clearPushOnSessionEnd = clearPushOnSessionEnd;

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;
  final GuestOnboardingStorage? _guestOnboardingStorage;
  final SessionTeardownCoordinator _sessionTeardownCoordinator;
  final Future<void> Function(String userId)? _clearPushOnSessionEnd;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  OtpRequestResult? _otpRequest;
  bool _sessionExpired = false;
  bool _loginRequestedAfterLogout = false;
  bool _authenticatedEntryPending = false;
  String? _pendingAuthenticatedEntryLocation;
  String? _pendingInviteResumeToken;
  bool _pendingInviteRouteClaimed = false;
  int _sessionOperationGeneration = 0;
  String? _pendingLogoutUserId;
  String _pendingLogoutReason = 'explicit_account_logout';
  bool _pendingLogoutRequestsLogin = true;
  bool _pendingLogoutMarksSessionExpired = false;
  Future<void>? _logoutInFlight;

  AuthStatus get status => _status;
  SafeUser? get user => _user;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  OtpRequestResult? get otpRequest => _otpRequest;
  bool get hasPendingInviteResume =>
      _status == AuthStatus.authenticated &&
      _pendingInviteResumeToken != null &&
      !_pendingInviteRouteClaimed;

  /// True right after a mid-session 401 invalidated the session. The UI
  /// redirects to login once, then acknowledges.
  bool get sessionExpired => _sessionExpired;
  bool get loginRequestedAfterLogout => _loginRequestedAfterLogout;
  bool get hasPendingAuthenticatedEntry =>
      _status == AuthStatus.authenticated && _authenticatedEntryPending;

  Future<void> restoreSession() async {
    AppLogger.global?.ensureSessionCorrelation();
    final operation = ++_sessionOperationGeneration;
    appLogEvent(
      'SESSION_LOAD_STARTED',
      category: AppLogCategory.session,
      reason: 'restore_requested',
      source: 'AuthController.restoreSession',
    );
    _status = AuthStatus.checking;
    _user = _authRepository.readCachedUser();
    _authRepository.bindClientSession(_user?.id);
    notifyListeners();

    final token = await _authRepository.readAccessToken();
    if (!_isCurrentSessionOperation(operation)) return;
    if (token == null || token.isEmpty) {
      _user = null;
      _authRepository.bindClientSession(null);
      _status = AuthStatus.unauthenticated;
      appLogEvent(
        'SESSION_LOAD_COMPLETED',
        category: AppLogCategory.session,
        reason: 'no_access_token',
        source: 'AuthController.restoreSession',
      );
      notifyListeners();
      return;
    }

    try {
      final restoredUser = await _authRepository.me();
      if (!_isCurrentSessionOperation(operation)) return;
      _user = restoredUser;
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.ensureCacheOwner(_user!.id);
        if (!_isCurrentSessionOperation(operation)) return;
        await _offlineSyncService?.cacheCurrentUser(_user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      _status = AuthStatus.authenticated;
      appLogEvent(
        'SESSION_RESTORED',
        category: AppLogCategory.session,
        userId: _user?.id,
        reason: 'server_session_confirmed',
        source: 'AuthController.restoreSession',
      );
      unawaited(_offlineSyncService?.syncPendingChanges());
    } on ApiException catch (error) {
      if (!_isCurrentSessionOperation(operation)) return;
      if (CachePolicy.shouldUseCache(error) && _user != null) {
        _status = AuthStatus.authenticated;
        appLogEvent(
          'SESSION_RESTORED',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: _user?.id,
          reason: 'offline_cached_account',
          source: 'AuthController.restoreSession',
        );
        await _offlineSyncService?.noteNetworkFailure(error.message);
      } else {
        final cachedUserId = _user?.id;
        appLogEvent(
          'SESSION_RESTORE_FAILED',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: cachedUserId,
          reason: 'server_session_rejected',
          source: 'AuthController.restoreSession',
          attributes: {
            'httpStatus': ?error.statusCode,
            'errorCode': ?error.serverCode,
          },
        );
        _pendingLogoutUserId = cachedUserId ?? 'unknown-session';
        await _startSessionTermination(
          reason: 'server_session_rejected',
          requestLoginAfterCompletion: false,
          markSessionExpired: false,
          allowChecking: true,
        );
        return;
      }
    }
    notifyListeners();
  }

  Future<bool> login({
    required String phone,
    required String password,
    String? successLocation,
  }) async {
    if (_status != AuthStatus.unauthenticated) {
      appLogEvent(
        'LOGIN_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        reason: 'session_not_unauthenticated',
        source: 'AuthController.login',
        attributes: {'authStatus': _status.name},
      );
      return false;
    }
    AppLogger.global?.startSessionCorrelation();
    final operation = ++_sessionOperationGeneration;
    appLogEvent(
      'LOGIN_STARTED',
      category: AppLogCategory.auth,
      reason: 'password_login_requested',
      source: 'AuthController.login',
    );
    final success = await _submit(() async {
      final response = await _authRepository.login(
        phone: phone.trim(),
        password: password,
      );
      if (!_isCurrentSessionOperation(operation)) return;
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      if (!_isCurrentSessionOperation(operation)) return;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.authenticated;
      _loginRequestedAfterLogout = false;
      _queueAuthenticatedEntry(successLocation);
      unawaited(_offlineSyncService?.syncPendingChanges());
    }, unauthorizedMessage: _safeLoginFailureMessage);
    final completed = success && _isCurrentSessionOperation(operation);
    appLogEvent(
      completed ? 'LOGIN_SUCCEEDED' : 'LOGIN_FAILED',
      category: AppLogCategory.auth,
      level: completed ? AppLogLevel.info : AppLogLevel.warning,
      userId: completed ? _user?.id : null,
      reason: completed
          ? 'authenticated_session_established'
          : success
          ? 'stale_session_operation'
          : 'authentication_rejected',
      source: 'AuthController.login',
      attributes: {'authStatus': _status.name, 'errorCode': ?_errorCode},
    );
    return completed;
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
    String? resumeInviteToken,
    String? successLocation,
    Future<String?> Function()? afterSessionEstablished,
  }) async {
    if (_status != AuthStatus.unauthenticated) {
      return false;
    }
    AppLogger.global?.startSessionCorrelation();
    final cleanResumeToken = _validInviteToken(resumeInviteToken);
    final operation = ++_sessionOperationGeneration;
    final success = await _submit(() async {
      final response = await _authRepository.register(
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        otpCode: otpCode,
      );
      if (!_isCurrentSessionOperation(operation)) return;
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      if (!_isCurrentSessionOperation(operation)) return;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      if (!_isCurrentSessionOperation(operation)) return;
      final resolvedSuccessLocation = afterSessionEstablished == null
          ? successLocation
          : (await afterSessionEstablished()) ?? successLocation;
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.authenticated;
      _loginRequestedAfterLogout = false;
      if (cleanResumeToken != null) {
        _pendingInviteResumeToken = cleanResumeToken;
        _pendingInviteRouteClaimed = false;
      } else {
        _clearPendingInviteResume();
        _queueAuthenticatedEntry(resolvedSuccessLocation);
      }
      unawaited(_offlineSyncService?.syncPendingChanges());
    });
    return success && _isCurrentSessionOperation(operation);
  }

  Future<OtpRequestResult?> startRegistration({
    required String name,
    required String phone,
    required String password,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.startRegistration(
          name: name.trim(),
          phone: phone.trim(),
          password: password,
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر إرسال رمز إنشاء الحساب الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<OtpRequestResult?> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.requestOtp(
          phone: phone.trim(),
          purpose: purpose,
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر إرسال رمز التحقق الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<OtpRequestResult?> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.requestInviteOtp(
          token: token.trim(),
          phone: phone.trim(),
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر التحقق من الدعوة الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<bool> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
    String? resumeInviteToken,
    String? accountName,
    String? accountPassword,
    String? successLocation,
  }) async {
    final cleanResumeToken = _validInviteToken(resumeInviteToken);
    final establishesSession = purpose == 'LOGIN' || cleanResumeToken != null;
    final privateInviteAccountSwitch =
        cleanResumeToken != null && _status == AuthStatus.authenticated;
    if (establishesSession &&
        _status != AuthStatus.unauthenticated &&
        !privateInviteAccountSwitch) {
      return false;
    }
    if (establishesSession) {
      AppLogger.global?.startSessionCorrelation();
    }
    final operation = ++_sessionOperationGeneration;
    final success = await _submit(() async {
      final response = cleanResumeToken == null
          ? await _authRepository.verifyOtp(
              phone: phone.trim(),
              purpose: purpose,
              code: code,
            )
          : await _authRepository.verifyInviteOtp(
              token: cleanResumeToken,
              phone: phone.trim(),
              code: code,
              name: accountName,
              password: accountPassword,
            );
      if (!_isCurrentSessionOperation(operation)) return;
      if (response.user != null) {
        _user = response.user;
        _authRepository.bindClientSession(response.user!.id);
        await _offlineSyncService?.ensureCacheOwner(response.user!.id);
        if (!_isCurrentSessionOperation(operation)) return;
        await _offlineSyncService?.cacheCurrentUser(response.user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      if (response.accessToken != null) {
        _status = AuthStatus.authenticated;
        _loginRequestedAfterLogout = false;
        if (purpose == 'LOGIN' && cleanResumeToken != null) {
          _pendingInviteResumeToken = cleanResumeToken;
          _pendingInviteRouteClaimed = false;
        } else {
          _clearPendingInviteResume();
          _queueAuthenticatedEntry(successLocation);
        }
        unawaited(_offlineSyncService?.syncPendingChanges());
      }
    });
    return success && _isCurrentSessionOperation(operation);
  }

  /// Returns a verified private invite exactly once to the router that lives
  /// inside the newly-created account boundary. The token remains memory-only
  /// and is consumed by the matching invite screen after navigation.
  String? claimPendingInviteResumeRoute() {
    if (!hasPendingInviteResume) return null;
    _pendingInviteRouteClaimed = true;
    return _pendingInviteResumeToken;
  }

  bool claimLoginAfterLogout() {
    if (!_loginRequestedAfterLogout) return false;
    _loginRequestedAfterLogout = false;
    return true;
  }

  String? claimPendingAuthenticatedEntry() {
    if (!hasPendingAuthenticatedEntry) return null;
    _authenticatedEntryPending = false;
    final location = _pendingAuthenticatedEntryLocation;
    _pendingAuthenticatedEntryLocation = null;
    return location;
  }

  void requestAuthenticatedEntry([String? successLocation]) {
    if (_status != AuthStatus.authenticated) return;
    _queueAuthenticatedEntry(successLocation);
    notifyListeners();
  }

  /// Allows only the route carrying the same private token to resume. A stale
  /// or unrelated route cannot consume another invite's phone proof.
  bool consumePendingInviteResume(String token) {
    final cleanToken = _validInviteToken(token);
    if (cleanToken == null || cleanToken != _pendingInviteResumeToken) {
      return false;
    }
    _clearPendingInviteResume();
    return true;
  }

  Future<bool> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    return _submit(() async {
      _user = await _authRepository.updateAvatar(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
      }
    });
  }

  Future<void> refreshCurrentUser() async {
    if (_status != AuthStatus.authenticated) return;
    final operation = _sessionOperationGeneration;
    try {
      final refreshedUser = await _authRepository.me();
      if (!_isCurrentSessionOperation(operation)) return;
      _user = refreshedUser;
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await handleSessionExpired();
      }
    }
  }

  Future<void> logout() {
    final retrying = _status == AuthStatus.terminationFailed;
    return _startSessionTermination(
      reason: retrying ? _pendingLogoutReason : 'explicit_account_logout',
      requestLoginAfterCompletion: retrying
          ? _pendingLogoutRequestsLogin
          : true,
      markSessionExpired: retrying ? _pendingLogoutMarksSessionExpired : false,
    );
  }

  Future<void> _startSessionTermination({
    required String reason,
    required bool requestLoginAfterCompletion,
    required bool markSessionExpired,
    bool allowChecking = false,
  }) {
    final inFlight = _logoutInFlight;
    if (inFlight != null) return inFlight;
    if (_status != AuthStatus.authenticated &&
        _status != AuthStatus.terminationFailed &&
        !(allowChecking && _status == AuthStatus.checking)) {
      return Future<void>.value();
    }
    if (_status != AuthStatus.terminationFailed) {
      _pendingLogoutReason = reason;
      _pendingLogoutRequestsLogin = requestLoginAfterCompletion;
      _pendingLogoutMarksSessionExpired = markSessionExpired;
    }
    final operation = _performLogout(
      reason: _pendingLogoutReason,
      requestLoginAfterCompletion: _pendingLogoutRequestsLogin,
      markSessionExpired: _pendingLogoutMarksSessionExpired,
    );
    _logoutInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_logoutInFlight, operation)) {
        _logoutInFlight = null;
      }
    });
  }

  Future<void> _performLogout({
    required String reason,
    required bool requestLoginAfterCompletion,
    required bool markSessionExpired,
  }) async {
    final operation = ++_sessionOperationGeneration;
    final outgoingUserId = _pendingLogoutUserId ?? _user?.id;
    _pendingLogoutUserId = outgoingUserId;
    SessionTeardownLease? teardownLease;
    Object? beginFailure;
    if (outgoingUserId != null) {
      try {
        teardownLease = _sessionTeardownCoordinator.begin(outgoingUserId);
      } on Object catch (error) {
        beginFailure = error;
      }
    } else {
      beginFailure = StateError('Authenticated session has no user identity');
    }
    appLogEvent(
      'LOGOUT_STARTED',
      category: AppLogCategory.auth,
      userId: outgoingUserId,
      reason: reason,
      source: 'AuthController.logout',
    );
    _authRepository.bindClientSession(null);
    _clearPendingInviteResume();
    _clearPendingAuthenticatedEntry();
    _loginRequestedAfterLogout = false;
    _sessionExpired = markSessionExpired;
    _user = null;
    _status = AuthStatus.terminating;
    _errorMessage = markSessionExpired
        ? 'انتهت جلستك. سجّل الدخول مرة أخرى للمتابعة.'
        : null;
    _errorCode = null;
    notifyListeners();

    if (beginFailure != null || teardownLease == null) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorMessage =
          'تعذر تنظيف بيانات الجلسة المحلية بأمان. حاول تسجيل الخروج مرة أخرى.';
      _errorCode = 'LOCAL_SESSION_TEARDOWN_FAILED';
      appLogEvent(
        'LOGOUT_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'local_teardown_begin_failed',
        source: 'AuthController.logout',
        error: beginFailure,
      );
      notifyListeners();
      return;
    }

    try {
      await _sessionTeardownCoordinator.terminate(teardownLease);
      if (!_isCurrentSessionOperation(operation)) return;

      _pendingLogoutUserId = null;
      _loginRequestedAfterLogout = requestLoginAfterCompletion;
      _status = AuthStatus.unauthenticated;
      appLogEvent(
        'LOGOUT_COMPLETED',
        category: AppLogCategory.auth,
        userId: outgoingUserId,
        reason: reason,
        source: 'AuthController.logout',
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorMessage =
          'تعذر تنظيف بيانات الجلسة المحلية بأمان. حاول تسجيل الخروج مرة أخرى.';
      _errorCode = 'LOCAL_SESSION_TEARDOWN_FAILED';
      appLogEvent(
        'LOGOUT_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'local_session_teardown_failed',
        source: 'AuthController.logout',
        error: error,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
  }

  /// Permanently deletes the account, then tears the local session down the
  /// same way logout does (cache, queued writes and drafts all go with it).
  /// Returns false with an error message if the server request fails, leaving
  /// the session intact so the user can retry.
  Future<bool> deleteAccount() async {
    final operation = ++_sessionOperationGeneration;
    final outgoingUserId = _user?.id;
    try {
      await _authRepository.deleteAccount();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _errorCode = error.serverCode;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف الحساب. حاول مرة أخرى.';
      notifyListeners();
      return false;
    }
    if (!_isCurrentSessionOperation(operation)) return false;
    final clearPush = _clearPushOnSessionEnd;
    if (outgoingUserId != null && clearPush != null) {
      await clearPush(outgoingUserId);
      if (!_isCurrentSessionOperation(operation)) return false;
    }
    _authRepository.bindClientSession(null);
    _clearPendingInviteResume();
    _clearPendingAuthenticatedEntry();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    await _offlineSyncService?.clearLocalData();
    await _guestOnboardingStorage?.clearDraft();
    return true;
  }

  /// Called by the API layer when any non-auth request returns 401. Ends
  /// the session cleanly instead of letting every screen degrade into
  /// misleading errors. It uses the same local teardown boundary as an
  /// explicit logout so account data cannot remain mounted or be reused.
  Future<void> handleSessionExpired() async {
    if (_status != AuthStatus.authenticated) return;
    appLogEvent(
      'UNAUTHORIZED_401',
      category: AppLogCategory.session,
      level: AppLogLevel.warning,
      userId: _user?.id,
      reason: 'confirmed_session_expiry',
      source: 'AuthController.handleSessionExpired',
    );
    await _startSessionTermination(
      reason: 'confirmed_session_expiry',
      requestLoginAfterCompletion: false,
      markSessionExpired: true,
    );
  }

  void acknowledgeSessionExpiry() {
    _sessionExpired = false;
  }

  void clearError() {
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  static String? _validInviteToken(String? token) {
    final cleanToken = token?.trim();
    if (cleanToken == null ||
        !_privateInviteTokenPattern.hasMatch(cleanToken)) {
      return null;
    }
    return cleanToken;
  }

  void _clearPendingInviteResume() {
    _pendingInviteResumeToken = null;
    _pendingInviteRouteClaimed = false;
  }

  void _queueAuthenticatedEntry(String? successLocation) {
    _authenticatedEntryPending = true;
    _pendingAuthenticatedEntryLocation = successLocation;
  }

  void _clearPendingAuthenticatedEntry() {
    _authenticatedEntryPending = false;
    _pendingAuthenticatedEntryLocation = null;
  }

  bool _isCurrentSessionOperation(int generation) {
    return generation == _sessionOperationGeneration;
  }

  Future<bool> _submit(
    Future<void> Function() action, {
    String? unauthorizedMessage,
    String? networkFailureMessage,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on FormatException catch (error) {
      appLogEvent(
        'AUTH_INPUT_REJECTED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        reason: 'invalid_phone_format',
        source: 'AuthController.submit',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      _errorMessage = 'رقم الهاتف غير صحيح';
      return false;
    } on ApiException catch (error) {
      _errorCode = error.serverCode;
      final translatedMessage = _messageForServerCode(error.serverCode);
      if (translatedMessage != null) {
        _errorMessage = translatedMessage;
      } else if (error.isUnauthorized && unauthorizedMessage != null) {
        _errorMessage = unauthorizedMessage;
      } else if (error.isNetworkFailure) {
        _errorMessage =
            networkFailureMessage ??
            'تعذر تسجيل الدخول الآن. تحقق من الاتصال وحاول مرة أخرى.';
      } else {
        _errorMessage = error.message;
      }
      return false;
    } catch (error) {
      appLogEvent(
        'AUTH_UNEXPECTED_FAILURE',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        reason: 'unexpected_auth_exception',
        source: 'AuthController.submit',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      _errorMessage = 'حدث خطأ، يرجى المحاولة مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static const _safeLoginFailureMessage =
      'تعذر تسجيل الدخول بهذه البيانات. تأكد منها، أو استخدم «نسيت كلمة المرور؟» أو أنشئ حسابًا جديدًا.';

  static String? _messageForServerCode(String? code) {
    return switch (code) {
      'INVALID_CREDENTIALS' => _safeLoginFailureMessage,
      'OTP_DELIVERY_UNAVAILABLE' => aarastOtpDeliveryUnavailableMessage,
      'PHONE_VERIFICATION_REQUIRED' =>
        'يحتاج حساب التطبيق إلى تأكيد رقم الهاتف. استخدم «الدخول برمز تحقق» للمتابعة.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'هذا الرقم مسجل بالفعل. انتقل إلى تسجيل الدخول أو استعد كلمة المرور.',
      'ADMIN_APP_PASSWORD_ALREADY_SET' =>
        'تم إعداد حساب التطبيق لهذا الرقم بالفعل. انتقل إلى تسجيل الدخول أو استعد كلمة مرور التطبيق.',
      'OTP_INVALID_OR_EXPIRED' =>
        'رمز التحقق غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا وحاول مرة أخرى.',
      'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، ولا يوجد حساب تطبيق مرتبط به. أنشئ حسابًا جديدًا للمتابعة.',
      'ACCOUNT_DISABLED_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، لكن الحساب معطل حاليًا. تواصل مع الدعم.',
      'INVITE_NOT_FOUND_FOR_PHONE' =>
        'لا توجد دعوة فعّالة مرتبطة بهذا الرقم. تأكد من الرقم أو اطلب دعوة جديدة.',
      'INVITE_ACCOUNT_SETUP_REQUIRED' =>
        'أنشئ اسمًا وكلمة مرور لحساب المساهم ثم أعد تأكيد الرمز نفسه.',
      _ => null,
    };
  }
}
