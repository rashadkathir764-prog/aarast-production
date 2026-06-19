import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/safe_user.dart';

class AuthStorage {
  const AuthStorage(this._preferences);

  static const _accessTokenKey = 'aarast_access_token';
  static const _safeUserKey = 'aarast_safe_user';
  static const _activePlanIdKey = 'aarast_active_plan_id';

  final SharedPreferences _preferences;

  Future<String?> readAccessToken() async {
    return _preferences.getString(_accessTokenKey);
  }

  SafeUser? readUser() {
    final rawUser = _preferences.getString(_safeUserKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      return SafeUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String accessToken,
    required SafeUser user,
  }) async {
    await _preferences.setString(_accessTokenKey, accessToken);
    await _preferences.setString(_safeUserKey, jsonEncode(user.toJson()));
  }

  Future<void> saveUser(SafeUser user) async {
    await _preferences.setString(_safeUserKey, jsonEncode(user.toJson()));
  }

  String? readActivePlanId() {
    return _preferences.getString(_activePlanIdKey);
  }

  Future<void> saveActivePlanId(String activePlanId) async {
    await _preferences.setString(_activePlanIdKey, activePlanId);
  }

  Future<void> clear() async {
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_safeUserKey);
    await _preferences.remove(_activePlanIdKey);
  }
}
