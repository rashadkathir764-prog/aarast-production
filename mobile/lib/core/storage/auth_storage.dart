import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/safe_user.dart';
import 'token_vault.dart';
import 'sensitive_value_vault.dart';

class AuthStorage {
  AuthStorage(
    this._preferences, {
    TokenVault? tokenVault,
    SensitiveValueVault? sensitiveValueVault,
  }) : _tokenVault = tokenVault,
       _sensitiveValueVault = sensitiveValueVault;

  static const _accessTokenKey = 'aarast_access_token';
  static const _refreshTokenKey = 'aarast_refresh_token';
  static const _safeUserKey = 'aarast_safe_user';
  static const _activePlanIdKey = 'aarast_active_plan_id';
  static const _accountContextKey = 'aarast_account_context_key';

  final SharedPreferences _preferences;

  /// When provided (production wiring in main.dart), the access token lives
  /// in the OS keystore. Without it (widget tests), the legacy
  /// SharedPreferences location is used so tests need no platform channels.
  final TokenVault? _tokenVault;
  final SensitiveValueVault? _sensitiveValueVault;
  SafeUser? _cachedUser;

  Future<void> initialize() async {
    final vault = _sensitiveValueVault;
    if (vault == null) return;
    final secureRaw = await vault.read(_safeUserKey);
    final secureUser = _decodeUser(secureRaw);
    if (secureUser != null) {
      _cachedUser = secureUser;
      await _preferences.remove(_safeUserKey);
      return;
    }

    final legacyRaw = _preferences.getString(_safeUserKey);
    final legacyUser = _decodeUser(legacyRaw);
    if (legacyUser == null || legacyRaw == null) return;
    await vault.write(_safeUserKey, legacyRaw);
    await _preferences.remove(_safeUserKey);
    _cachedUser = legacyUser;
  }

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
    if (_sensitiveValueVault != null) return _cachedUser;
    final rawUser = _preferences.getString(_safeUserKey);
    return _decodeUser(rawUser);
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
    await _saveUser(user);
  }

  Future<void> saveUser(SafeUser user) async {
    await _saveUser(user);
  }

  String? readActivePlanId() {
    return _preferences.getString(_activePlanIdKey);
  }

  Future<void> saveActivePlanId(String activePlanId) async {
    await _preferences.setString(_activePlanIdKey, activePlanId);
  }

  Future<void> clearActivePlanId() async {
    await _preferences.remove(_activePlanIdKey);
  }

  String? readAccountContextKey() {
    return _preferences.getString(_accountContextKey);
  }

  Future<void> saveAccountContextKey(String contextKey) async {
    await _preferences.setString(_accountContextKey, contextKey);
  }

  Future<void> clearAccountContextKey() async {
    await _preferences.remove(_accountContextKey);
  }

  Future<void> clear() async {
    await _tokenVault?.delete();
    await _tokenVault?.deleteRefresh();
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_safeUserKey);
    await _sensitiveValueVault?.delete(_safeUserKey);
    _cachedUser = null;
    await _preferences.remove(_activePlanIdKey);
    await _preferences.remove(_accountContextKey);
  }

  Future<void> _saveUser(SafeUser user) async {
    final encoded = jsonEncode(user.toJson());
    final vault = _sensitiveValueVault;
    if (vault == null) {
      await _preferences.setString(_safeUserKey, encoded);
    } else {
      await vault.write(_safeUserKey, encoded);
      await _preferences.remove(_safeUserKey);
      _cachedUser = user;
    }
  }

  SafeUser? _decodeUser(String? rawUser) {
    if (rawUser == null || rawUser.isEmpty) return null;
    try {
      return SafeUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
