import 'package:aarast_mobile/features/catalogs/catalogs_api.dart';
import 'package:aarast_mobile/features/finance/finance_api.dart';
import 'package:flutter_test/flutter_test.dart';

ManagedReferenceCatalog _managed() => ManagedReferenceCatalog.fromJson({
  'key': 'money.starter.categories',
  'items': [
    {
      'key': 'groom-mahr',
      'nameAr': 'المهر والاتفاقات',
      'isRecommended': true,
      'showForGroom': true,
      'showForCustomer': true,
      'sortOrder': 1,
    },
    {
      'key': 'groom-venue',
      'nameAr': 'قاعة الرجال',
      'isRecommended': true,
      'showForGroom': true,
      'showForCustomer': true,
      'sortOrder': 2,
    },
    {
      'key': 'groom-audio',
      'nameAr': 'الصوت والإضاءة',
      'isRecommended': false,
      'showForGroom': true,
      'showForCustomer': true,
      'sortOrder': 3,
    },
  ],
});

void main() {
  test('a new groom plan never starts with the mahr as a budget item (C1)', () {
    final names = moneyStarterPlanItemNames(null, 'GROOM');
    expect(names, isNotEmpty);
    expect(names, isNot(contains('المهر والاتفاقات')));
    expect(
      moneyStarterPlanItemNames(null, null),
      isNot(contains('المهر والذهب')),
    );
  });

  test('the managed catalog wins, minus the mahr and the optional rows', () {
    expect(moneyStarterPlanItemNames(_managed(), 'GROOM'), ['قاعة الرجال']);
  });
}
