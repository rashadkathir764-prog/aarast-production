import 'dart:convert';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AuthStorage persists and explicitly clears only the context key',
    () async {
      SharedPreferences.setMockInitialValues({
        'aarast_active_plan_id': 'plan-previous',
      });
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = AuthStorage(preferences, sensitiveValueVault: vault);
      await storage.initialize();
      await storage.saveSession(
        accessToken: 'access-user-a',
        user: _user('user-a'),
      );

      await storage.saveAccountContextKey('plan:plan-1:owner');
      expect(storage.readAccountContextKey(), 'plan:plan-1:owner');

      await storage.clearAccountContextKey();
      expect(storage.readAccountContextKey(), isNull);
      expect(storage.readActivePlanId(), 'plan-previous');
    },
  );

  test('a v2 context selection is rejected for a different user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final vault = _MemorySensitiveVault();
    final storage = AuthStorage(preferences, sensitiveValueVault: vault);
    await storage.initialize();
    await storage.saveSession(
      accessToken: 'access-user-a',
      user: _user('user-a'),
    );
    await storage.saveAccountContextKey('provider:provider-1');

    final persistedSelection = _decodeV2Selection(vault);
    expect(persistedSelection, {
      'version': 2,
      'userId': 'user-a',
      'contextKey': 'provider:provider-1',
    });

    await storage.saveSession(
      accessToken: 'access-user-b',
      user: _user('user-b'),
    );

    expect(
      storage.readAccountContextKey(),
      isNull,
      reason: 'user-b must never inherit user-a context selection',
    );
  });

  test(
    'full session clear removes the persisted v2 context selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = AuthStorage(preferences, sensitiveValueVault: vault);
      await storage.initialize();
      await storage.saveSession(
        accessToken: 'access-user-a',
        user: _user('user-a'),
      );
      await storage.saveAccountContextKey('provider:provider-1');
      expect(_decodeV2Selection(vault)['userId'], 'user-a');

      await storage.clear();

      expect(storage.readAccountContextKey(), isNull);
      expect(vault.values['aarast_account_context_key'], isNull);
    },
  );

  test('a valid legacy context is accepted once then migrated to v2', () async {
    SharedPreferences.setMockInitialValues({
      'aarast_safe_user': jsonEncode(_user('legacy-user').toJson()),
      'aarast_account_context_key': 'provider:legacy-provider',
    });
    final preferences = await SharedPreferences.getInstance();
    final vault = _MemorySensitiveVault();
    final storage = AuthStorage(preferences, sensitiveValueVault: vault);

    await storage.initialize();

    expect(storage.readAccountContextKey(), 'provider:legacy-provider');
    expect(preferences.getString('aarast_account_context_key'), isNull);
    expect(_decodeV2Selection(vault), {
      'version': 2,
      'userId': 'legacy-user',
      'contextKey': 'provider:legacy-provider',
    });

    await preferences.setString(
      'aarast_account_context_key',
      'provider:stale-legacy-provider',
    );
    final restartedStorage = AuthStorage(
      preferences,
      sensitiveValueVault: vault,
    );
    await restartedStorage.initialize();

    expect(
      restartedStorage.readAccountContextKey(),
      'provider:legacy-provider',
    );
    expect(preferences.getString('aarast_account_context_key'), isNull);
  });

  test(
    'a replacement login after full logout cannot restore the old role for the same multi-role user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = AuthStorage(preferences, sensitiveValueVault: vault);
      await storage.initialize();
      final user = _user('multi-role-user');
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        user: user,
      );
      await storage.saveAccountContextKey('provider:provider-1');

      final logoutEpoch = storage.beginSessionInvalidation();
      final replacementLoginEpoch = storage.beginSessionEstablishment();
      expect(
        await storage.saveSessionAtEpoch(
          expectedEpoch: replacementLoginEpoch,
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          user: user,
        ),
        isTrue,
      );
      expect(await storage.clearIfEpoch(logoutEpoch), isFalse);

      expect(storage.readUser()?.id, 'multi-role-user');
      expect(
        storage.readAccountContextKey(),
        isNull,
        reason:
            'a new login must choose among owner/provider contexts instead of restoring the old provider role',
      );
    },
  );
}

SafeUser _user(String id) {
  return SafeUser(id: id, name: 'Test User', role: 'USER', status: 'ACTIVE');
}

Map<String, dynamic> _decodeV2Selection(_MemorySensitiveVault vault) {
  final raw = vault.values['aarast_account_context_key'];
  expect(raw, isNotNull);
  expect(
    raw,
    startsWith('{'),
    reason: 'the secure value must be a user-bound v2 record, not a raw key',
  );
  return Map<String, dynamic>.from(jsonDecode(raw!) as Map);
}

class _MemorySensitiveVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
