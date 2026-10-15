import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// Field test Q03: the server's CATEGORY_EXCEEDED warning was parsed but never
// shown, so an overspent category stayed silent on the money screen.

void main() {
  test('an exceeded category is named with its overrun', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'budget': {'total': '1000000', 'remaining': '200000'},
      'costs': {'total': '800000', 'paid': '0', 'outstanding': '800000'},
      'categories': [
        {'categoryId': 'hall', 'name': 'القاعة', 'allocatedAmount': '500000'},
        {'categoryId': 'gold', 'name': 'الذهب', 'allocatedAmount': '400000'},
      ],
      'warnings': [
        {
          'type': 'CATEGORY_EXCEEDED',
          'severity': 'DANGER',
          'categoryId': 'hall',
          'amount': '300000',
        },
        {'type': 'PAYMENT_SCHEDULE_DUE_SOON', 'severity': 'WARNING'},
      ],
    });

    expect(summary.exceededCategories, [(name: 'القاعة', overrun: '300000')]);
  });

  test('no exceeded category means no warning to show', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'warnings': [
        {'type': 'BUDGET_EXCEEDED', 'severity': 'DANGER', 'amount': '1'},
      ],
    });

    expect(summary.exceededCategories, isEmpty);
  });
}
