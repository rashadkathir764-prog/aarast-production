import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/session/session_teardown_coordinator.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/auth_otp.dart';
import '../models/auth_response.dart';
import '../models/safe_user.dart';

enum AccountDeletionServerStatus { deleted, pending, notStarted }

class AuthRepository implements SessionAuthTeardownPort {
  const AuthRepository(this._apiClient, this._authStorage);

  static const _otpDeliveryReceiveTimeout = Duration(seconds: 25);

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  void bindClientSession(String? userId) {
    _apiClient.bindSessionIdentity(userId);
  }

  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/login', {
        'phone': normalizedPhone,
        'password': password,
      });
      final response = _parseAuthResponse(json, operation: 'login');
      await _authStorage.saveSessionAtEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/register',
      {'name': name, 'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    required String otpCode,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/register/complete', {
        'name': name,
        'phone': normalizedPhone,
        'password': password,
        'otpCode': otpCode,
      });
      final response = _parseAuthResponse(json, operation: 'register');
      await _authStorage.saveSessionAtEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  Future<SafeUser> me() async {
    final sessionEpoch = _authStorage.sessionEpoch;
    final json = await _apiClient.getJson('/api/v1/auth/me');
    final user = SafeUser.fromJson(json);
    await _authStorage.saveUserIfEpoch(user, sessionEpoch);
    return user;
  }

  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/otp/request',
      {'phone': normalizedPhone, 'purpose': purpose},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/invites/${Uri.encodeComponent(token)}/request-otp',
      {'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    if (json['accountSetupRequired'] is! bool) {
      throw const ApiException(
        'تعذر تحديد حالة حساب المساهم. حدّث خدمة المصادقة ثم حاول مرة أخرى.',
      );
    }
    return OtpRequestResult.fromJson(json);
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final establishesSession = purpose == 'LOGIN';
    final sessionEpoch = establishesSession
        ? _authStorage.beginSessionEstablishment()
        : _authStorage.sessionEpoch;
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/otp/verify', {
        'phone': normalizedPhone,
        'purpose': purpose,
        'code': code,
      });
      final response = OtpVerifyResult.fromJson(json);
      if (establishesSession) {
        if (!response.hasDurableSession) {
          throw const ApiException(
            'تعذر إنشاء جلسة دخول دائمة. لم تُحفظ جلسة مؤقتة على الجهاز.',
          );
        }
        final saved = await _saveOtpSession(
          response,
          expectedEpoch: sessionEpoch,
          reservedEpoch: true,
        );
        if (!saved) {
          throw const ApiException(
            'تغيّرت جلسة الحساب قبل اكتمال الحفظ. أعد المحاولة بأمان.',
          );
        }
      } else if (response.accessToken != null &&
          response.refreshToken != null &&
          response.user != null) {
        await _authStorage.saveSessionIfEpoch(
          expectedEpoch: sessionEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      } else if (response.user != null) {
        await _authStorage.saveUserIfEpoch(response.user!, sessionEpoch);
      }
      return response;
    } on Object {
      if (establishesSession) {
        await _clearFailedSessionIntent(sessionEpoch);
      }
      rethrow;
    }
  }

  Future<OtpVerifyResult> verifyInviteOtp({
    required String token,
    required String phone,
    required String code,
    String? name,
    String? password,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson(
        '/api/v1/invites/${Uri.encodeComponent(token)}/verify-otp',
        {
          'phone': normalizedPhone,
          'code': code,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      final response = OtpVerifyResult.fromJson(json);
      if (!response.hasDurableSession) {
        throw const ApiException(
          'تعذر إنشاء جلسة مساهم دائمة. لم تُحفظ جلسة مؤقتة على الجهاز.',
        );
      }
      final saved = await _saveOtpSession(
        response,
        expectedEpoch: sessionEpoch,
        reservedEpoch: true,
      );
      if (!saved) {
        throw const ApiException(
          'تغيّرت جلسة الحساب قبل اكتمال الحفظ. أعد المحاولة بأمان.',
        );
      }
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  /// يطلب رمز استعادة كلمة المرور. الخادم لا يكشف وجود الحساب من عدمه.
  Future<OtpRequestResult> requestPasswordReset({required String phone}) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/password-reset/request',
      {'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// يؤكد الاستعادة بالرمز وكلمة المرور الجديدة — الخادم يستهلك الرمز
  /// ويبطل كل الجلسات القائمة، فيبقى الدخول بكلمة المرور الجديدة فقط.
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    await _apiClient.postJson('/api/v1/auth/password-reset/confirm', {
      'phone': normalizedPhone,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<String?> readAccessToken() => _authStorage.readAccessToken();

  Future<bool> refreshSession() async {
    final sessionEpoch = _authStorage.sessionEpoch;
    final refreshToken = await _authStorage.readRefreshTokenIfEpoch(
      sessionEpoch,
    );
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final json = await _apiClient.postJson('/api/v1/auth/refresh', {
        'refreshToken': refreshToken,
      });
      final response = _parseAuthResponse(json, operation: 'refresh');
      return _authStorage.saveSessionIfEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
    } on ApiException catch (error) {
      if (!error.isUnauthorized) rethrow;
      await _authStorage.clearIfEpoch(sessionEpoch);
      return false;
    }
  }

  SafeUser? readCachedUser() => _authStorage.readUser();

  Future<bool> _saveOtpSession(
    OtpVerifyResult response, {
    required int expectedEpoch,
    bool reservedEpoch = false,
  }) async {
    if (response.accessToken != null &&
        response.refreshToken != null &&
        response.user != null) {
      if (reservedEpoch) {
        return _authStorage.saveSessionAtEpoch(
          expectedEpoch: expectedEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      } else {
        return _authStorage.saveSessionIfEpoch(
          expectedEpoch: expectedEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      }
    } else if (response.user != null) {
      return _authStorage.saveUserIfEpoch(response.user!, expectedEpoch);
    }
    return false;
  }

  Future<SafeUser> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final sessionEpoch = _authStorage.sessionEpoch;
    try {
      final ticket = await _apiClient
          .postJson('/api/v1/media/uploads/presign', {
            'purpose': 'user-avatar',
            'fileName': fileName,
            'contentType': contentType,
            'byteSize': bytes.length,
          });
      final uploadUrl = ticket['uploadUrl']?.toString() ?? '';
      final key = ticket['key']?.toString() ?? '';
      if (uploadUrl.isEmpty || key.isEmpty) {
        throw const ApiException('تعذر تجهيز رفع الصورة.');
      }
      await _apiClient.putBytes(uploadUrl, bytes, contentType: contentType);
      final verified = await _apiClient.postJson(
        '/api/v1/media/uploads/verify',
        {'key': key, 'purpose': 'user-avatar'},
      );
      final publicUrl = verified['publicUrl']?.toString() ?? '';
      if (publicUrl.isEmpty) {
        throw const ApiException('تعذر التحقق من الصورة المرفوعة.');
      }
      final user = SafeUser.fromJson(
        await _apiClient.patchJson('/api/v1/users/me', {
          'avatarUrl': publicUrl,
        }),
      );
      await _authStorage.saveUserIfEpoch(user, sessionEpoch);
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 503 ||
          error.message.toLowerCase().contains('media storage')) {
        throw const ApiException(
          'خدمة رفع الصور غير متاحة الآن. يرجى المحاولة مرة أخرى لاحقًا.',
          statusCode: 503,
        );
      }
      rethrow;
    }
  }

  /// Permanently deletes the account server-side.
  ///
  /// Local credentials and account data are owned by the central session
  /// teardown boundary after this request succeeds.
  Future<void> deleteAccount({required String clientRequestId}) async {
    final response = await _apiClient.mutateJson(
      '/api/v1/users/me',
      const {},
      method: 'DELETE',
      clientRequestId: clientRequestId,
    );
    if (response['deleted'] != true) {
      throw const FormatException(
        'Account deletion response did not confirm deletion',
      );
    }
  }

  Future<AccountDeletionServerStatus> accountDeletionStatus({
    required String userId,
    required String clientRequestId,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/account-deletions/status',
      {'userId': userId, 'clientRequestId': clientRequestId},
    );
    return switch (response['status']) {
      'DELETED' => AccountDeletionServerStatus.deleted,
      'PENDING' => AccountDeletionServerStatus.pending,
      'NOT_STARTED' => AccountDeletionServerStatus.notStarted,
      _ => throw const FormatException(
        'Account deletion status response is invalid',
      ),
    };
  }

  @override
  SessionAuthTeardownLease beginSessionTeardown(String userId) {
    return SessionAuthTeardownLease(
      userId: userId,
      storageEpoch: _authStorage.beginSessionInvalidation(),
    );
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {
    final accessToken = await _authStorage.readAccessTokenIfEpoch(
      lease.storageEpoch,
    );
    final refreshToken = await _authStorage.readRefreshTokenIfEpoch(
      lease.storageEpoch,
    );
    lease.captureCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    final cleared = await _authStorage.clearTerminatingSessionAtEpoch(
      lease.storageEpoch,
    );
    if (!cleared) {
      throw StateError(
        'The session epoch changed before local teardown completed',
      );
    }
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {
    final refreshToken = lease.refreshTokenForRemoteTeardown;
    if (refreshToken == null || refreshToken.isEmpty) return;
    final accessToken = lease.accessTokenForRemoteTeardown;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Remote logout credentials are incomplete');
    }
    await _apiClient.postJsonWithBearer(
      '/api/v1/auth/logout',
      {'refreshToken': refreshToken},
      bearerToken: accessToken,
      cancelToken: cancelToken,
    );
  }

  Future<void> logout() async {
    final userId = _authStorage.readUser()?.id ?? 'unknown-session';
    final lease = beginSessionTeardown(userId);
    await captureRemoteCredentials(lease);
    await clearLocalSession(lease);
    final cancelToken = CancelToken();
    try {
      await revokeRemoteSession(
        lease,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      cancelToken.cancel('Session teardown deadline reached');
    } on Object {
      // Local logout must always complete, even when the network is down.
    } finally {
      lease.clearSensitiveCredentials();
    }
  }

  Future<void> _clearFailedSessionIntent(int sessionEpoch) async {
    try {
      await _authStorage.clearIfEpoch(sessionEpoch);
    } on Object {
      // Preserve the original authentication failure. A later restore still
      // treats the reserved epoch as unauthenticated.
    }
  }

  AuthResponse _parseAuthResponse(
    Map<String, dynamic> json, {
    required String operation,
  }) {
    try {
      return AuthResponse.fromJson(json);
    } on Object catch (error) {
      appLogEvent(
        'AUTH_RESPONSE_PARSE_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        reason: 'invalid_auth_response_shape',
        source: 'AuthRepository.parseAuthResponse',
        attributes: {
          'operation': operation,
          'errorType': error.runtimeType.toString(),
        },
      );
      throw const ApiException(
        'تعذر قراءة جلسة تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى.',
      );
    }
  }
}
