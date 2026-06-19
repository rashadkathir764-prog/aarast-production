import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildTab', () {
    test('defines exactly the approved five user navigation tabs', () {
      expect(UserRebuildTab.values, hasLength(5));
      expect(UserRebuildTab.values.map((tab) => tab.name), [
        'home',
        'money',
        'tasks',
        'providers',
        'more',
      ]);
    });

    test('uses the approved Arabic labels', () {
      expect(UserRebuildTab.values.map((tab) => tab.label), [
        'الرئيسية',
        'المال',
        'المهام',
        'الموردون',
        'المزيد',
      ]);
    });

    test('keeps money as a plan-required tab', () {
      expect(UserRebuildTab.money.label, 'المال');
      expect(UserRebuildTab.money.requiresCurrentPlan, isTrue);
      expect(UserRebuildTab.money.semanticPurpose, contains('financial'));
    });
  });
}
