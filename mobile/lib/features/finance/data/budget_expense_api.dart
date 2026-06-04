import '../../../core/network/api_client.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';

class BudgetExpenseApi {
  const BudgetExpenseApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/budget-categories',
    );
    return list
        .whereType<Map>()
        .map((item) => BudgetCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BudgetCategory> createBudgetCategory({
    required String weddingPlanId,
    required String name,
    String? targetAmount,
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/budget-categories', {
          'name': name.trim(),
          if (targetAmount != null && targetAmount.trim().isNotEmpty)
            'targetAmount': targetAmount.trim(),
        });
    return BudgetCategory.fromJson(json);
  }

  Future<BudgetCategory> updateBudgetCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson('/budget-categories/$id', data);
    return BudgetCategory.fromJson(json);
  }

  Future<void> deleteBudgetCategory(String id) async {
    await _apiClient.deleteJson('/budget-categories/$id');
  }

  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/expenses',
    );
    return list
        .whereType<Map>()
        .map((item) => Expense.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    final json = await _apiClient.getJson(
      '/wedding-plans/$weddingPlanId/expenses/summary',
    );
    return ExpenseSummary.fromJson(json);
  }

  Future<Expense> createExpense({
    required String weddingPlanId,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PLANNED',
    DateTime? expenseDate,
    String? note,
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/expenses', {
          'title': title.trim(),
          'amount': amount.trim(),
          'status': status,
          if (budgetCategoryId != null && budgetCategoryId.trim().isNotEmpty)
            'budgetCategoryId': budgetCategoryId.trim(),
          if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
    return Expense.fromJson(json);
  }

  Future<Expense> updateExpense(String id, Map<String, dynamic> data) async {
    final json = await _apiClient.patchJson('/expenses/$id', data);
    return Expense.fromJson(json);
  }

  Future<void> deleteExpense(String id) async {
    await _apiClient.deleteJson('/expenses/$id');
  }
}
