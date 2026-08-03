import 'dart:convert';

import 'package:aarast_mobile/core/session/pending_account_deletion.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists one stable secure deletion request across restart', () async {
    final vault = _MemoryVault();
    final first = PendingAccountDeletionStore(vault);
    final record = await first.putIfAbsent('user-a');
    final restarted = PendingAccountDeletionStore(vault);

    final restored = await restarted.putIfAbsent('user-a');
    expect(restored.clientRequestId, record.clientRequestId);
    expect(restored.userId, 'user-a');
    expect(vault.values.keys, [PendingAccountDeletionStore.storageKey]);
  });

  test('ordinary storage remains until confirmed deletion teardown', () async {
    final vault = _MemoryVault();
    final store = PendingAccountDeletionStore(vault);
    final record = await store.putIfAbsent('user-a');

    expect((await store.read())?.clientRequestId, record.clientRequestId);
    await store.removeForDeletedUser('another-user');
    expect(await store.read(), isNotNull);
    await store.removeForDeletedUser('user-a');
    expect(await store.read(), isNull);
  });

  test('definitive rejection removes only the matching command', () async {
    final vault = _MemoryVault();
    final store = PendingAccountDeletionStore(vault);
    final record = await store.putIfAbsent('user-a');

    await store.removeAfterDefinitiveRejection(record);
    expect(await store.read(), isNull);
  });

  test('malformed secure state fails closed', () async {
    final vault = _MemoryVault();
    vault.values[PendingAccountDeletionStore.storageKey] = jsonEncode({
      'version': 1,
      'userId': 'user-a',
    });

    await expectLater(
      PendingAccountDeletionStore(vault).read(),
      throwsA(isA<FormatException>()),
    );
  });
}

class _MemoryVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
