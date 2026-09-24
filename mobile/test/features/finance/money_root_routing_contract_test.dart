import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';

void main() {
  // The router's route trees live in per-area part files of the router
  // library (spec M6); the contract reads the whole library.
  final router = readLibrarySource('lib/core/routing/app_router.dart');
  final main = File('lib/main.dart').readAsStringSync();
  final mainShell = File(
    'lib/features/shell/main_shell.dart',
  ).readAsStringSync();
  final planShell = File(
    'lib/features/shell/screens/wedding_plan_shell.dart',
  ).readAsStringSync();
  final quickActions = File(
    'lib/features/wedding_plans/widgets/quick_add_actions.dart',
  ).readAsStringSync();

  test(
    'the application root wires only FinanceApi and MoneyOverviewScreen',
    () {
      expect(
        main,
        contains(
          "import 'features/finance/finance_api.dart'\n"
          '    show FinanceApi, FinanceProvider, LocalFinancePlanContext;',
        ),
      );
      expect(main, isNot(contains("'features/finance/data/")));
      expect(main, contains('Provider<FinanceApi>.value(value: financeApi)'));
      expect(main, isNot(contains('BudgetExpenseApi')));
      expect(mainShell, contains('MoneyOverviewScreen('));
      expect(mainShell, isNot(contains('BudgetExpenseScreen(')));
    },
  );

  test('router registers the real canonical money screens only', () {
    for (final path in <String>[
      '/wedding-plans/:id/money',
      '/wedding-plans/:id/money/budget',
      '/wedding-plans/:id/money/categories/create',
      '/wedding-plans/:id/money/categories/:categoryId',
      '/wedding-plans/:id/money/categories/:categoryId/edit',
      '/wedding-plans/:id/money/costs',
      '/wedding-plans/:id/money/costs/create',
      '/wedding-plans/:id/money/costs/:costId/edit',
    ]) {
      expect(router, contains("path: '$path'"), reason: path);
    }

    for (final removedPath in <String>[
      '/wedding-plans/:id/finance',
      '/wedding-plans/:id/expenses',
      '/wedding-plans/:id/financial-commitments',
      '/wedding-plans/:id/payments/record',
    ]) {
      expect(router, isNot(contains(removedPath)), reason: removedPath);
    }
  });

  test('both shells and quick add use the one money vocabulary', () {
    expect(planShell, contains("'money'"));
    expect(planShell, isNot(contains("'finance'")));
    expect(quickActions, contains('AppRouter.moneyCostCreate(planId)'));
    expect(quickActions, contains('AppRouter.moneyCategoryCreate(planId)'));
    expect(quickActions, contains('onRecordPayment'));
    expect(quickActions, contains('onAddPaymentSchedule'));
    expect(quickActions, isNot(contains('AppRouter.moneyBudget(planId)')));
    expect(quickActions, isNot(contains('createFinancialCommitment')));
    expect(quickActions, isNot(contains('recordPayment')));
  });
}
