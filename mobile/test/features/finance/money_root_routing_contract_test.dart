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

  test(
    'the application root wires only FinanceApi and MoneyOverviewScreen',
    () {
      // The root takes money (costs and funding) only through the finance
      // owner API, never from its data layer.
      expect(
        main,
        contains(
          "import 'features/finance/finance_api.dart'\n"
          '    show\n'
          '        FinanceApi,\n'
          '        FinanceProvider,\n'
          '        FundingApi,\n'
          '        FundingProvider,\n'
          '        LocalFinancePlanContext;',
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
      // The groom cleanup: «البنود» (c02) and «الدفعات» (c03) replace them.
      "'/wedding-plans/:id/money/costs'",
      "'/wedding-plans/:id/money/schedules'",
      "'/wedding-plans/:id/money/costs/:costId/schedules/create'",
    ]) {
      expect(router, isNot(contains(removedPath)), reason: removedPath);
    }
  });

  test('both shells and the quick add use the one money vocabulary', () {
    final quickAdd = File(
      'lib/features/shell/widgets/plan_quick_add.dart',
    ).readAsStringSync();
    final costAction = File(
      'lib/features/finance/widgets/money_cost_action_picker.dart',
    ).readAsStringSync();
    expect(planShell, contains("'money'"));
    expect(planShell, isNot(contains("'finance'")));
    // D33: both shells run the one «+» flow, which opens today's money forms.
    expect(planShell, contains('PlanQuickAddFlow('));
    expect(mainShell, contains('PlanQuickAddFlow('));
    expect(quickAdd, contains('AppRouter.moneyCostCreate(planId)'));
    expect(quickAdd, contains('AppRouter.moneyCategoryCreate(planId)'));
    expect(quickAdd, contains('MoneyCostActionIntent.payment'));
    expect(quickAdd, contains('MoneyCostActionIntent.schedule'));
    expect(quickAdd, isNot(contains('AppRouter.moneyBudget(planId)')));
    expect(quickAdd, isNot(contains('createFinancialCommitment')));
    expect(quickAdd, isNot(contains('recordPayment')));
    // A payment goes through c07's form, a date through its sheet.
    expect(costAction, contains('AppRouter.moneyPaymentCreate(planId'));
    expect(costAction, contains('showPaymentScheduleSheet('));
  });
}
