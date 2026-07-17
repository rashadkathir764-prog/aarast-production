import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../data/auth_repository.dart';
import '../models/auth_otp.dart';
import '../models/safe_user.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(
    this._authRepository, {
    OfflineSyncService? offlineSyncService,
    GuestOnboardingStorage? guestOnboardingStorage,
  }) : _offlineSyncService = offlineSyncService,
       _guestOnboardingStorage = guestOnboardingStorage;

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;
  final GuestOnboardingStorage? _guestOnboardingStorage;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  OtpRequestResult? _otpRequest;
  bool _sessionExpired = false;

  AuthStatus get status => _status;
  SafeUser? get user => _user;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  OtpRequestResult? get otpRequest => _otpRequest;

  /// True right after a mid-session 401 invalidated the session. The UI
  /// redirects to login once, then acknowledges.
  bool get sessionExpired => _sessionExpired;

  Future<void> restoreSession() async {
    _status = AuthStatus.checking;
    _user = _authRepository.readCachedUser();
    _authRepository.bindClientSession(_user?.id);
    notifyListeners();

    final token = await _authRepository.readAccessToken();
    if (token == null || token.isEmpty) {
      _user = null;
      _authRepository.bindClientSession(null);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      _user = await _authRepository.me();
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.ensureCacheOwner(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
      }
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    } on ApiException catch (error) {
      if (CachePolicy.shouldUseCache(error) && _user != null) {
        _status = AuthStatus.authenticated;
        await _offlineSyncService?.noteNetworkFailure(error.message);
      } else {
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
    return _submit(() async {
      final response = await _authRepository.login(
        phone: phone.trim(),
        password: password,
      );
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      await _offlineSyncService?.cacheCurrentUser(response.user);
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    }, unauthorizedMessage: _safeLoginFailureMessage);
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
  }) async {
    return _submit(() async {
      final response = await _authRepository.register(
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        otpCode: otpCode,
      );
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      await _offlineSyncService?.cacheCurrentUser(response.user);
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    });
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

  Future<bool> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    return _submit(() async {
      final response = await _authRepository.verifyOtp(
        phone: phone.trim(),
        purpose: purpose,
        code: code,
      );
      if (response.user != null) {
        _user = response.user;
        _authRepository.bindClientSession(response.user!.id);
        await _offlineSyncService?.ensureCacheOwner(response.user!.id);
        await _offlineSyncService?.cacheCurrentUser(response.user!);
      }
      if (response.accessToken != null) {
        _status = AuthStatus.authenticated;
        unawaited(_offlineSyncService?.syncPendingChanges());
      }
    });
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
    try {
      _user = await _authRepository.me();
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
      }
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await handleSessionExpired();
      }
    }
  }

  Future<void> logout() async {
    _authRepository.bindClientSession(null);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    // Privacy hard-rule: shared devices are common in Yemen. Everything
    // financial that this account cached locally must go with the session —
    // cache, queued writes and any onboarding draft tied to this session.
    await _offlineSyncService?.clearLocalData();
    await _guestOnboardingStorage?.clearDraft();
    await _authRepository.logout();
  }

  /// Permanently deletes the account, then tears the local session down the
  /// same way logout does (cache, queued writes and drafts all go with it).
  /// Returns false with an error message if the server request fails, leaving
  /// the session intact so the user can retry.
  Future<bool> deleteAccount() async {
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
    _authRepository.bindClientSession(null);
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
    _authRepository.bindClientSession(null);
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
      _ => null,
    };
  }
}
