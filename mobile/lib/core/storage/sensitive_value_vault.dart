import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SensitiveValueVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureSensitiveValueVault implements SensitiveValueVault {
  const SecureSensitiveValueVault([this._storage = _defaultStorage]);

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'aarast_sensitive_state',
      resetOnError: false,
      migrateWithBackup: true,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
