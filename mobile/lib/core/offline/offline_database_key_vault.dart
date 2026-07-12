import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class OfflineSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterOfflineSecretStore implements OfflineSecretStore {
  const FlutterOfflineSecretStore([this._storage = _defaultStorage]);

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'aarast_offline_database',
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
}

typedef OfflineKeyGenerator = Uint8List Function();

class OfflineDatabaseKeyVault {
  OfflineDatabaseKeyVault({
    OfflineSecretStore store = const FlutterOfflineSecretStore(),
    OfflineKeyGenerator? keyGenerator,
  }) : _store = store,
       _keyGenerator = keyGenerator ?? _generateSecureKey;

  static const storageKey = 'aarast_offline_database_key_v1';
  static const keyBytes = 32;

  final OfflineSecretStore _store;
  final OfflineKeyGenerator _keyGenerator;

  Future<String> readOrCreate() async {
    final existing = await _store.read(storageKey);
    if (existing != null) {
      _validate(existing);
      return existing;
    }

    final bytes = _keyGenerator();
    if (bytes.length != keyBytes) {
      throw StateError('Offline database key generation failed');
    }
    final generated = base64UrlEncode(bytes);
    await _store.write(storageKey, generated);
    final persisted = await _store.read(storageKey);
    if (persisted != generated) {
      throw StateError('Offline database key could not be persisted securely');
    }
    _validate(persisted!);
    return persisted;
  }

  static Uint8List _generateSecureKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyBytes, (_) => random.nextInt(256)),
    );
  }

  static void _validate(String value) {
    try {
      if (base64Url.decode(value).length != keyBytes) {
        throw const FormatException();
      }
    } on FormatException {
      throw StateError('Offline database key is invalid');
    }
  }
}
