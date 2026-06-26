import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/storage/auth_storage.dart';
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

  Future<String?> readAccessToken() => _authStorage.readAccessToken();

  SafeUser? readCachedUser() => _authStorage.readUser();

  Future<void> logout() => _authStorage.clear();

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
