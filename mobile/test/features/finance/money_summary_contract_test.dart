import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
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
      'commitmentTotal': '3000000',
      'commitmentRemainingTotal': '2500000',
      'paidInstallmentsCount': 2,
      'remainingInstallmentsCount': 3,
      'overdueInstallmentsCount': 1,
      'nextInstallment': {
        'id': 'inst-1',
        'financialCommitmentId': 'commitment-1',
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
      'commitmentsCount': 1,
      'installmentsCount': 5,
    });

    expect(summary.totalBudget, '120000000');
    expect(summary.totalSpent, '1600000');
    expect(summary.remainingBudget, '118400000');
    expect(summary.commitmentRemainingTotal, '2500000');
    expect(summary.nextInstallment?.amount, '500000');
    expect(summary.categorySummaries.single.name, 'القاعة');
    expect(summary.financialWarnings.single.type, 'INSTALLMENT_OVERDUE');
    expect(summary.budgetStatus, 'DANGER');
  });

  test('formats Yemeni money without confusing prefix forms', () {
    expect(plainCompactYemeniMoneyForTests(120000000), '120 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(1500000), '1.5 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(5200000), '5.2 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(-1500000), '-1.5 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(1600000), '1.6 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(10500000), '10.5 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(118400000), '118.4 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(5300000), '5.3 مليون ر.ي');
    expect(plainCompactYemeniMoneyForTests(120000000).startsWith('م'), isFalse);
    expect(formatCompactYemeniMoney(5300000), isNot(contains('M ر.ي')));
    expect(
      stripMoneyDirectionalityMarks(formatCompactYemeniMoney(5300000)),
      isNot(contains('ر.ي م')),
    );
    expect(plainCompactYemeniMoneyForTests(120), isNot(contains('م120')));
  });

  test('formats compact money with the selected plan currency', () {
    expect(
      plainCompactMoneyForTests(1500000, currencyCode: 'SAR'),
      '1.5 مليون ر.س',
    );
    expect(plainCompactMoneyForTests(1500, currencyCode: 'USD'), '1,500 دولار');
    expect(plainCompactMoneyForTests(1500, currencyCode: 'YER'), '1,500 ر.ي');
  });

  testWidgets('YemeniMoneyText keeps clear number unit and currency tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            YemeniMoneyText(1500000, currencyCode: 'YER'),
            YemeniMoneyText(5200000, currencyCode: 'YER'),
            YemeniMoneyText(-1500000, currencyCode: 'YER'),
          ],
        ),
      ),
    );

    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('5.2'), findsOneWidget);
    expect(find.text('-1.5'), findsOneWidget);
    expect(find.text('مليون'), findsNWidgets(3));
    expect(find.text('ر.ي'), findsNWidgets(3));
  });

  testWidgets(
    'compact money exposes a clear million word in stable visual order',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(child: YemeniMoneyText(1500000, currencyCode: 'YER')),
        ),
      );

      final money = find.byType(YemeniMoneyText);
      final number = find.descendant(of: money, matching: find.text('1.5'));
      final unit = find.descendant(of: money, matching: find.text('مليون'));
      final currency = find.descendant(of: money, matching: find.text('ر.ي'));

      expect(number, findsOneWidget);
      expect(unit, findsOneWidget);
      expect(currency, findsOneWidget);
      expect(
        tester.getTopLeft(number).dx,
        lessThan(tester.getTopLeft(unit).dx),
      );
      expect(
        tester.getTopLeft(unit).dx,
        lessThan(tester.getTopLeft(currency).dx),
      );
      expect(tester.getSemantics(money).label, '1.5 مليون ريال يمني');
    },
  );

  testWidgets('money text renders the selected plan currency', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: YemeniMoneyText(1500000, currencyCode: 'SAR'),
      ),
    );

    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('مليون'), findsOneWidget);
    expect(find.text('ر.س'), findsOneWidget);
  });

  testWidgets('money tokens stay safe at 320px and 1.3 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                YemeniMoneyText(118400000, currencyCode: 'YER'),
                YemeniMoneyText(-10500000, currencyCode: 'SAR'),
                YemeniMoneyText(1500, currencyCode: 'USD'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('118.4'), findsOneWidget);
    expect(find.text('-10.5'), findsOneWidget);
    expect(find.text('دولار'), findsOneWidget);
  });

  test('payables screen uses the shared Arabic money formatter', () {
    final source = File(
      'lib/features/finance/screens/financial_payables_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import '../widgets/yemeni_money_text.dart';"));
    expect(source, contains('YemeniMoneyText('));
    expect(source, isNot(contains('formatCompactYemeniMoney(value)')));
    expect(source, isNot(contains('M ر.ي')));
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

  test('missing budget is never labelled as financially safe', () {
    const summary = MoneySummary(weddingPlanId: 'plan-no-budget');
    expect(summary.budgetStatus, 'NO_BUDGET');
  });

  test('legacy debt feature directory is permanently removed', () {
    final legacyDirectory = Directory('lib/features/debts');
    expect(
      legacyDirectory.existsSync()
          ? legacyDirectory
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart'))
                .isEmpty
          : true,
      isTrue,
    );
    expect(
      File('lib/core/routing/app_router.dart').readAsStringSync(),
      isNot(contains('/debts/')),
    );
    for (final path in [
      'lib/features/auth/screens/login_screen.dart',
      'lib/features/more/screens/more_screen.dart',
      'lib/features/sharing/screens/invite_decision_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('ديون')),
        reason: '$path must use the canonical payables/payment language.',
      );
    }
  });

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
    'money screen keeps payables and activity merged without duplicate rails',
    () {
      final screenSource = File(
        'lib/features/finance/screens/budget_expense_screen.dart',
      ).readAsStringSync();
      final overviewDirectory = Directory(
        'lib/features/finance/widgets/finance_overview',
      );
      expect(overviewDirectory.existsSync(), isTrue);
      const requiredOverviewFiles = [
        'budget_categories_section.dart',
        'expense_delete_confirmation_sheet.dart',
        'finance_overview_components.dart',
        'finance_overview_content.dart',
        'finance_overview_mapper.dart',
        'financial_payables_section.dart',
        'recent_money_activity_section.dart',
      ];
      final overviewFiles = overviewDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      for (final fileName in requiredOverviewFiles) {
        expect(
          File('${overviewDirectory.path}/$fileName').existsSync(),
          isTrue,
          reason: fileName,
        );
      }
      final overviewSources = overviewFiles
          .map((file) => file.readAsStringSync())
          .join('\n');
      final source = '$screenSource\n$overviewSources';

      expect(screenSource.split('\n').length, lessThanOrEqualTo(240));
      expect(screenSource, contains('FinanceOverviewContent'));
      expect(
        screenSource,
        contains("finance_overview/finance_overview_content.dart"),
      );
      for (final file in overviewFiles) {
        expect(file.readAsStringSync(), isNot(contains('part of ')));
      }
      expect(source, contains('class FinancialPayablesSection'));
      expect(source, contains('class RecentMoneyActivitySection'));
      expect(source, isNot(contains('hasLegacyDebtData')));
      expect(source, isNot(contains('سجل الديون القديم')));
      expect(source, isNot(contains('_FinanceActionStrip')));
      expect(source, isNot(contains('_FinancialPaymentsSection')));
      expect(source, isNot(contains('_FinancialInstallmentsSection')));
      expect(source, isNot(contains('PaymentTimelineRail(')));
    },
  );

  test(
    'local money summary reflects expenses commitments and due installment',
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

      final category = await financeApi.createBudgetCategory(
        weddingPlanId: localPlanId,
        name: 'القاعة',
        targetAmount: '1000000',
      );
      await financeApi.createExpense(
        weddingPlanId: localPlanId,
        title: 'دفعة القاعة',
        amount: '250000',
        budgetCategoryId: category.id,
        status: 'PAID',
      );
      final commitment = await financeApi.createFinancialCommitment(
        weddingPlanId: localPlanId,
        budgetCategoryId: category.id,
        partyName: 'القاعة',
        title: 'باقي القاعة',
        totalAmount: '500000',
        paidAmount: '100000',
        sourceType: 'MANUAL_PAYABLE',
      );
      await financeApi.createFinancialInstallment(
        commitmentId: commitment.id,
        amount: '200000',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      );

      final summary = await financeApi.getMoneySummary(localPlanId);

      expect(summary.totalBudget, '1000000.00');
      expect(summary.totalSpent, '250000.00');
      expect(summary.confirmedCostTotal, '750000.00');
      expect(summary.remainingBudget, '250000.00');
      expect(summary.commitmentTotal, '500000.00');
      expect(summary.commitmentRemainingTotal, '400000.00');
      expect(summary.nextInstallment?.amount, '200000');
      expect(
        summary.financialWarnings.map((warning) => warning.type),
        contains('INSTALLMENT_DUE_SOON'),
      );
    },
  );

  test(
    'local money summary uses the guest plan budget before category totals',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final apiClient = ApiClient(tokenProvider: () async => null);
      final database = await createLocalDatabase(preferences);
      final offline = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      final financeApi = BudgetExpenseApi(
        apiClient,
        offline: offline,
        localPlanContextLoader: (_) async => const LocalFinancePlanContext(
          estimatedBudget: '1000000',
          currency: 'USD',
        ),
      );

      await financeApi.createBudgetCategory(
        weddingPlanId: localPlanId,
        name: 'القاعة',
        targetAmount: '250000',
      );
      final summary = await financeApi.getMoneySummary(localPlanId);

      expect(summary.totalBudget, '1000000.00');
      expect(summary.currency, 'USD');
    },
  );

  test('local financial commitments reject impossible balances', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final apiClient = ApiClient(tokenProvider: () async => null);
    final database = await createLocalDatabase(preferences);
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    final financeApi = BudgetExpenseApi(apiClient, offline: offline);
    const planId = 'guest-plan-money-balance-guards';

    final category = await financeApi.createBudgetCategory(
      weddingPlanId: planId,
      name: 'الصالة',
      targetAmount: '1000',
    );

    expect(
      () => financeApi.createFinancialCommitment(
        weddingPlanId: planId,
        budgetCategoryId: category.id,
        title: 'التزام صفر',
        totalAmount: '0',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => financeApi.createFinancialCommitment(
        weddingPlanId: planId,
        budgetCategoryId: category.id,
        title: 'التزام مدفوع أكثر من الإجمالي',
        totalAmount: '100',
        paidAmount: '150',
      ),
      throwsA(isA<ApiException>()),
    );

    final commitment = await financeApi.createFinancialCommitment(
      weddingPlanId: planId,
      budgetCategoryId: category.id,
      title: 'التزام صحيح',
      totalAmount: '100',
      paidAmount: '60',
    );

    expect(
      () => financeApi.createFinancialPaymentRecord(
        commitmentId: commitment.id,
        amount: '50',
      ),
      throwsA(isA<ApiException>()),
    );

    final payment = await financeApi.createFinancialPaymentRecord(
      commitmentId: commitment.id,
      amount: '40',
    );
    expect(payment.amount, '40.00');

    final commitments = await financeApi.getFinancialCommitments(planId);
    expect(commitments.single.paidAmount, '100.00');
    expect(commitments.single.remainingAmount, '0.00');
  });
}
