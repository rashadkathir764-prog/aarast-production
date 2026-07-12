import '../../models/budget_category.dart';
import '../../models/expense.dart';
import '../../models/money_summary.dart';

List<MoneyCategorySummary> buildFallbackMoneyCategorySummaries({
  required List<BudgetCategory> categories,
  required List<Expense> expenses,
}) {
  return _buildCategoryRows(categories, expenses)
      .map(
        (row) => MoneyCategorySummary(
          categoryId: row.id,
          name: row.name,
          allocated: row.target.toString(),
          spent: row.spent.toString(),
          remaining: (row.target - row.spent).toString(),
          expensesCount: row.expensesCount,
          overBudget: row.target > 0 && row.spent > row.target,
        ),
      )
      .toList();
}

class _CategorySpendRow {
  const _CategorySpendRow({
    required this.id,
    required this.name,
    required this.spent,
    required this.target,
    required this.progress,
    required this.expensesCount,
  });

  final String id;
  final String name;
  final num spent;
  final num target;
  final double progress;
  final int expensesCount;
}

List<_CategorySpendRow> _buildCategoryRows(
  List<BudgetCategory> categories,
  List<Expense> expenses,
) {
  final activeExpenses = expenses.where((expense) => expense.status == 'PAID');
  final totalSpent = activeExpenses.fold<num>(
    0,
    (sum, expense) => sum + _moneyValue(expense.amount),
  );

  return categories.map((category) {
    final spent = activeExpenses
        .where((expense) => expense.budgetCategoryId == category.id)
        .fold<num>(0, (sum, expense) => sum + _moneyValue(expense.amount));
    final target = _moneyValue(category.targetAmount ?? '0');
    final denominator = target > 0 ? target : totalSpent;
    final progress = denominator <= 0 ? 0.0 : spent / denominator;
    final categoryExpenses = expenses.where(
      (expense) => expense.budgetCategoryId == category.id,
    );
    return _CategorySpendRow(
      id: category.id,
      name: category.name,
      spent: spent,
      target: target,
      progress: progress.toDouble(),
      expensesCount: categoryExpenses.length,
    );
  }).toList();
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
