import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/widgets/finance_overview/budget_categories_section.dart';
import 'package:aarast_mobile/features/finance/widgets/finance_overview/expense_delete_confirmation_sheet.dart';
import 'package:aarast_mobile/features/finance/widgets/finance_overview/financial_payables_section.dart';
import 'package:aarast_mobile/features/finance/widgets/finance_overview/recent_money_activity_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('payables preview chooses the earliest dated money event', (
    tester,
  ) async {
    String? openedCommitmentId;
    final laterCommitment = _commitment(
      id: 'commitment-later',
      title: 'مستحق بقسط أقرب',
      dueDate: DateTime.utc(2026, 7, 20),
    );
    final earlierCommitment = _commitment(
      id: 'commitment-earlier',
      title: 'مستحق أقرب بدون قسط',
      dueDate: DateTime.utc(2026, 7, 10),
    );

    await tester.pumpWidget(
      _wrap(
        FinancialPayablesSection(
          summary: const MoneySummary(
            weddingPlanId: 'plan-overview',
            currency: 'YER',
          ),
          currencyCode: 'YER',
          commitments: [laterCommitment, earlierCommitment],
          installments: [
            FinancialInstallment(
              id: 'installment-nearest',
              weddingPlanId: 'plan-overview',
              financialCommitmentId: laterCommitment.id,
              budgetCategoryId: 'category-1',
              amount: '200',
              status: 'PENDING',
              dueDate: DateTime.utc(2026, 7, 5),
            ),
          ],
          onOpenPayables: () {},
          onOpenCommitment: (id) => openedCommitmentId = id,
        ),
      ),
    );

    expect(find.text('مستحق بقسط أقرب'), findsOneWidget);
    expect(find.text('مستحق أقرب بدون قسط'), findsNothing);

    await tester.tap(find.text('مستحق بقسط أقرب'));
    expect(openedCommitmentId, laterCommitment.id);
  });

  testWidgets('budget categories show three rows then expand on demand', (
    tester,
  ) async {
    final rows = [
      for (var index = 1; index <= 4; index++)
        MoneyCategorySummary(
          categoryId: 'category-$index',
          name: 'البند $index',
          allocated: '1000',
          spent: '100',
          remaining: '900',
        ),
    ];

    await tester.pumpWidget(
      _wrap(
        BudgetCategoriesSection(
          weddingPlanId: 'plan-overview',
          categoryRows: rows,
          canManageFinancialRecords: true,
          currencyCode: 'YER',
        ),
      ),
    );

    expect(find.text('البند 1'), findsOneWidget);
    expect(find.text('البند 3'), findsOneWidget);
    expect(find.text('البند 4'), findsNothing);

    await tester.tap(find.text('عرض الكل'));
    await tester.pumpAndSettle();

    expect(find.text('البند 4'), findsOneWidget);
    expect(find.text('إخفاء'), findsOneWidget);
  });

  testWidgets('recent activity is date-sorted and keeps permission gates', (
    tester,
  ) async {
    FinancialPaymentRecord? openedPayment;
    final now = DateTime.utc(2026, 7, 11);
    final expense = Expense(
      id: 'expense-1',
      weddingPlanId: 'plan-overview',
      budgetCategoryId: 'category-1',
      title: 'مصروف أقدم',
      amount: '100',
      status: 'PAID',
      expenseDate: now.subtract(const Duration(days: 2)),
      createdAt: now,
      updatedAt: now,
    );
    final payment = FinancialPaymentRecord(
      id: 'payment-1',
      weddingPlanId: 'plan-overview',
      financialCommitmentId: 'commitment-1',
      budgetCategoryId: 'category-1',
      title: 'دفعة أحدث',
      amount: '200',
      paidAt: now,
    );

    await tester.pumpWidget(
      _wrap(
        RecentMoneyActivitySection(
          expenses: [expense],
          payments: [payment],
          budgetCategories: [_category()],
          isBusy: false,
          canManageFinancialRecords: false,
          currencyCode: 'YER',
          onEditExpense: (_) => fail('view-only must not edit'),
          onOpenPayment: (value) => openedPayment = value,
          onDeleteExpense: (_) => fail('view-only must not delete'),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('دفعة أحدث')).dy,
      lessThan(tester.getTopLeft(find.text('مصروف أقدم')).dy),
    );
    expect(find.byTooltip('خيارات المصروف'), findsNothing);

    await tester.tap(find.text('دفعة أحدث'));
    expect(openedPayment?.id, payment.id);
  });

  testWidgets('expense delete sheet preserves cancel and confirm results', (
    tester,
  ) async {
    Future<bool?>? result;
    final expense = Expense(
      id: 'expense-delete',
      weddingPlanId: 'plan-overview',
      title: 'مصروف القاعة',
      amount: '300',
      status: 'PAID',
      createdAt: DateTime.utc(2026, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 11),
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = showExpenseDeleteConfirmation(
                context: context,
                expense: expense,
              );
            },
            child: const Text('فتح التأكيد'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح التأكيد'));
    await tester.pumpAndSettle();
    expect(find.textContaining(expense.title), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    await tester.tap(find.text('فتح التأكيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

FinancialCommitment _commitment({
  required String id,
  required String title,
  required DateTime dueDate,
}) {
  return FinancialCommitment(
    id: id,
    weddingPlanId: 'plan-overview',
    budgetCategoryId: 'category-1',
    title: title,
    totalAmount: '1000',
    paidAmount: '0',
    remainingAmount: '1000',
    sourceType: 'MANUAL_COMMITMENT',
    status: 'OPEN',
    dueDate: dueDate,
  );
}

BudgetCategory _category() {
  final now = DateTime.utc(2026, 7, 11);
  return BudgetCategory(
    id: 'category-1',
    weddingPlanId: 'plan-overview',
    name: 'الصالة',
    targetAmount: '1000',
    createdAt: now,
    updatedAt: now,
  );
}
