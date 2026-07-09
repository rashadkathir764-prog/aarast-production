import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';
import '../models/financial_commitment.dart';
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

  Future<BudgetCategory> updateBudgetCategory({
    required BudgetCategory category,
    required String name,
    String? targetAmount,
  }) async {
    final data = {
      'name': name.trim(),
      'targetAmount': targetAmount != null && targetAmount.trim().isNotEmpty
          ? targetAmount.trim()
          : null,
    };
    if (category.id.startsWith('local-budget-category-') ||
        _isLocalGuestPlanId(category.weddingPlanId)) {
      return _updateLocalBudgetCategory(category: category, payload: data);
    }
    try {
      final json = await _apiClient.patchJson(
        '/budget-categories/${category.id}',
        data,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: json,
      );
      return BudgetCategory.fromJson(json);
    } on Object catch (error) {
      // Same offline contract as create: a network failure queues the
      // write instead of surfacing a hard error.
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localJson = {
        'id': category.id,
        'weddingPlanId': category.weddingPlanId,
        ...data,
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'budget_category',
        operation: 'update',
        endpoint: '/budget-categories/${category.id}',
        method: 'PATCH',
        payload: data,
        localEntityId: category.id,
      );
      await _offline.refreshStatus();
      return BudgetCategory.fromJson(localJson);
    }
  }

  Future<void> deleteBudgetCategory(String id) async {
    try {
      await _apiClient.deleteJson('/budget-categories/$id');
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: {'id': id},
        dirty: true,
        deletedLocally: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'budget_category',
        operation: 'delete',
        endpoint: '/budget-categories/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
      );
      await _offline.refreshStatus();
    }
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

  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    const table = OfflineTables.cachedFinancialCommitments;
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(FinancialCommitment.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$weddingPlanId/financial-commitments',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(FinancialCommitment.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) {
        return cached.map(FinancialCommitment.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<FinancialPaymentRecord>> getFinancialPaymentRecords(
    String weddingPlanId,
  ) async {
    const table = OfflineTables.cachedFinancialPaymentRecords;
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(FinancialPaymentRecord.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$weddingPlanId/financial-payment-records',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(FinancialPaymentRecord.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) {
        return cached.map(FinancialPaymentRecord.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<FinancialInstallment>> getDueFinancialInstallments(
    String weddingPlanId,
  ) async {
    const table = OfflineTables.cachedFinancialInstallments;
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .where(_isDueFinancialInstallment)
          .map(FinancialInstallment.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$weddingPlanId/financial-installments/due',
      );
      for (final item in items) {
        await _offline?.database.saveCachedItem(table: table, json: item);
      }
      return items.map(FinancialInstallment.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) {
        return cached
            .where(_isDueFinancialInstallment)
            .map(FinancialInstallment.fromJson)
            .toList();
      }
      rethrow;
    }
  }

  Future<FinancialCommitment> createFinancialCommitment({
    required String weddingPlanId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String sourceType = 'MANUAL_COMMITMENT',
    String? providerId,
    String? planProviderLinkId,
    String? quoteRequestId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? paidAmount,
    DateTime? dueDate,
    DateTime? agreementDate,
    String? note,
  }) async {
    _assertFinancialCommitmentAmounts(
      totalAmount: totalAmount,
      paidAmount: paidAmount,
    );
    final payload = {
      'budgetCategoryId': budgetCategoryId.trim(),
      'sourceType': sourceType,
      'title': title.trim(),
      'totalAmount': totalAmount.trim(),
      if (providerId != null && providerId.trim().isNotEmpty)
        'providerId': providerId.trim(),
      if (planProviderLinkId != null && planProviderLinkId.trim().isNotEmpty)
        'planProviderLinkId': planProviderLinkId.trim(),
      if (quoteRequestId != null && quoteRequestId.trim().isNotEmpty)
        'quoteRequestId': quoteRequestId.trim(),
      if (quoteOfferId != null && quoteOfferId.trim().isNotEmpty)
        'quoteOfferId': quoteOfferId.trim(),
      if (partyName != null && partyName.trim().isNotEmpty)
        'partyName': partyName.trim(),
      if (partyPhone != null && partyPhone.trim().isNotEmpty)
        'partyPhone': partyPhone.trim(),
      if (paidAmount != null && paidAmount.trim().isNotEmpty)
        'paidAmount': paidAmount.trim(),
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (agreementDate != null)
        'agreementDate': agreementDate.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalFinancialCommitment(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.postJson(
        '/api/v1/wedding-plans/$weddingPlanId/financial-commitments',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return FinancialCommitment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final local = await _createLocalFinancialCommitment(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
      await _offline.database.enqueueSync(
        entityType: 'financial_commitment',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/$weddingPlanId/financial-commitments',
        method: 'POST',
        payload: payload,
        localEntityId: local.id,
      );
      await _offline.refreshStatus();
      return local;
    }
  }

  Future<FinancialPaymentRecord> createFinancialPaymentRecord({
    required String commitmentId,
    required String amount,
    String? title,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    _assertPositiveMoney(amount, 'amount');
    final payload = {
      'amount': amount.trim(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (method != null && method.trim().isNotEmpty) 'method': method.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (commitmentId.startsWith('local-financial-commitment-')) {
      return _createLocalFinancialPaymentRecord(
        commitmentId: commitmentId,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.postJson(
        '/api/v1/financial-commitments/$commitmentId/payment-records',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialPaymentRecords,
        json: json,
      );
      return FinancialPaymentRecord.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final local = await _createLocalFinancialPaymentRecord(
        commitmentId: commitmentId,
        payload: payload,
      );
      await _offline.database.enqueueSync(
        entityType: 'financial_payment_record',
        operation: 'create',
        endpoint: '/api/v1/financial-commitments/$commitmentId/payment-records',
        method: 'POST',
        payload: payload,
        localEntityId: local.id,
      );
      await _offline.refreshStatus();
      return local;
    }
  }

  Future<FinancialInstallment> createFinancialInstallment({
    required String commitmentId,
    required String amount,
    DateTime? dueDate,
    DateTime? paidAt,
    String status = 'PENDING',
    String? note,
  }) async {
    final payload = {
      'amount': amount.trim(),
      'status': status,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (commitmentId.startsWith('local-financial-commitment-')) {
      return _createLocalFinancialInstallment(
        commitmentId: commitmentId,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.postJson(
        '/api/v1/financial-commitments/$commitmentId/installments',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialInstallments,
        json: json,
      );
      return FinancialInstallment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final local = await _createLocalFinancialInstallment(
        commitmentId: commitmentId,
        payload: payload,
      );
      await _offline.database.enqueueSync(
        entityType: 'financial_installment',
        operation: 'create',
        endpoint: '/api/v1/financial-commitments/$commitmentId/installments',
        method: 'POST',
        payload: payload,
        localEntityId: local.id,
      );
      await _offline.refreshStatus();
      return local;
    }
  }

  Future<Expense> createExpense({
    required String weddingPlanId,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PAID',
    DateTime? expenseDate,
    String? note,
  }) async {
    final categoryId = _requiredPaidExpenseCategoryId(budgetCategoryId);
    _assertPaidExpense(status: status, amount: amount);
    final payload = {
      'title': title.trim(),
      'amount': amount.trim(),
      'status': status,
      'budgetCategoryId': categoryId,
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
    String status = 'PAID',
    DateTime? expenseDate,
    String? note,
  }) async {
    final categoryId = _requiredPaidExpenseCategoryId(budgetCategoryId);
    _assertPaidExpense(status: status, amount: amount);
    final payload = {
      'title': title.trim(),
      'amount': amount.trim(),
      'status': status,
      'budgetCategoryId': categoryId,
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

  String _requiredPaidExpenseCategoryId(String? budgetCategoryId) {
    final categoryId = budgetCategoryId?.trim();
    if (categoryId == null || categoryId.isEmpty) {
      throw ArgumentError('budgetCategoryId is required for paid expenses');
    }
    return categoryId;
  }

  void _assertPaidExpense({required String status, required String amount}) {
    if (status != 'PAID') {
      throw ArgumentError(
        'Expenses record actual paid money only; use financial commitments for planned or remaining amounts',
      );
    }
    final parsed = num.tryParse(amount.replaceAll(',', '').trim());
    if (parsed == null || parsed <= 0) {
      throw ArgumentError('amount must be greater than zero');
    }
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
    final commitments =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedFinancialCommitments,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final financialInstallments =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedFinancialInstallments,
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
    final activeCommitments = commitments
        .where((commitment) => commitment['status']?.toString() != 'CANCELLED')
        .toList();
    final commitmentTotal = activeCommitments.fold<num>(
      0,
      (sum, commitment) => sum + _moneyValue(commitment['totalAmount']),
    );
    final commitmentPaid = activeCommitments.fold<num>(
      0,
      (sum, commitment) => sum + _moneyValue(commitment['paidAmount']),
    );
    final commitmentRemaining = (commitmentTotal - commitmentPaid).clamp(
      0,
      commitmentTotal,
    );
    final remainingBudget = totalBudget - totalSpent;
    final confirmedCostTotal = commitmentTotal + totalDebts;
    final paidTotal = commitmentPaid + paidDebts + totalSpent;
    final outstandingTotal = commitmentRemaining + debtRemaining;
    final deficitOrSurplus = totalBudget - confirmedCostTotal;
    final categorySummaries = categories.map((category) {
      final id = category['id']?.toString() ?? '';
      final allocated = _moneyValue(category['targetAmount']);
      final categoryExpenses = expenses.where(
        (expense) => expense['budgetCategoryId']?.toString() == id,
      );
      final categoryCommitments = activeCommitments.where(
        (commitment) => commitment['budgetCategoryId']?.toString() == id,
      );
      final spent = categoryExpenses.fold<num>(0, (sum, expense) {
        if (expense['status']?.toString() != 'PAID') return sum;
        return sum + _moneyValue(expense['amount']);
      });
      final confirmedCost = categoryCommitments.fold<num>(
        0,
        (sum, commitment) => sum + _moneyValue(commitment['totalAmount']),
      );
      final commitmentPaidForCategory = categoryCommitments.fold<num>(
        0,
        (sum, commitment) => sum + _moneyValue(commitment['paidAmount']),
      );
      final categoryInstallments = financialInstallments.where(
        (installment) => installment['budgetCategoryId']?.toString() == id,
      );
      final paid = spent + commitmentPaidForCategory;
      final outstanding = (confirmedCost - commitmentPaidForCategory).clamp(
        0,
        confirmedCost,
      );
      final budgetRemaining = allocated - confirmedCost;
      return MoneyCategorySummary(
        categoryId: id,
        name: category['name']?.toString() ?? '',
        allocated: _moneyOrNull(allocated),
        spent: _moneyOrNull(spent),
        confirmedCost: _moneyOrNull(confirmedCost),
        paid: _moneyOrNull(paid),
        outstanding: _moneyOrNull(outstanding),
        budgetRemaining: _moneyOrNull(budgetRemaining),
        remaining: _moneyOrNull(allocated - spent),
        expensesCount: categoryExpenses.length,
        commitmentsCount: categoryCommitments.length,
        installmentsCount: categoryInstallments.length,
        overBudget: allocated > 0 && confirmedCost > allocated,
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
    final unpaidFinancialInstallments =
        financialInstallments.where((installment) {
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
    final financialOverdueCount = unpaidFinancialInstallments.where((
      installment,
    ) {
      final dueDate = DateTime.tryParse(
        installment['dueDate']?.toString() ?? '',
      );
      return dueDate != null &&
          dueDate.isBefore(DateTime(now.year, now.month, now.day));
    }).length;
    final financialDueSoonCount = unpaidFinancialInstallments.where((
      installment,
    ) {
      final dueDate = DateTime.tryParse(
        installment['dueDate']?.toString() ?? '',
      );
      if (dueDate == null) return false;
      final days = dueDate.difference(now).inDays;
      return days >= 0 && days <= 7;
    }).length;
    final warnings = <MoneyFinancialWarning>[
      if (deficitOrSurplus < 0)
        MoneyFinancialWarning(
          type: 'BUDGET_EXCEEDED',
          severity: 'DANGER',
          message: 'ميزانيتك تجاوزت الحد',
          amount: _moneyOrNull(deficitOrSurplus.abs()),
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
      if (overdueCount + financialOverdueCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_OVERDUE',
          severity: 'DANGER',
          message: 'قسط متأخر يحتاج متابعة',
          count: overdueCount + financialOverdueCount,
        ),
      if (dueSoonCount + financialDueSoonCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_DUE_SOON',
          severity: 'WARNING',
          message: 'قسط قريب يحتاج متابعة',
          count: dueSoonCount + financialDueSoonCount,
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
      confirmedCostTotal: _moneyOrNull(confirmedCostTotal),
      paidTotal: _moneyOrNull(paidTotal),
      outstandingTotal: _moneyOrNull(outstandingTotal),
      commitmentTotal: _moneyOrNull(commitmentTotal),
      commitmentPaidTotal: _moneyOrNull(commitmentPaid),
      commitmentRemainingTotal: _moneyOrNull(commitmentRemaining),
      deficitOrSurplus: _moneyOrNull(deficitOrSurplus),
      totalDebts: _moneyOrNull(totalDebts),
      debtRemaining: _moneyOrNull(debtRemaining),
      paidInstallmentsCount: installments
          .where((installment) => installment['status']?.toString() == 'PAID')
          .length,
      remainingInstallmentsCount: unpaidInstallments.length,
      overdueInstallmentsCount: overdueCount,
      dueInstallmentsCount: dueSoonCount,
      financialInstallmentsCount: financialInstallments.length,
      financialDueInstallmentsCount: financialDueSoonCount,
      financialOverdueInstallmentsCount: financialOverdueCount,
      financialRemainingInstallmentsCount: unpaidFinancialInstallments.length,
      nextInstallment: nextInstallment,
      nextFinancialInstallment: unpaidFinancialInstallments.isEmpty
          ? null
          : MoneyNextInstallment.fromJson(unpaidFinancialInstallments.first),
      categorySummaries: categorySummaries,
      financialWarnings: warnings,
      categoriesCount: categories.length,
      expensesCount: expenses.length,
      debtsCount: debts.length,
      commitmentsCount: activeCommitments.length,
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

  num _assertPositiveMoney(Object? value, String field) {
    final parsed = num.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    );
    if (parsed == null || parsed <= 0) {
      throw ApiException(
        field == 'totalAmount'
            ? 'التكلفة المتفق عليها يجب أن تكون أكبر من صفر.'
            : 'المبلغ يجب أن يكون أكبر من صفر.',
      );
    }
    return parsed;
  }

  num _assertOptionalNonNegativeMoney(Object? value, String field) {
    final raw = value?.toString().replaceAll(',', '').trim() ?? '';
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed < 0) {
      throw ApiException('$field غير صحيح.');
    }
    return parsed;
  }

  void _assertFinancialCommitmentAmounts({
    required String totalAmount,
    String? paidAmount,
  }) {
    final total = _assertPositiveMoney(totalAmount, 'totalAmount');
    final paid = _assertOptionalNonNegativeMoney(paidAmount, 'paidAmount');
    if (paid > total) {
      throw const ApiException(
        'المدفوع لا يمكن أن يتجاوز التكلفة المتفق عليها.',
      );
    }
  }

  void _assertPaymentWithinRemaining({
    required Map<String, dynamic> commitment,
    required num amount,
  }) {
    if (commitment['status']?.toString() == 'CANCELLED') {
      throw const ApiException('لا يمكن تسجيل دفعة على التزام ملغي.');
    }
    final total = _moneyValue(commitment['totalAmount']);
    final paid = _moneyValue(commitment['paidAmount']);
    final remaining = (total - paid).clamp(0, total);
    if (amount > remaining) {
      throw const ApiException('مبلغ الدفعة لا يمكن أن يتجاوز الباقي المستحق.');
    }
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

  Future<BudgetCategory> _updateLocalBudgetCategory({
    required BudgetCategory category,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      id: category.id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...payload,
      'id': category.id,
      'weddingPlanId': cached?['weddingPlanId'] ?? category.weddingPlanId,
      'createdAt': cached?['createdAt'] ?? category.createdAt.toIso8601String(),
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

  Future<FinancialCommitment> _createLocalFinancialCommitment({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final total = _assertPositiveMoney(payload['totalAmount'], 'totalAmount');
    final paid = _assertOptionalNonNegativeMoney(
      payload['paidAmount'],
      'paidAmount',
    );
    if (paid > total) {
      throw const ApiException(
        'المدفوع لا يمكن أن يتجاوز التكلفة المتفق عليها.',
      );
    }
    final remaining = (total - paid).clamp(0, total);
    final localJson = {
      ...payload,
      'id': 'local-financial-commitment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': weddingPlanId,
      'paidAmount': paid.toStringAsFixed(2),
      'remainingAmount': remaining.toStringAsFixed(2),
      'status': _deriveCommitmentStatus(total, paid),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      json: localJson,
      dirty: true,
    );
    if (paid > 0) {
      await _createLocalFinancialPaymentRecord(
        commitmentId: localJson['id']!.toString(),
        payload: {
          'title': 'دفعة أولى: ${payload['title'] ?? ''}',
          'amount': paid.toStringAsFixed(2),
          'paidAt': payload['agreementDate'] ?? now.toIso8601String(),
        },
        updateCommitmentBalance: false,
      );
    }
    await _offline?.refreshStatus();
    return FinancialCommitment.fromJson(localJson);
  }

  Future<FinancialPaymentRecord> _createLocalFinancialPaymentRecord({
    required String commitmentId,
    required Map<String, dynamic> payload,
    bool updateCommitmentBalance = true,
  }) async {
    final commitment = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      id: commitmentId,
    );
    if (commitment == null) {
      throw const ApiException('تعذر العثور على المستحق المالي.');
    }
    final now = DateTime.now();
    final amount = _assertPositiveMoney(payload['amount'], 'amount');
    if (updateCommitmentBalance) {
      _assertPaymentWithinRemaining(commitment: commitment, amount: amount);
    }
    final localJson = {
      'id': 'local-financial-payment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': commitment['weddingPlanId'],
      'financialCommitmentId': commitmentId,
      'budgetCategoryId': commitment['budgetCategoryId'],
      'title': payload['title'] ?? 'دفعة: ${commitment['title'] ?? ''}',
      'amount': amount.toStringAsFixed(2),
      'paidAt': payload['paidAt'] ?? now.toIso8601String(),
      if (payload['method'] != null) 'method': payload['method'],
      if (payload['note'] != null) 'note': payload['note'],
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialPaymentRecords,
      json: localJson,
      dirty: true,
    );
    if (updateCommitmentBalance) {
      final total = _moneyValue(commitment['totalAmount']);
      final paid = _moneyValue(commitment['paidAmount']) + amount;
      final remaining = (total - paid).clamp(0, total);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        json: {
          ...commitment,
          'paidAmount': paid.toStringAsFixed(2),
          'remainingAmount': remaining.toStringAsFixed(2),
          'status': _deriveCommitmentStatus(total, paid),
          'updatedAt': now.toIso8601String(),
        },
        dirty: true,
      );
    }
    await _offline?.refreshStatus();
    return FinancialPaymentRecord.fromJson(localJson);
  }

  Future<FinancialInstallment> _createLocalFinancialInstallment({
    required String commitmentId,
    required Map<String, dynamic> payload,
  }) async {
    final commitment = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      id: commitmentId,
    );
    if (commitment == null) {
      throw const ApiException('تعذر العثور على المستحق المالي.');
    }
    final now = DateTime.now();
    final status = payload['status']?.toString() ?? 'PENDING';
    final localJson = {
      'id': 'local-financial-installment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': commitment['weddingPlanId'],
      'financialCommitmentId': commitmentId,
      'budgetCategoryId': commitment['budgetCategoryId'],
      ...payload,
      'status': status,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialInstallments,
      json: localJson,
      dirty: true,
    );
    if (status == 'PAID') {
      await _createLocalFinancialPaymentRecord(
        commitmentId: commitmentId,
        payload: {
          'title': 'قسط: ${commitment['title'] ?? ''}',
          'amount': payload['amount'],
          'paidAt': payload['paidAt'] ?? now.toIso8601String(),
          if (payload['note'] != null) 'note': payload['note'],
        },
      );
    }
    await _offline?.refreshStatus();
    return FinancialInstallment.fromJson(localJson);
  }

  bool _isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }

  bool _isDueFinancialInstallment(Map<String, dynamic> installment) {
    final status = installment['status']?.toString().toUpperCase() ?? '';
    return status != 'PAID' &&
        status != 'CANCELLED' &&
        installment['dueDate'] != null;
  }

  String _deriveCommitmentStatus(num total, num paid) {
    if (total <= 0 || paid <= 0) return 'OPEN';
    if (paid >= total) return 'PAID';
    return 'PARTIALLY_PAID';
  }
}
