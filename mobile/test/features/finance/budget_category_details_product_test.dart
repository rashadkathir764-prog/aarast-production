import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('category details is a complete finance destination at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.reset);

    final apiClient = ApiClient(tokenProvider: () async => null);
    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_CategoryFinanceApi(apiClient)),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BudgetCategoryDetailsScreen(
              weddingPlanId: 'plan-1',
              budgetCategoryId: 'category-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الصالة'), findsWidgets);
    expect(find.text('المستحقات المرتبطة'), findsOneWidget);
    expect(find.text('باقي الصالة'), findsOneWidget);
    expect(find.text('حركات البند'), findsOneWidget);
    expect(find.text('دفعة الصالة'), findsWidgets);
    expect(find.text('إدارة البند'), findsOneWidget);
    expect(find.text('إضافة مستحق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CategoryFinanceApi extends BudgetExpenseApi {
  _CategoryFinanceApi(super.apiClient);

  static final _now = DateTime.utc(2026, 7, 10);

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    return [
      BudgetCategory(
        id: 'category-1',
        weddingPlanId: weddingPlanId,
        name: 'الصالة',
        targetAmount: '1000000',
        createdAt: _now,
        updatedAt: _now,
      ),
    ];
  }

  @override
  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    return [
      Expense(
        id: 'expense-1',
        weddingPlanId: weddingPlanId,
        budgetCategoryId: 'category-1',
        title: 'دفعة الصالة',
        amount: '100000',
        status: 'PAID',
        expenseDate: _now,
        createdAt: _now,
        updatedAt: _now,
      ),
    ];
  }

  @override
  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    return const ExpenseSummary(
      totalPaid: '100000',
      totalPlanned: '0',
      totalCancelled: '0',
      countPaid: 1,
      countPlanned: 0,
      countCancelled: 0,
    );
  }

  @override
  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    return MoneySummary(
      weddingPlanId: weddingPlanId,
      totalBudget: '1000000',
      totalSpent: '100000',
      categorySummaries: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'الصالة',
          allocated: '1000000',
          spent: '100000',
          remaining: '900000',
          expensesCount: 1,
          commitmentsCount: 1,
          overBudget: false,
        ),
      ],
    );
  }

  @override
  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    return [
      FinancialCommitment(
        id: 'commitment-1',
        weddingPlanId: weddingPlanId,
        budgetCategoryId: 'category-1',
        title: 'باقي الصالة',
        totalAmount: '500000',
        paidAmount: '100000',
        remainingAmount: '400000',
        sourceType: 'PROVIDER_SERVICE',
        status: 'PARTIALLY_PAID',
        dueDate: _now.add(const Duration(days: 7)),
      ),
    ];
  }

  @override
  Future<List<FinancialPaymentRecord>> getFinancialPaymentRecords(
    String weddingPlanId,
  ) async {
    return [
      FinancialPaymentRecord(
        id: 'payment-1',
        weddingPlanId: weddingPlanId,
        financialCommitmentId: 'commitment-1',
        budgetCategoryId: 'category-1',
        title: 'دفعة الصالة',
        amount: '100000',
        paidAt: _now,
      ),
    ];
  }

  @override
  Future<List<FinancialInstallment>> getDueFinancialInstallments(
    String weddingPlanId,
  ) async {
    return const [];
  }
}
