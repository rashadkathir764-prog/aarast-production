import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/widgets/finance_overview/finance_overview_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback category summaries preserve paid-only spend semantics', () {
    final rows = buildFallbackMoneyCategorySummaries(
      categories: [
        _category(id: 'hall', name: 'الصالة', target: '1000'),
        _category(id: 'photo', name: 'التصوير', target: '100'),
      ],
      expenses: [
        _expense(id: 'paid-hall', categoryId: 'hall', amount: '250'),
        _expense(
          id: 'planned-hall',
          categoryId: 'hall',
          amount: '400',
          status: 'PLANNED',
        ),
        _expense(id: 'paid-photo', categoryId: 'photo', amount: '150'),
      ],
    );

    expect(rows, hasLength(2));
    expect(rows[0].categoryId, 'hall');
    expect(rows[0].allocated, '1000');
    expect(rows[0].spent, '250');
    expect(rows[0].remaining, '750');
    expect(rows[0].expensesCount, 2);
    expect(rows[0].overBudget, isFalse);

    expect(rows[1].categoryId, 'photo');
    expect(rows[1].allocated, '100');
    expect(rows[1].spent, '150');
    expect(rows[1].remaining, '-50');
    expect(rows[1].expensesCount, 1);
    expect(rows[1].overBudget, isTrue);
  });
}

BudgetCategory _category({
  required String id,
  required String name,
  required String target,
}) {
  final now = DateTime.utc(2026, 7, 11);
  return BudgetCategory(
    id: id,
    weddingPlanId: 'plan-overview',
    name: name,
    targetAmount: target,
    createdAt: now,
    updatedAt: now,
  );
}

Expense _expense({
  required String id,
  required String categoryId,
  required String amount,
  String status = 'PAID',
}) {
  final now = DateTime.utc(2026, 7, 11);
  return Expense(
    id: id,
    weddingPlanId: 'plan-overview',
    budgetCategoryId: categoryId,
    title: id,
    amount: amount,
    status: status,
    expenseDate: now,
    createdAt: now,
    updatedAt: now,
  );
}
