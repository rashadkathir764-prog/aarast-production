import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/budget_setup_screen.dart';
import 'package:aarast_mobile/features/finance/screens/create_budget_category_screen.dart';
import 'package:aarast_mobile/features/finance/screens/create_financial_commitment_screen.dart';
import 'package:aarast_mobile/features/finance/screens/expenses_screen.dart';
import 'package:aarast_mobile/features/finance/screens/financial_commitment_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/financial_payables_screen.dart';
import 'package:aarast_mobile/features/finance/screens/financial_payment_record_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/record_payment_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase A money screens premium contract', () {
    test('A1 plan management remains premium and source-truth safe', () {
      final source = _readSource(
        'lib/features/wedding_plans/screens/plan_management_screen.dart',
      );
      final viewSource = _readSource(
        'lib/features/wedding_plans/widgets/plan_management_view.dart',
      );

      expect(source, contains('AarastScreenFrame'));
      expect(source, contains('PlanManagementView'));
      expect(viewSource, contains('إدارة الخطة'));
      expect(viewSource, contains('حالة اكتمال البيانات'));
      expect(source, isNot(contains('_PremiumPlanSummaryHero')));
      expect(source, isNot(contains('_PlanSectionsCard')));
      expect(source, contains('LucideIcons.'));
      expect(_materialIconLines(source), isEmpty);
      expect(_materialIconLines(viewSource), isEmpty);
      expect(source, isNot(contains('AarastComingSoonScreen')));
      expect(source, isNot(contains('Mock progress data')));
      expect(source, isNot(contains("?? 'غير متاح'")));
    });

    test('A6-A9 use Lucide icons and dynamic Arabic currency labels', () {
      for (final path in _phaseAFinanceScreenPaths) {
        final source = _readSource(path);
        expect(source, contains('LucideIcons.'), reason: path);
        expect(source, contains('currencyLabelAr'), reason: path);
        expect(_materialIconLines(source), isEmpty, reason: path);
        expect(source, isNot(contains("suffixText: 'ر.ي'")), reason: path);
        expect(source, isNot(contains("suffixText: 'YER'")), reason: path);
        expect(source, isNot(contains("' ر.ي'")), reason: path);
      }
    });

    test('create expense copy stays outside deposit and booking scope', () {
      final source = _readSource(
        'lib/features/finance/screens/create_expense_screen.dart',
      );

      expect(source, isNot(contains('عربون')));
      expect(source, isNot(contains('الحجز')));
      expect(source, isNot(contains('تاريخ الاتفاق')));
      expect(source, isNot(contains('موعد دفع الباقي')));
      expect(source, contains('تسجيل مصروف مدفوع'));
      expect(source, contains('المبلغ المدفوع'));
      expect(source, contains('تصنيف مالي'));
    });
  });

  group('Phase A money screens currency rendering', () {
    testWidgets('budget setup shows selected plan currency', (tester) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(const BudgetSetupScreen(weddingPlanId: _planId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ر.س'), findsWidgets);
      expect(find.text('ر.ي'), findsNothing);
    });

    testWidgets('create budget category shows selected plan currency', (
      tester,
    ) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(const CreateBudgetCategoryScreen(weddingPlanId: _planId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ر.س'), findsWidgets);
      expect(find.text('ر.ي'), findsNothing);
    });

    testWidgets('expenses list shows selected plan currency', (tester) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(const ExpensesScreen(weddingPlanId: _planId)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ر.س'), findsWidgets);
      expect(find.textContaining('ر.ي'), findsNothing);
    });

    testWidgets('budget category details shows selected plan currency', (
      tester,
    ) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(
          const BudgetCategoryDetailsScreen(
            weddingPlanId: _planId,
            budgetCategoryId: _categoryId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ر.س'), findsWidgets);
      expect(find.textContaining('ر.ي'), findsNothing);
    });

    testWidgets('financial payables shows selected plan currency', (
      tester,
    ) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(const FinancialPayablesScreen(weddingPlanId: _planId)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ر.س'), findsWidgets);
      expect(find.textContaining('ر.ي'), findsNothing);
    });
  });

  group('Current finance surfaces at narrow RTL width', () {
    final screens = <Widget>[
      const CreateFinancialCommitmentScreen(weddingPlanId: _planId),
      const FinancialPayablesScreen(weddingPlanId: _planId),
      const FinancialCommitmentDetailsScreen(
        weddingPlanId: _planId,
        commitmentId: 'missing-commitment',
      ),
      const FinancialPaymentRecordDetailsScreen(
        weddingPlanId: _planId,
        paymentRecordId: 'missing-payment',
      ),
      const RecordPaymentScreen(weddingPlanId: _planId),
    ];

    for (final screen in screens) {
      testWidgets('${screen.runtimeType} is overflow-free at 320px RTL', (
        tester,
      ) async {
        _setPhoneView(tester);

        await tester.pumpWidget(_wrap(screen));
        await tester.pumpAndSettle();

        expect(find.byWidget(screen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

const _planId = 'plan-sar';
const _categoryId = 'category-hall';

const _phaseAFinanceScreenPaths = [
  'lib/features/finance/screens/budget_category_details_screen.dart',
  'lib/features/finance/screens/expenses_screen.dart',
  'lib/features/finance/screens/budget_setup_screen.dart',
  'lib/features/finance/screens/create_budget_category_screen.dart',
];

Widget _wrap(Widget child) {
  final apiClient = ApiClient(tokenProvider: () async => null);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WeddingPlansProvider>.value(
        value: _FakeWeddingPlansProvider(apiClient, [_plan()]),
      ),
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_FakeBudgetExpenseApi(apiClient)),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

WeddingPlan _plan() {
  final now = DateTime.utc(2026, 7, 5);
  return WeddingPlan(
    id: _planId,
    ownerUserId: 'user-1',
    title: 'خطة الرياض',
    currency: 'SAR',
    status: 'PLANNING',
    createdAt: now,
    updatedAt: now,
  );
}

BudgetCategory _category() {
  final now = DateTime.utc(2026, 7, 5);
  return BudgetCategory(
    id: _categoryId,
    weddingPlanId: _planId,
    name: 'الصالة',
    targetAmount: '10000',
    createdAt: now,
    updatedAt: now,
  );
}

Expense _expense() {
  final now = DateTime.utc(2026, 7, 5);
  return Expense(
    id: 'expense-1',
    weddingPlanId: _planId,
    budgetCategoryId: _categoryId,
    title: 'دفعة الصالة',
    amount: '1500',
    status: 'PAID',
    expenseDate: DateTime.utc(2026, 7, 6),
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeBudgetExpenseApi extends BudgetExpenseApi {
  _FakeBudgetExpenseApi(super.apiClient);

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    return [_category()];
  }

  @override
  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    return [_expense()];
  }

  @override
  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    return const ExpenseSummary(
      totalPaid: '1500',
      totalPlanned: '0',
      totalCancelled: '0',
      countPaid: 1,
      countPlanned: 0,
      countCancelled: 0,
    );
  }

  @override
  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    return const MoneySummary(
      weddingPlanId: _planId,
      currency: 'SAR',
      totalBudget: '10000',
      totalSpent: '1500',
      remainingBudget: '8500',
      categorySummaries: [
        MoneyCategorySummary(
          categoryId: _categoryId,
          name: 'الصالة',
          allocated: '10000',
          spent: '1500',
          remaining: '8500',
          expensesCount: 1,
          overBudget: false,
        ),
      ],
    );
  }

  @override
  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    return const [];
  }

  @override
  Future<List<FinancialPaymentRecord>> getFinancialPaymentRecords(
    String weddingPlanId,
  ) async {
    return const [];
  }

  @override
  Future<List<FinancialInstallment>> getDueFinancialInstallments(
    String weddingPlanId,
  ) async {
    return const [];
  }
}

class _FakeWeddingPlansProvider extends WeddingPlansProvider {
  _FakeWeddingPlansProvider(ApiClient apiClient, this._fakePlans)
    : super(WeddingPlansApi(apiClient));

  final List<WeddingPlan> _fakePlans;

  @override
  List<WeddingPlan> get plans => _fakePlans;

  @override
  WeddingPlan? get selectedPlan => _fakePlans.isEmpty ? null : _fakePlans.first;
}

List<String> _materialIconLines(String source) {
  return source
      .split('\n')
      .where(
        (line) => line.contains('Icons.') && !line.contains('LucideIcons.'),
      )
      .toList();
}

String _readSource(String relativePath) {
  return File('${_findMobileRoot()}$relativePath').readAsStringSync();
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

void _setPhoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
  addTearDown(tester.view.reset);
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
