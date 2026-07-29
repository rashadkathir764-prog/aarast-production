import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/context_lifecycle_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../data/auth_repository.dart';
import '../models/auth_otp.dart';
import '../models/safe_user.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  static final RegExp _privateInviteTokenPattern = RegExp(
    r'^[A-Za-z0-9_-]{43}$',
  );

  AuthController(
    this._authRepository, {
    OfflineSyncService? offlineSyncService,
    GuestOnboardingStorage? guestOnboardingStorage,
    Future<void> Function(String userId)? beforeAccountLogout,
    Future<void> Function(String userId)? clearPushOnSessionEnd,
  }) : _offlineSyncService = offlineSyncService,
       _guestOnboardingStorage = guestOnboardingStorage,
       _beforeAccountLogout = beforeAccountLogout,
       _clearPushOnSessionEnd = clearPushOnSessionEnd;

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;
  final GuestOnboardingStorage? _guestOnboardingStorage;
  final Future<void> Function(String userId)? _beforeAccountLogout;
  final Future<void> Function(String userId)? _clearPushOnSessionEnd;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  OtpRequestResult? _otpRequest;
  bool _sessionExpired = false;
  bool _loginRequestedAfterLogout = false;
  String? _pendingInviteResumeToken;
  bool _pendingInviteRouteClaimed = false;
  int _sessionOperationGeneration = 0;

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

  Future<void> restoreSession() async {
    final operation = ++_sessionOperationGeneration;
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
      ContextLifecycleLogger.event(
        'SESSION_RESTORED',
        userId: _user?.id,
        reason: 'server_session_confirmed',
        source: 'AuthController.restoreSession',
      );
      unawaited(_offlineSyncService?.syncPendingChanges());
    } on ApiException catch (error) {
      if (!_isCurrentSessionOperation(operation)) return;
      if (CachePolicy.shouldUseCache(error) && _user != null) {
        _status = AuthStatus.authenticated;
        ContextLifecycleLogger.event(
          'SESSION_RESTORED',
          userId: _user?.id,
          reason: 'offline_cached_account',
          source: 'AuthController.restoreSession',
        );
        await _offlineSyncService?.noteNetworkFailure(error.message);
      } else {
        final cachedUserId = _user?.id;
        final clearPush = _clearPushOnSessionEnd;
        if (cachedUserId != null && clearPush != null) {
          await clearPush(cachedUserId);
          if (!_isCurrentSessionOperation(operation)) return;
        }
        // Drop the in-memory identity before any network or storage cleanup.
        // A slow logout request must never keep the previous account's
        // provider subtree mounted during failed session restoration.
        _user = null;
        _authRepository.bindClientSession(null);
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        await _authRepository.logout();
        return;
      }
    }
    notifyListeners();
  }

  Future<bool> login({required String phone, required String password}) async {
    final operation = ++_sessionOperationGeneration;
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
      unawaited(_offlineSyncService?.syncPendingChanges());
    }, unauthorizedMessage: _safeLoginFailureMessage);
    return success && _isCurrentSessionOperation(operation);
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
    String? resumeInviteToken,
  }) async {
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
      _status = AuthStatus.authenticated;
      _loginRequestedAfterLogout = false;
      if (cleanResumeToken != null) {
        _pendingInviteResumeToken = cleanResumeToken;
        _pendingInviteRouteClaimed = false;
      } else {
        _clearPendingInviteResume();
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
  }) async {
    final cleanResumeToken = _validInviteToken(resumeInviteToken);
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

  Future<void> logout() async {
    final operation = ++_sessionOperationGeneration;
    final outgoingUserId = _user?.id;
    ContextLifecycleLogger.event(
      'LOGOUT_ACCOUNT',
      userId: _user?.id,
      reason: 'explicit_account_logout',
      source: 'AuthController.logout',
    );
    final beforeLogout = _beforeAccountLogout;
    if (outgoingUserId != null && beforeLogout != null) {
      await beforeLogout(outgoingUserId);
      if (!_isCurrentSessionOperation(operation)) return;
    }
    _authRepository.bindClientSession(null);
    _clearPendingInviteResume();
    _loginRequestedAfterLogout = true;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    // Start repository logout immediately so it captures the outgoing
    // storage epoch before a replacement login can begin.
    final repositoryLogout = _authRepository.logout();
    // Privacy hard-rule: shared devices are common in Yemen. Everything
    // financial that this account cached locally must go with the session —
    // cache, queued writes and any onboarding draft tied to this session.
    await _offlineSyncService?.clearLocalData();
    if (_isCurrentSessionOperation(operation)) {
      await _guestOnboardingStorage?.clearDraft();
    }
    await repositoryLogout;
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
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    await _offlineSyncService?.clearLocalData();
    await _guestOnboardingStorage?.clearDraft();
    return true;
  }

  /// Called by the API layer when any non-auth request returns 401. Ends
  /// the session cleanly instead of letting every screen degrade into
  /// misleading errors. Local cache is kept: the SAME account will log in
  /// again and `ensureCacheOwner` protects against a different one.
  Future<void> handleSessionExpired() async {
    if (_status != AuthStatus.authenticated) return;
    final operation = ++_sessionOperationGeneration;
    final outgoingUserId = _user?.id;
    ContextLifecycleLogger.event(
      'UNAUTHORIZED_401',
      userId: _user?.id,
      reason: 'confirmed_session_expiry',
      source: 'AuthController.handleSessionExpired',
    );
    final clearPush = _clearPushOnSessionEnd;
    if (outgoingUserId != null && clearPush != null) {
      await clearPush(outgoingUserId);
      if (!_isCurrentSessionOperation(operation)) return;
    }
    _authRepository.bindClientSession(null);
    _clearPendingInviteResume();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _sessionExpired = true;
    _errorMessage = 'انتهت جلستك. سجّل الدخول مرة أخرى للمتابعة.';
    _errorCode = null;
    notifyListeners();
    await _authRepository.logout();
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
      if (kDebugMode) {
        debugPrint('[AarastAuth] Invalid phone input: $error');
      }
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
      if (kDebugMode) {
        debugPrint('[AarastAuth] Unexpected auth error: $error');
      }
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
