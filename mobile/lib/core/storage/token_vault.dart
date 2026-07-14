import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secure token persistence so the auth layer can be
/// tested without platform channels while production uses the OS keystore.
abstract class TokenVault {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();

  Future<String?> readRefresh();

  Future<void> writeRefresh(String token);

  Future<void> deleteRefresh();
}

/// Production vault backed by the platform keystore/keychain via
/// flutter_secure_storage.
///
/// Aarast handles private money data: the JWT unlocks budgets, costs and
/// payment schedules, so it must never live in plaintext SharedPreferences.
class SecureTokenVault implements TokenVault {
  const SecureTokenVault([this._storage = _defaultStorage]);

  static const _accessTokenKey = 'aarast_access_token';
  static const _refreshTokenKey = 'aarast_refresh_token';

  static const _defaultStorage = FlutterSecureStorage(
    // v10 migrates legacy encrypted SharedPreferences data to its modern
    // RSA-OAEP + AES-GCM storage automatically when algorithms change.
    aOptions: AndroidOptions(),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } on Object {
      // A corrupted keystore entry must degrade to "not signed in",
      // never crash the splash flow. The user simply logs in again.
      return null;
    }
  }

  @override
  Future<void> write(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<void> delete() {
    return _storage.delete(key: _accessTokenKey);
  }

  @override
  Future<String?> readRefresh() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeRefresh(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> deleteRefresh() {
    return _storage.delete(key: _refreshTokenKey);
  }
}
