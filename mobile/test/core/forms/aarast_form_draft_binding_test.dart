import 'package:aarast_mobile/core/forms/aarast_form_draft_binding.dart';
import 'package:aarast_mobile/core/forms/aarast_form_draft_store.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores text and extras without rewriting the snapshot', () async {
    final fixture = await _fixture();
    await fixture.store.write('provider:service:new', {
      'title': 'التصوير',
      'categoryId': 'photography',
    });
    final writesBeforeRestore = fixture.vault.writeCount;
    final title = TextEditingController();
    addTearDown(title.dispose);

    String? restoredCategory;
    final binding = AarastFormDraftBinding(
      store: fixture.store,
      scope: 'provider:service:new',
      fields: {'title': title},
      restoreExtras: (data) =>
          restoredCategory = data['categoryId']?.toString(),
    );
    addTearDown(binding.dispose);

    expect(await binding.restore(), isTrue);
    expect(title.text, 'التصوير');
    expect(restoredCategory, 'photography');
    expect(fixture.vault.writeCount, writesBeforeRestore);
  });

  test(
    'debounces controller and extra changes into one secure draft',
    () async {
      final fixture = await _fixture();
      final title = TextEditingController();
      addTearDown(title.dispose);

      var category = 'venue';
      final binding = AarastFormDraftBinding(
        store: fixture.store,
        scope: 'provider:service:new',
        fields: {'title': title},
        readExtras: () => {'categoryId': category},
      );
      addTearDown(binding.dispose);

      title.text = 'قاعة';
      category = 'photo';
      binding.changed();
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(await fixture.store.read('provider:service:new'), {
        'title': 'قاعة',
        'categoryId': 'photo',
      });
    },
  );
}

Future<({AarastFormDraftStore store, _MemorySensitiveValueVault vault})>
_fixture() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final vault = _MemorySensitiveValueVault();
  return (
    store: AarastFormDraftStore(
      vault: vault,
      authStorage: AuthStorage(preferences),
    ),
    vault: vault,
  );
}

class _MemorySensitiveValueVault implements SensitiveValueVault {
  final Map<String, String> values = <String, String>{};
  int writeCount = 0;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount += 1;
    values[key] = value;
  }
}
