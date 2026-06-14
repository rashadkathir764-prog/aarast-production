import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';

class BudgetExpenseApi {
  const BudgetExpenseApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    const table = OfflineTables.cachedBudgetCategories;
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/budget-categories',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(BudgetCategory.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) return cached.map(BudgetCategory.fromJson).toList();
      rethrow;
    }
  }

  Future<BudgetCategory> createBudgetCategory({
    required String weddingPlanId,
    required String name,
    String? targetAmount,
  }) async {
    final payload = {
      'name': name.trim(),
      if (targetAmount != null && targetAmount.trim().isNotEmpty)
        'targetAmount': targetAmount.trim(),
    };
    try {
      final json = await _apiClient.postJson(
        '/wedding-plans/$weddingPlanId/budget-categories',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return BudgetCategory.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-budget-category-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        ...payload,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'budget_category',
        operation: 'create',
        endpoint: '/wedding-plans/$weddingPlanId/budget-categories',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return BudgetCategory.fromJson(localJson);
    }
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
    const table = OfflineTables.cachedBudgetItems;
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/expenses',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(Expense.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) return cached.map(Expense.fromJson).toList();
      rethrow;
    }
  }

  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    final key = 'expense_summary:$weddingPlanId';
    try {
      final json = await _apiClient.getJson(
        '/wedding-plans/$weddingPlanId/expenses/summary',
      );
      await _offline?.database.setMeta(key, jsonEncode(json));
      return ExpenseSummary.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached != null) {
        return ExpenseSummary.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      final expenses = await _offline.database.readCachedList(
        table: OfflineTables.cachedBudgetItems,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (expenses.isNotEmpty) return _summaryFromExpenses(expenses);
      rethrow;
    }
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
    final payload = {
      'title': title.trim(),
      'amount': amount.trim(),
      'status': status,
      if (budgetCategoryId != null && budgetCategoryId.trim().isNotEmpty)
        'budgetCategoryId': budgetCategoryId.trim(),
      if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    try {
      final json = await _apiClient.postJson(
        '/wedding-plans/$weddingPlanId/expenses',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBudgetItems,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return Expense.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-expense-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        ...payload,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBudgetItems,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'expense',
        operation: 'create',
        endpoint: '/wedding-plans/$weddingPlanId/expenses',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return Expense.fromJson(localJson);
    }
  }

  Future<Expense> updateExpense(String id, Map<String, dynamic> data) async {
    final json = await _apiClient.patchJson('/expenses/$id', data);
    return Expense.fromJson(json);
  }

  Future<void> deleteExpense(String id) async {
    await _apiClient.deleteJson('/expenses/$id');
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    return cached.isEmpty ? null : cached;
  }

  ExpenseSummary _summaryFromExpenses(List<Map<String, dynamic>> expenses) {
    num totalPaid = 0;
    num totalPlanned = 0;
    num totalCancelled = 0;
    var countPaid = 0;
    var countPlanned = 0;
    var countCancelled = 0;
    for (final expense in expenses) {
      final amount = num.tryParse(expense['amount']?.toString() ?? '') ?? 0;
      switch (expense['status']?.toString()) {
        case 'PAID':
          totalPaid += amount;
          countPaid++;
        case 'CANCELLED':
          totalCancelled += amount;
          countCancelled++;
        default:
          totalPlanned += amount;
          countPlanned++;
      }
    }
    return ExpenseSummary(
      totalPaid: totalPaid.toStringAsFixed(2),
      totalPlanned: totalPlanned.toStringAsFixed(2),
      totalCancelled: totalCancelled.toStringAsFixed(2),
      countPaid: countPaid,
      countPlanned: countPlanned,
      countCancelled: countCancelled,
    );
  }
}
