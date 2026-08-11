import 'package:aarast_mobile/core/forms/aarast_form_draft_store.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'secure form drafts are account scoped and clearable as one graph',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final vault = _MemorySensitiveValueVault();
      final store = AarastFormDraftStore(
        vault: vault,
        authStorage: authStorage,
      );

      await authStorage.saveSession(
        accessToken: 'test-token-one',
        user: _user('user-1'),
      );
      await store.write('guest:plan-1:new', {
        'name': 'ضيف محفوظ',
        'phone': '+967777000000',
      });

      expect(await store.read('guest:plan-1:new'), {
        'name': 'ضيف محفوظ',
        'phone': '+967777000000',
      });
      expect(
        preferences.getKeys().where((key) => key.contains('form-draft')),
        isEmpty,
        reason: 'Private form values must never use plaintext preferences.',
      );

      await authStorage.saveSession(
        accessToken: 'test-token-two',
        user: _user('user-2'),
      );
      expect(await store.read('guest:plan-1:new'), isNull);

      await store.write('cost:plan-2:new', {'total': '250000'});
      expect(await store.read('cost:plan-2:new'), {'total': '250000'});

      await store.clearAll();
      expect(await store.read('cost:plan-2:new'), isNull);
      expect(
        vault.values.keys.where((key) => key.contains('form-draft')),
        isEmpty,
      );
    },
  );
}

SafeUser _user(String id) {
  return SafeUser(
    id: id,
    name: 'مستخدم اختبار',
    role: 'USER',
    status: 'ACTIVE',
  );
}

class _MemorySensitiveValueVault implements SensitiveValueVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
