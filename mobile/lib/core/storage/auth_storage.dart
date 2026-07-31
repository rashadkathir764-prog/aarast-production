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
  String? _cachedAccountContextKey;
  int _sessionEpoch = 0;
  Future<void> _sessionMutationTail = Future<void>.value();

  /// Monotonic identity for the locally persisted account session.
  ///
  /// Login/registration/refresh advance this value synchronously before any
  /// storage await. Delayed logout and refresh completions may only mutate
  /// storage while the epoch they started from is still current.
  int get sessionEpoch => _sessionEpoch;

  bool isSessionEpochCurrent(int epoch) => epoch == _sessionEpoch;

  /// Claims a logout/session-expiry operation synchronously. Any refresh or
  /// profile write that started from the previous epoch becomes stale before
  /// the first logout network await.
  int beginSessionInvalidation() => ++_sessionEpoch;

  /// Reserves the epoch for a user-initiated replacement login before its
  /// network request starts. This makes any older logout completion stale.
  int beginSessionEstablishment() => ++_sessionEpoch;

  Future<void> initialize() async {
    final vault = _sensitiveValueVault;
    if (vault == null) return;

    final secureRaw = await vault.read(_safeUserKey);
    final secureUser = _decodeUser(secureRaw);
    if (secureUser != null) {
      _cachedUser = secureUser;
      await _preferences.remove(_safeUserKey);
    } else {
      final legacyRaw = _preferences.getString(_safeUserKey);
      final legacyUser = _decodeUser(legacyRaw);
      if (legacyUser != null && legacyRaw != null) {
        await vault.write(_safeUserKey, legacyRaw);
        await _preferences.remove(_safeUserKey);
        _cachedUser = legacyUser;
      }
    }

    final secureContextValue = await vault.read(_accountContextKey);
    if (secureContextValue != null && secureContextValue.isNotEmpty) {
      _cachedAccountContextKey = await _migrateAccountContextValue(
        secureContextValue,
      );
      await _preferences.remove(_accountContextKey);
    } else {
      final legacyContextValue = _preferences.getString(_accountContextKey);
      if (legacyContextValue != null && legacyContextValue.isNotEmpty) {
        final migrated = await _migrateAccountContextValue(legacyContextValue);
        await vault.write(_accountContextKey, migrated);
        await _preferences.remove(_accountContextKey);
        _cachedAccountContextKey = migrated;
      }
    }
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
    final epoch = ++_sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _writeSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        clearAccountContext: true,
      );
    });
  }

  Future<bool> saveSessionIfEpoch({
    required int expectedEpoch,
    required String accessToken,
    String? refreshToken,
    required SafeUser user,
  }) async {
    if (!isSessionEpochCurrent(expectedEpoch)) return false;
    final epoch = ++_sessionEpoch;
    var saved = false;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _writeSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        clearAccountContext: false,
      );
      saved = isSessionEpochCurrent(epoch);
    });
    return saved;
  }

  Future<bool> saveSessionAtEpoch({
    required int expectedEpoch,
    required String accessToken,
    String? refreshToken,
    required SafeUser user,
  }) async {
    var saved = false;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(expectedEpoch)) return;
      await _writeSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        clearAccountContext: true,
      );
      saved = isSessionEpochCurrent(expectedEpoch);
    });
    return saved;
  }

  Future<String?> readRefreshTokenIfEpoch(int expectedEpoch) async {
    if (!isSessionEpochCurrent(expectedEpoch)) return null;
    final token = await readRefreshToken();
    return isSessionEpochCurrent(expectedEpoch) ? token : null;
  }

  Future<String?> readAccessTokenIfEpoch(int expectedEpoch) async {
    if (!isSessionEpochCurrent(expectedEpoch)) return null;
    final token = await readAccessToken();
    return isSessionEpochCurrent(expectedEpoch) ? token : null;
  }

  Future<void> _writeSession({
    required String accessToken,
    String? refreshToken,
    required SafeUser user,
    required bool clearAccountContext,
  }) async {
    if (clearAccountContext) {
      await _clearAccountContextKey();
    }
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
    final epoch = _sessionEpoch;
    await saveUserIfEpoch(user, epoch);
  }

  Future<bool> saveUserIfEpoch(SafeUser user, int expectedEpoch) async {
    var saved = false;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(expectedEpoch)) return;
      await _saveUser(user);
      saved = isSessionEpochCurrent(expectedEpoch);
    });
    return saved;
  }

  String? readActivePlanId() {
    return _preferences.getString(_activePlanIdKey);
  }

  Future<void> saveActivePlanId(String activePlanId) async {
    final epoch = _sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _preferences.setString(_activePlanIdKey, activePlanId);
    });
  }

  Future<void> clearActivePlanId() async {
    final epoch = _sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _preferences.remove(_activePlanIdKey);
    });
  }

  String? readAccountContextKey() {
    final raw = _sensitiveValueVault != null
        ? _cachedAccountContextKey
        : _preferences.getString(_accountContextKey);
    if (raw == null || raw.isEmpty) return null;
    final selection = _decodeAccountContextSelection(raw);
    if (selection == null) return raw;
    final currentUserId = readUser()?.id;
    if (currentUserId == null || currentUserId != selection.userId) {
      return null;
    }
    return selection.contextKey;
  }

  Future<void> saveAccountContextKey(String contextKey) async {
    final epoch = _sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      final userId = readUser()?.id;
      final storedValue = userId == null
          ? contextKey
          : jsonEncode({
              'version': 2,
              'userId': userId,
              'contextKey': contextKey,
            });
      final vault = _sensitiveValueVault;
      if (vault == null) {
        await _preferences.setString(_accountContextKey, storedValue);
        return;
      }
      await vault.write(_accountContextKey, storedValue);
      await _preferences.remove(_accountContextKey);
      if (isSessionEpochCurrent(epoch)) {
        _cachedAccountContextKey = storedValue;
      }
    });
  }

  Future<void> clearAccountContextKey() async {
    final epoch = _sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _clearAccountContextKey();
    });
  }

  Future<void> clear() async {
    final epoch = ++_sessionEpoch;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _clearStorage();
    });
  }

  Future<bool> clearIfEpoch(int expectedEpoch) async {
    if (!isSessionEpochCurrent(expectedEpoch)) return false;
    final epoch = ++_sessionEpoch;
    var cleared = false;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(epoch)) return;
      await _clearStorage();
      cleared = isSessionEpochCurrent(epoch);
    });
    return cleared;
  }

  /// Clears the session claimed by a terminating flow without advancing its
  /// epoch again. This makes a failed secure-storage deletion retryable while
  /// still rejecting any late cleanup after a replacement session claimed a
  /// newer epoch.
  Future<bool> clearTerminatingSessionAtEpoch(int expectedEpoch) async {
    if (!isSessionEpochCurrent(expectedEpoch)) return false;
    var cleared = false;
    await _enqueueSessionMutation(() async {
      if (!isSessionEpochCurrent(expectedEpoch)) return;
      await _clearStorage();
      cleared = isSessionEpochCurrent(expectedEpoch);
    });
    return cleared;
  }

  Future<void> _clearStorage() async {
    await _tokenVault?.delete();
    await _tokenVault?.deleteRefresh();
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_safeUserKey);
    await _sensitiveValueVault?.delete(_safeUserKey);
    _cachedUser = null;
    await _preferences.remove(_activePlanIdKey);
    await _clearAccountContextKey();
  }

  Future<void> _clearAccountContextKey() async {
    await _sensitiveValueVault?.delete(_accountContextKey);
    await _preferences.remove(_accountContextKey);
    _cachedAccountContextKey = null;
  }

  Future<void> _enqueueSessionMutation(Future<void> Function() mutation) {
    final operation = _sessionMutationTail.then<void>((_) => mutation());
    _sessionMutationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
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

  Future<String> _migrateAccountContextValue(String rawValue) async {
    if (_decodeAccountContextSelection(rawValue) != null) return rawValue;
    final userId = readUser()?.id;
    if (userId == null || userId.isEmpty) return rawValue;
    final migrated = jsonEncode({
      'version': 2,
      'userId': userId,
      'contextKey': rawValue,
    });
    await _sensitiveValueVault?.write(_accountContextKey, migrated);
    return migrated;
  }

  _PersistedAccountContextSelection? _decodeAccountContextSelection(
    String rawValue,
  ) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 2) {
        return null;
      }
      final userId = decoded['userId']?.toString().trim();
      final contextKey = decoded['contextKey']?.toString().trim();
      if (userId == null ||
          userId.isEmpty ||
          contextKey == null ||
          contextKey.isEmpty) {
        return null;
      }
      return _PersistedAccountContextSelection(
        userId: userId,
        contextKey: contextKey,
      );
    } on FormatException {
      return null;
    }
  }
}

class _PersistedAccountContextSelection {
  const _PersistedAccountContextSelection({
    required this.userId,
    required this.contextKey,
  });

  final String userId;
  final String contextKey;
}
