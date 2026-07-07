import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/auth_otp.dart';
import '../models/auth_response.dart';
import '../models/safe_user.dart';

class AuthRepository {
  const AuthRepository(this._apiClient, this._authStorage);

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJson('/auth/login', {
      'phone': normalizedPhone,
      'password': password,
    });
    final response = _parseAuthResponse(json, operation: 'login');
    await _authStorage.saveSession(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      user: response.user,
    );
    return response;
  }

  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJson('/auth/register', {
      'name': name,
      'phone': normalizedPhone,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'password': password,
    });
    final response = _parseAuthResponse(json, operation: 'register');
    await _authStorage.saveSession(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      user: response.user,
    );
    return response;
  }

  Future<SafeUser> me() async {
    final json = await _apiClient.getJson('/auth/me');
    final user = SafeUser.fromJson(json);
    await _authStorage.saveUser(user);
    return user;
  }

  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJson('/auth/otp/request', {
      'phone': normalizedPhone,
      'purpose': purpose,
    });
    return OtpRequestResult.fromJson(json);
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJson('/auth/otp/verify', {
      'phone': normalizedPhone,
      'purpose': purpose,
      'code': code,
    });
    final response = OtpVerifyResult.fromJson(json);
    if (response.accessToken != null &&
        response.refreshToken != null &&
        response.user != null) {
      await _authStorage.saveSession(
        accessToken: response.accessToken!,
        refreshToken: response.refreshToken!,
        user: response.user!,
      );
    } else if (response.user != null) {
      await _authStorage.saveUser(response.user!);
    }
    return response;
  }

  /// يطلب رمز استعادة كلمة المرور. الخادم لا يكشف وجود الحساب من عدمه.
  Future<OtpRequestResult> requestPasswordReset({
    required String phone,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJson('/auth/password-reset/request', {
      'phone': normalizedPhone,
    });
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
    await _apiClient.postJson('/auth/password-reset/confirm', {
      'phone': normalizedPhone,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<String?> readAccessToken() => _authStorage.readAccessToken();

  Future<bool> refreshSession() async {
    final refreshToken = await _authStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final json = await _apiClient.postJson('/auth/refresh', {
        'refreshToken': refreshToken,
      });
      final response = _parseAuthResponse(json, operation: 'refresh');
      await _authStorage.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } on ApiException catch (error) {
      if (!error.isUnauthorized) rethrow;
      await _authStorage.clear();
      return false;
    }
  }

  SafeUser? readCachedUser() => _authStorage.readUser();

  Future<SafeUser> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final ticket = await _apiClient.postJson('/media/uploads/presign', {
        'purpose': 'user-avatar',
        'fileName': fileName,
        'contentType': contentType,
        'byteSize': bytes.length,
      });
      final uploadUrl = ticket['uploadUrl']?.toString() ?? '';
      final publicUrl = ticket['publicUrl']?.toString() ?? '';
      if (uploadUrl.isEmpty || publicUrl.isEmpty) {
        throw const ApiException('تعذر تجهيز رفع الصورة.');
      }
      await _apiClient.putBytes(uploadUrl, bytes, contentType: contentType);
      final user = SafeUser.fromJson(
        await _apiClient.patchJson('/users/me', {'avatarUrl': publicUrl}),
      );
      await _authStorage.saveUser(user);
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

  Future<void> logout() async {
    final refreshToken = await _authStorage.readRefreshToken();
    try {
      await _apiClient.postJson('/auth/logout', {
        if (refreshToken != null && refreshToken.isNotEmpty)
          'refreshToken': refreshToken,
      });
    } on Object {
      // Local logout must always complete, even when the network is down.
    } finally {
      await _authStorage.clear();
    }
  }

  AuthResponse _parseAuthResponse(
    Map<String, dynamic> json, {
    required String operation,
  }) {
    try {
      return AuthResponse.fromJson(json);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[AarastAuth] Failed to parse $operation response: $error');
      }
      throw const ApiException(
        'تعذر قراءة جلسة تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى.',
      );
    }
  }
}
