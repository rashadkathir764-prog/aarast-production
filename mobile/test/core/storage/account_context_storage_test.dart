import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
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
      final storage = AuthStorage(preferences);

      await storage.saveAccountContextKey('plan:plan-1:owner');
      expect(storage.readAccountContextKey(), 'plan:plan-1:owner');

      await storage.clearAccountContextKey();
      expect(storage.readAccountContextKey(), isNull);
      expect(storage.readActivePlanId(), 'plan-previous');
    },
  );

  test('session clear removes the persisted context key', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    await storage.saveAccountContextKey('provider:provider-1');

    await storage.clear();

    expect(storage.readAccountContextKey(), isNull);
  });

  test(
    'production wiring migrates the context key to secure storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'aarast_account_context_key': 'plan:plan-1:owner',
      });
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = AuthStorage(preferences, sensitiveValueVault: vault);

      await storage.initialize();

      expect(storage.readAccountContextKey(), 'plan:plan-1:owner');
      expect(preferences.getString('aarast_account_context_key'), isNull);
      expect(vault.values['aarast_account_context_key'], 'plan:plan-1:owner');

      await storage.clear();
      expect(vault.values['aarast_account_context_key'], isNull);
    },
  );
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
