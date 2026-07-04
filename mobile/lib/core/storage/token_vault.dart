import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secure token persistence so the auth layer can be
/// tested without platform channels while production uses the OS keystore.
abstract class TokenVault {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

/// Production vault backed by the platform keystore/keychain via
/// flutter_secure_storage.
///
/// Aarast is a financial app: the JWT unlocks budgets, debts and
/// installments, so it must never live in plaintext SharedPreferences.
class SecureTokenVault implements TokenVault {
  const SecureTokenVault([this._storage = _defaultStorage]);

  static const _accessTokenKey = 'aarast_access_token';

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
}
