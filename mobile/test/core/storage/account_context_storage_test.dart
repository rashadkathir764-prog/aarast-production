import 'package:aarast_mobile/core/storage/auth_storage.dart';
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
}
