import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';
import '../models/money_summary.dart';

class BudgetExpenseApi {
  const BudgetExpenseApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    const table = OfflineTables.cachedBudgetCategories;
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(BudgetCategory.fromJson)
          .toList();
    }
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
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalBudgetCategory(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }
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
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(Expense.fromJson)
          .toList();
    }
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
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final expenses = await _offline?.database.readCachedList(
        table: OfflineTables.cachedBudgetItems,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return _summaryFromExpenses(expenses ?? const <Map<String, dynamic>>[]);
    }
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

  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    final key = 'money_summary:$weddingPlanId';
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _localMoneySummary(weddingPlanId);
    }
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$weddingPlanId/money-summary',
      );
      await _offline?.database.setMeta(key, jsonEncode(json));
      return MoneySummary.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached != null) {
        return MoneySummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
      return _localMoneySummary(weddingPlanId);
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
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalExpense(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }
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

  Future<Expense> updateExpense({
    required String id,
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
      'budgetCategoryId':
          budgetCategoryId != null && budgetCategoryId.trim().isNotEmpty
          ? budgetCategoryId.trim()
          : null,
      'expenseDate': expenseDate?.toIso8601String(),
      'note': note != null && note.trim().isNotEmpty ? note.trim() : null,
    };

    if (id.startsWith('local-expense-')) {
      return _updateLocalExpense(
        id: id,
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }

    try {
      final json = await _apiClient.patchJson('/expenses/$id', payload);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBudgetItems,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return Expense.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedBudgetItems,
        id: id,
      );
      if (cached == null) rethrow;

      final localJson = {
        ...cached,
        ...payload,
        'id': id,
        'weddingPlanId': weddingPlanId,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBudgetItems,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'expense',
        operation: 'update',
        endpoint: '/expenses/$id',
        method: 'PATCH',
        payload: payload,
        localEntityId: id,
      );
      await _offline.refreshStatus();
      return Expense.fromJson(localJson);
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _apiClient.deleteJson('/expenses/$id');
      await _markExpenseDeletedLocally(id, dirty: false);
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _markExpenseDeletedLocally(id, dirty: true);
      await _offline.database.enqueueSync(
        entityType: 'expense',
        operation: 'delete',
        endpoint: '/expenses/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
      );
      await _offline.refreshStatus();
    }
  }

  Future<void> _markExpenseDeletedLocally(
    String id, {
    required bool dirty,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetItems,
      id: id,
    );
    if (cached == null) return;
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: cached,
      dirty: dirty,
      deletedLocally: true,
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<MoneySummary> _localMoneySummary(String weddingPlanId) async {
    final categories =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedBudgetCategories,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final expenses =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedBudgetItems,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final debts =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedDebts,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];

    final installments = <Map<String, dynamic>>[];
    for (final debt in debts) {
      final debtId = debt['id']?.toString();
      if (debtId == null || debtId.isEmpty) continue;
      final debtInstallments = await _offline?.database.readCachedList(
        table: OfflineTables.cachedInstallments,
        parentColumn: 'debtId',
        parentId: debtId,
      );
      if (debtInstallments != null) installments.addAll(debtInstallments);
    }

    final totalBudget = categories.fold<num>(
      0,
      (sum, category) => sum + _moneyValue(category['targetAmount']),
    );
    final totalSpent = expenses.fold<num>(0, (sum, expense) {
      if (expense['status']?.toString() != 'PAID') return sum;
      return sum + _moneyValue(expense['amount']);
    });
    final totalDebts = debts.fold<num>(
      0,
      (sum, debt) => sum + _moneyValue(debt['totalAmount']),
    );
    final paidDebts = debts.fold<num>(
      0,
      (sum, debt) => sum + _moneyValue(debt['paidAmount']),
    );
    final debtRemaining = (totalDebts - paidDebts).clamp(0, totalDebts);
    final remainingBudget = totalBudget - totalSpent;
    final categorySummaries = categories.map((category) {
      final id = category['id']?.toString() ?? '';
      final allocated = _moneyValue(category['targetAmount']);
      final categoryExpenses = expenses.where(
        (expense) => expense['budgetCategoryId']?.toString() == id,
      );
      final spent = categoryExpenses.fold<num>(0, (sum, expense) {
        if (expense['status']?.toString() != 'PAID') return sum;
        return sum + _moneyValue(expense['amount']);
      });
      return MoneyCategorySummary(
        categoryId: id,
        name: category['name']?.toString() ?? '',
        allocated: _moneyOrNull(allocated),
        spent: _moneyOrNull(spent),
        remaining: _moneyOrNull(allocated - spent),
        expensesCount: categoryExpenses.length,
        overBudget: allocated > 0 && spent > allocated,
      );
    }).toList();

    final now = DateTime.now();
    final unpaidInstallments =
        installments.where((installment) {
          final status = installment['status']?.toString();
          return status != 'PAID' && status != 'CANCELLED';
        }).toList()..sort((a, b) {
          final aDate = DateTime.tryParse(a['dueDate']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['dueDate']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
    final overdueCount = unpaidInstallments.where((installment) {
      final dueDate = DateTime.tryParse(
        installment['dueDate']?.toString() ?? '',
      );
      return dueDate != null &&
          dueDate.isBefore(DateTime(now.year, now.month, now.day));
    }).length;
    final dueSoonCount = unpaidInstallments.where((installment) {
      final dueDate = DateTime.tryParse(
        installment['dueDate']?.toString() ?? '',
      );
      if (dueDate == null) return false;
      final days = dueDate.difference(now).inDays;
      return days >= 0 && days <= 7;
    }).length;
    final warnings = <MoneyFinancialWarning>[
      if (remainingBudget < 0)
        MoneyFinancialWarning(
          type: 'BUDGET_EXCEEDED',
          severity: 'DANGER',
          message: 'ميزانيتك تجاوزت الحد',
          amount: _moneyOrNull(remainingBudget.abs()),
        ),
      if (categorySummaries.any((category) => category.overBudget == true))
        MoneyFinancialWarning(
          type: 'CATEGORY_EXCEEDED',
          severity: 'WARNING',
          message: 'تصنيف في الميزانية تجاوز المخصص',
          count: categorySummaries
              .where((category) => category.overBudget == true)
              .length,
        ),
      if (overdueCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_OVERDUE',
          severity: 'DANGER',
          message: 'قسط متأخر يحتاج متابعة',
          count: overdueCount,
        ),
      if (dueSoonCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_DUE_SOON',
          severity: 'WARNING',
          message: 'قسط قريب يحتاج متابعة',
          count: dueSoonCount,
        ),
    ];

    final nextInstallment = unpaidInstallments.isEmpty
        ? null
        : MoneyNextInstallment.fromJson(unpaidInstallments.first);

    return MoneySummary(
      weddingPlanId: weddingPlanId,
      totalBudget: _moneyOrNull(totalBudget),
      totalSpent: _moneyOrNull(totalSpent),
      remainingBudget: _moneyOrNull(remainingBudget),
      totalDebts: _moneyOrNull(totalDebts),
      debtRemaining: _moneyOrNull(debtRemaining),
      paidInstallmentsCount: installments
          .where((installment) => installment['status']?.toString() == 'PAID')
          .length,
      remainingInstallmentsCount: unpaidInstallments.length,
      overdueInstallmentsCount: overdueCount,
      dueInstallmentsCount: dueSoonCount,
      nextInstallment: nextInstallment,
      categorySummaries: categorySummaries,
      financialWarnings: warnings,
      categoriesCount: categories.length,
      expensesCount: expenses.length,
      debtsCount: debts.length,
      installmentsCount: installments.length,
    );
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

  num _moneyValue(Object? value) {
    return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  String? _moneyOrNull(num? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  Future<Expense> _createLocalExpense({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localId = 'local-expense-${now.microsecondsSinceEpoch}';
    final localJson = {
      'id': localId,
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Expense.fromJson(localJson);
  }

  Future<BudgetCategory> _createLocalBudgetCategory({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localJson = {
      'id': 'local-budget-category-${now.microsecondsSinceEpoch}',
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return BudgetCategory.fromJson(localJson);
  }

  Future<Expense> _updateLocalExpense({
    required String id,
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetItems,
      id: id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...payload,
      'id': id,
      'weddingPlanId': cached?['weddingPlanId'] ?? weddingPlanId,
      'createdAt': cached?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Expense.fromJson(localJson);
  }

  bool _isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }
}
