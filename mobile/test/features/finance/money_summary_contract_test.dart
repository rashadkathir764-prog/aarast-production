import 'package:aarast_mobile/features/finance/models/money_formatters.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the canonical one-money summary contract', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'SAR',
      'budget': {
        'total': '120000',
        'allocated': '80000',
        'unallocated': '40000',
        'confirmedCost': '50000',
        'remaining': '70000',
      },
      'costs': {
        'total': '50000',
        'paid': '15000',
        'outstanding': '35000',
        'count': 2,
      },
      'paymentSchedules': {
        'upcomingCount': 1,
        'overdueCount': 0,
        'next': {
          'id': 'schedule-1',
          'costId': 'cost-1',
          'amount': '10000',
          'dueDate': '2026-08-01T00:00:00.000Z',
          'status': 'PENDING',
        },
      },
      'categories': [
        {
          'categoryId': 'category-1',
          'name': 'الصالة',
          'allocatedAmount': '80000',
          'confirmedCost': '50000',
          'paid': '15000',
          'outstanding': '35000',
          'remainingAllocation': '30000',
          'costsCount': 2,
        },
      ],
      'warnings': [
        {'type': 'BUDGET_NEAR_LIMIT', 'severity': 'WARNING', 'amount': '10000'},
      ],
      'permissions': {'canViewMoney': true, 'canManageMoney': false},
    });

    expect(summary.planId, 'plan-1');
    expect(summary.currency, 'SAR');
    expect(summary.budget.total, '120000');
    expect(summary.costs.paid, '15000');
    expect(summary.costs.outstanding, '35000');
    expect(summary.paymentSchedules.next?.costId, 'cost-1');
    expect(summary.categories.single.name, 'الصالة');
    expect(summary.categories.single.costsCount, 2);
    expect(summary.permissions.canViewMoney, isTrue);
    expect(summary.permissions.canManageMoney, isFalse);
    expect(summary.healthStatus, 'WARNING');
  });

  test('an unset general budget remains unset even with categories', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'budget': {
        'total': null,
        'allocated': '500000',
        'unallocated': null,
        'confirmedCost': '100000',
        'remaining': null,
      },
      'categories': [
        {
          'categoryId': 'category-1',
          'name': 'الصالة',
          'allocatedAmount': '500000',
        },
      ],
    });

    expect(summary.hasBudget, isFalse);
    expect(summary.budget.total, isNull);
    expect(summary.categories.single.allocatedAmount, '500000');
    expect(summary.healthStatus, 'UNSET');
  });

  test('compact money formatting keeps number, unit and dynamic currency', () {
    expect(
      plainCompactMoneyForTests(1500000, currencyCode: 'YER'),
      '1.5 مليون ر.ي',
    );
    expect(
      plainCompactMoneyForTests(-10500000, currencyCode: 'SAR'),
      '-10.5 مليون ر.س',
    );
    expect(
      compactMoneyParts(1500, currencyCode: 'USD').semanticText,
      contains('دولار أمريكي'),
    );
  });

  testWidgets('MoneyAmountText is overflow-safe at 320px RTL', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 180);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 150,
              child: MoneyAmountText(amount: 118400000, currency: 'YER'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MoneyAmountText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
