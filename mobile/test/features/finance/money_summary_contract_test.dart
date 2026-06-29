import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/money_formatters.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/widgets/yemeni_money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const localPlanId = 'guest-plan-money-contract';

  test('parses backend Super 2 money summary fields', () {
    final summary = MoneySummary.fromJson({
      'weddingPlanId': 'plan-1',
      'currency': 'YER',
      'totalBudget': '120000000',
      'totalSpent': '1600000',
      'remainingBudget': '118400000',
      'totalDebts': '3000000',
      'debtRemaining': '2500000',
      'paidInstallmentsCount': 2,
      'remainingInstallmentsCount': 3,
      'overdueInstallmentsCount': 1,
      'nextInstallment': {
        'id': 'inst-1',
        'debtId': 'debt-1',
        'amount': '500000',
        'dueAt': '2026-07-01T00:00:00.000Z',
        'status': 'PENDING',
      },
      'categorySummaries': [
        {
          'categoryId': 'cat-1',
          'name': 'القاعة',
          'allocated': '1000000',
          'spent': '250000',
          'remaining': '750000',
          'expensesCount': 1,
          'overBudget': false,
        },
      ],
      'financialWarnings': [
        {
          'type': 'INSTALLMENT_OVERDUE',
          'severity': 'DANGER',
          'message': 'Installment overdue',
          'count': 1,
        },
      ],
      'categoriesCount': 1,
      'expensesCount': 1,
      'debtsCount': 1,
      'installmentsCount': 5,
    });

    expect(summary.totalBudget, '120000000');
    expect(summary.totalSpent, '1600000');
    expect(summary.remainingBudget, '118400000');
    expect(summary.debtRemaining, '2500000');
    expect(summary.nextInstallment?.amount, '500000');
    expect(summary.categorySummaries.single.name, 'القاعة');
    expect(summary.financialWarnings.single.type, 'INSTALLMENT_OVERDUE');
    expect(summary.budgetStatus, 'DANGER');
  });

  test('formats Yemeni money without confusing prefix forms', () {
    expect(plainCompactYemeniMoneyForTests(120000000), '120م ر.ي');
    expect(plainCompactYemeniMoneyForTests(1500000), '1.5م ر.ي');
    expect(plainCompactYemeniMoneyForTests(5200000), '5.2م ر.ي');
    expect(plainCompactYemeniMoneyForTests(-1500000), '-1.5م ر.ي');
    expect(plainCompactYemeniMoneyForTests(1600000), '1.6م ر.ي');
    expect(plainCompactYemeniMoneyForTests(118400000), '118م ر.ي');
    expect(plainCompactYemeniMoneyForTests(5300000), '5.3م ر.ي');
    expect(plainCompactYemeniMoneyForTests(120000000).startsWith('م'), isFalse);
    expect(formatCompactYemeniMoney(5300000), isNot(contains('M ر.ي')));
    expect(
      stripMoneyDirectionalityMarks(formatCompactYemeniMoney(5300000)),
      isNot(contains('ر.ي م')),
    );
    expect(plainCompactYemeniMoneyForTests(120), isNot(contains('م120')));
  });

  testWidgets(
    'YemeniMoneyText keeps number unit and currency in stable order',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              YemeniMoneyText(1500000),
              YemeniMoneyText(5200000),
              YemeniMoneyText(-1500000),
            ],
          ),
        ),
      );

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '')
          .join('\n');

      expect(rendered, contains('1.5م ر.ي'));
      expect(rendered, contains('5.2م ر.ي'));
      expect(rendered, contains('-1.5م ر.ي'));
      expect(rendered, isNot(contains('ر.ي م')));
      expect(rendered, isNot(contains('M ر.ي')));
      expect(rendered, isNot(contains('م120')));
    },
  );

  test('debts screen uses the shared Arabic Yemeni formatter', () {
    final source = File(
      'lib/features/debts/screens/debt_installment_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("import '../../finance/widgets/yemeni_money_text.dart';"),
    );
    expect(source, contains('YemeniMoneyText('));
    expect(source, isNot(contains('formatCompactYemeniMoney(value)')));
    expect(source, isNot(contains('M ر.ي')));
    expect(source, isNot(contains("'+ إضافة دين جديد'")));
    expect(source, isNot(contains('label: const Text(\'+')));
  });

  test(
    'zero budget with spending is not presented as a zero percent success',
    () {
      const summary = MoneySummary(
        weddingPlanId: 'plan-zero-budget',
        totalBudget: '0',
        totalSpent: '1500000',
        remainingBudget: '-1500000',
      );
      expect(summary.hasUsableBudget, isFalse);
      expect(summary.hasSpendingWithoutBudget, isTrue);
      expect(summary.budgetStatus, 'OVER_BUDGET');
    },
  );

  test('money screen does not expose fake Super 3 task actions', () {
    final source = File(
      'lib/features/finance/screens/budget_expense_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('إنشاء مهمة متابعة')));
    expect(source, isNot(contains('إضافة مهمة')));
    expect(source, isNot(contains('طلب عرض سعر')));
    expect(source, isNot(contains('انضم كمزود')));
  });

  test(
    'local money summary reflects expenses debts and due installment',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final apiClient = ApiClient(tokenProvider: () async => null);
      final database = await createLocalDatabase(preferences);
      final offline = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      final financeApi = BudgetExpenseApi(apiClient, offline: offline);
      final debtApi = DebtInstallmentApi(apiClient, offline: offline);

      await financeApi.createBudgetCategory(
        weddingPlanId: localPlanId,
        name: 'القاعة',
        targetAmount: '1000000',
      );
      await financeApi.createExpense(
        weddingPlanId: localPlanId,
        title: 'عربون القاعة',
        amount: '250000',
        status: 'PAID',
      );
      final debt = await debtApi.createDebt(
        weddingPlanId: localPlanId,
        creditorName: 'القاعة',
        title: 'باقي القاعة',
        totalAmount: '500000',
        paidAmount: '100000',
      );
      await debtApi.createInstallment(
        debtId: debt.id,
        amount: '200000',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      );

      final summary = await financeApi.getMoneySummary(localPlanId);

      expect(summary.totalBudget, '1000000.00');
      expect(summary.totalSpent, '250000.00');
      expect(summary.remainingBudget, '750000.00');
      expect(summary.totalDebts, '500000.00');
      expect(summary.debtRemaining, '400000.00');
      expect(summary.nextInstallment?.amount, '200000');
      expect(
        summary.financialWarnings.map((warning) => warning.type),
        contains('INSTALLMENT_DUE_SOON'),
      );
    },
  );
}
