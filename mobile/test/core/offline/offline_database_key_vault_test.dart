import 'dart:typed_data';
import 'dart:io';

import 'package:aarast_mobile/core/offline/offline_database_key_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native release configuration preserves SQLCipher and Keychain access',
    () {
      final proguard = File(
        'android/app/proguard-rules.pro',
      ).readAsStringSync();
      final vault = File(
        'lib/core/offline/offline_database_key_vault.dart',
      ).readAsStringSync();
      final entitlements = [
        'ios/Runner/Runner.entitlements',
        'macos/Runner/DebugProfile.entitlements',
        'macos/Runner/Release.entitlements',
      ].map((path) => File(path).readAsStringSync());

      // RA-MO-104: sqflite_sqlcipher 3.4 uses net.zetetic's SQLCipher; the
      // old net.sqlcipher rule kept a package that is no longer there.
      expect(
        proguard,
        contains('-keep class net.zetetic.database.sqlcipher.** { *; }'),
      );
      expect(proguard, isNot(contains('-keep class net.sqlcipher.')));
      expect(vault, contains("storageNamespace: 'aarast_offline_database'"));
      expect(vault, contains('resetOnError: false'));
      expect(vault, contains('migrateWithBackup: true'));
      for (final source in entitlements) {
        expect(source, contains('<key>keychain-access-groups</key>'));
        expect(
          source,
          contains(r'$(AppIdentifierPrefix)$(CFBundleIdentifier)'),
        );
      }
    },
  );

  test('creates one 256-bit database key and reuses it', () async {
    final store = _MemorySecretStore();
    var generations = 0;
    final vault = OfflineDatabaseKeyVault(
      store: store,
      keyGenerator: () {
        generations += 1;
        return Uint8List.fromList(List<int>.generate(32, (index) => index));
      },
    );

    final first = await vault.readOrCreate();
    final second = await vault.readOrCreate();

    expect(first, second);
    expect(generations, 1);
    expect(store.values.keys, [OfflineDatabaseKeyVault.storageKey]);
    expect(first, isNot(contains('aarast')));
  });

  test('refuses a corrupted keystore value instead of replacing it', () async {
    final store = _MemorySecretStore()
      ..values[OfflineDatabaseKeyVault.storageKey] = 'invalid';
    final vault = OfflineDatabaseKeyVault(store: store);

    await expectLater(vault.readOrCreate(), throwsStateError);
    expect(store.values[OfflineDatabaseKeyVault.storageKey], 'invalid');
  });

  test('fails closed when secure persistence cannot be confirmed', () async {
    final vault = OfflineDatabaseKeyVault(
      store: _DroppingSecretStore(),
      keyGenerator: () => Uint8List(32),
    );

    await expectLater(vault.readOrCreate(), throwsStateError);
  });

  test(
    'keystore read errors never generate a replacement database key',
    () async {
      var generations = 0;
      final vault = OfflineDatabaseKeyVault(
        store: _ThrowingSecretStore(),
        keyGenerator: () {
          generations += 1;
          return Uint8List(32);
        },
      );

      await expectLater(vault.readOrCreate(), throwsA(isA<StateError>()));
      expect(generations, 0);
    },
  );
}

class _MemorySecretStore implements OfflineSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DroppingSecretStore implements OfflineSecretStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

class _ThrowingSecretStore implements OfflineSecretStore {
  @override
  Future<String?> read(String key) {
    throw StateError('keystore unavailable');
  }

  @override
  Future<void> write(String key, String value) {
    throw StateError('must not write');
  }
}
