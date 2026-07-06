import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/safe_user.dart';
import 'token_vault.dart';

class AuthStorage {
  const AuthStorage(this._preferences, {TokenVault? tokenVault})
    : _tokenVault = tokenVault;

  static const _accessTokenKey = 'aarast_access_token';
  static const _refreshTokenKey = 'aarast_refresh_token';
  static const _safeUserKey = 'aarast_safe_user';
  static const _activePlanIdKey = 'aarast_active_plan_id';

  final SharedPreferences _preferences;

  /// When provided (production wiring in main.dart), the access token lives
  /// in the OS keystore. Without it (widget tests), the legacy
  /// SharedPreferences location is used so tests need no platform channels.
  final TokenVault? _tokenVault;

  Future<String?> readAccessToken() async {
    final vault = _tokenVault;
    if (vault == null) {
      return _preferences.getString(_accessTokenKey);
    }

    final secureToken = await vault.read();
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // One-time migration: sessions created before the secure vault existed
    // stored the token in plaintext SharedPreferences. Move it over and
    // delete the plaintext copy.
    final legacyToken = _preferences.getString(_accessTokenKey);
    if (legacyToken == null || legacyToken.isEmpty) {
      return null;
    }
    await vault.write(legacyToken);
    await _preferences.remove(_accessTokenKey);
    return legacyToken;
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

  Future<String?> readRefreshToken() async {
    final vault = _tokenVault;
    if (vault == null) {
      return _preferences.getString(_refreshTokenKey);
    }
    return vault.readRefresh();
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required SafeUser user,
  }) async {
    final vault = _tokenVault;
    if (vault == null) {
      await _preferences.setString(_accessTokenKey, accessToken);
    } else {
      await vault.write(accessToken);
      // Never keep a plaintext copy alongside the secure one.
      await _preferences.remove(_accessTokenKey);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      if (vault == null) {
        await _preferences.setString(_refreshTokenKey, refreshToken);
      } else {
        await vault.writeRefresh(refreshToken);
        await _preferences.remove(_refreshTokenKey);
      }
    } else {
      await vault?.deleteRefresh();
      await _preferences.remove(_refreshTokenKey);
    }
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
    await _tokenVault?.delete();
    await _tokenVault?.deleteRefresh();
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_safeUserKey);
    await _preferences.remove(_activePlanIdKey);
  }
}
