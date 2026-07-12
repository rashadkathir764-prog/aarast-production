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
import 'finance_local_data_source.dart';
import 'finance_money_rules.dart';

class LocalFinancePlanContext {
  const LocalFinancePlanContext({this.estimatedBudget, this.currency});

  final String? estimatedBudget;
  final String? currency;
}

typedef LocalFinancePlanContextLoader =
    Future<LocalFinancePlanContext?> Function(String weddingPlanId);

class BudgetExpenseApi {
  const BudgetExpenseApi(
    this._apiClient, {
    OfflineSyncService? offline,
    LocalFinancePlanContextLoader? localPlanContextLoader,
  }) : _offline = offline,
       _localPlanContextLoader = localPlanContextLoader;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;
  final LocalFinancePlanContextLoader? _localPlanContextLoader;

  FinanceLocalDataSource get _local => FinanceLocalDataSource(_offline);

  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    const table = OfflineTables.cachedBudgetCategories;
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
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
        '/api/v1/wedding-plans/$weddingPlanId/budget-categories',
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      return _local.createBudgetCategory(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.postJson(
        '/api/v1/wedding-plans/$weddingPlanId/budget-categories',
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
        endpoint: '/api/v1/wedding-plans/$weddingPlanId/budget-categories',
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
        FinanceLocalDataSource.isLocalGuestPlanId(category.weddingPlanId)) {
      return _local.updateBudgetCategory(category: category, payload: data);
    }
    try {
      final json = await _apiClient.patchJson(
        '/api/v1/budget-categories/${category.id}',
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
        endpoint: '/api/v1/budget-categories/${category.id}',
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
      await _apiClient.deleteJson('/api/v1/budget-categories/$id');
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
        endpoint: '/api/v1/budget-categories/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
      );
      await _offline.refreshStatus();
    }
  }

  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    const table = OfflineTables.cachedBudgetItems;
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
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
        '/api/v1/wedding-plans/$weddingPlanId/expenses',
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      final expenses = await _offline?.database.readCachedList(
        table: OfflineTables.cachedBudgetItems,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return _local.expenseSummaryFrom(
        expenses ?? const <Map<String, dynamic>>[],
      );
    }
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$weddingPlanId/expenses/summary',
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
      if (expenses.isNotEmpty) return _local.expenseSummaryFrom(expenses);
      rethrow;
    }
  }

  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    final key = 'money_summary:$weddingPlanId';
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      final context = await _localPlanContextLoader?.call(weddingPlanId);
      return _local.moneySummary(
        weddingPlanId,
        estimatedBudget: context?.estimatedBudget,
        currency: context?.currency,
      );
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
      return _local.moneySummary(weddingPlanId);
    }
  }

  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    const table = OfflineTables.cachedFinancialCommitments;
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: table,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .where(FinanceLocalDataSource.isDueFinancialInstallment)
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
            .where(FinanceLocalDataSource.isDueFinancialInstallment)
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
    FinanceMoneyRules.assertCommitmentAmounts(
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      return _local.createFinancialCommitment(
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
      final local = await _local.createFinancialCommitment(
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
    FinanceMoneyRules.assertPositive(amount, 'amount');
    final payload = {
      'amount': amount.trim(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (method != null && method.trim().isNotEmpty) 'method': method.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (commitmentId.startsWith('local-financial-commitment-')) {
      return _local.createFinancialPaymentRecord(
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
      final local = await _local.createFinancialPaymentRecord(
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

  Future<FinancialCommitment> updateFinancialCommitment({
    required FinancialCommitment commitment,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    required String sourceType,
    String? partyName,
    String? partyPhone,
    DateTime? dueDate,
    DateTime? agreementDate,
    String? note,
  }) async {
    FinanceMoneyRules.assertPositive(totalAmount, 'totalAmount');
    final payload = {
      'budgetCategoryId': budgetCategoryId.trim(),
      'sourceType': sourceType,
      'title': title.trim(),
      'totalAmount': totalAmount.trim(),
      'partyName': partyName?.trim(),
      'partyPhone': partyPhone?.trim(),
      'dueDate': dueDate?.toIso8601String(),
      'agreementDate': agreementDate?.toIso8601String(),
      'note': note?.trim(),
    };
    if (commitment.id.startsWith('local-financial-commitment-') ||
        FinanceLocalDataSource.isLocalGuestPlanId(commitment.weddingPlanId)) {
      return _local.updateFinancialCommitment(
        commitment: commitment,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.patchJson(
        '/api/v1/financial-commitments/${commitment.id}',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        json: json,
      );
      return FinancialCommitment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final local = await _local.updateFinancialCommitment(
        commitment: commitment,
        payload: payload,
      );
      await _offline.database.enqueueSync(
        entityType: 'financial_commitment',
        operation: 'update',
        endpoint: '/api/v1/financial-commitments/${commitment.id}',
        method: 'PATCH',
        payload: payload,
        localEntityId: commitment.id,
      );
      await _offline.refreshStatus();
      return local;
    }
  }

  Future<void> deleteFinancialCommitment(String id) async {
    try {
      await _apiClient.deleteJson('/api/v1/financial-commitments/$id');
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        json: {'id': id},
        dirty: true,
        deletedLocally: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'financial_commitment',
        operation: 'delete',
        endpoint: '/api/v1/financial-commitments/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
      );
      await _offline.refreshStatus();
    }
  }

  Future<void> reverseFinancialPaymentRecord(String id) async {
    // Reversals are deliberate ledger actions. Never report them as complete
    // while offline or leave them queued invisibly; the user retries online
    // and receives the server-confirmed compensating entry.
    await _apiClient.deleteJson('/api/v1/financial-payment-records/$id');
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
      return _local.createFinancialInstallment(
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
      final local = await _local.createFinancialInstallment(
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
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) {
      return _local.createExpense(
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }
    try {
      final json = await _apiClient.postJson(
        '/api/v1/wedding-plans/$weddingPlanId/expenses',
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
        endpoint: '/api/v1/wedding-plans/$weddingPlanId/expenses',
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
      return _local.updateExpense(
        id: id,
        weddingPlanId: weddingPlanId,
        payload: payload,
      );
    }

    try {
      final json = await _apiClient.patchJson('/api/v1/expenses/$id', payload);
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
        endpoint: '/api/v1/expenses/$id',
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
      await _apiClient.deleteJson('/api/v1/expenses/$id');
      await _local.markExpenseDeleted(id, dirty: false);
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _local.markExpenseDeleted(id, dirty: true);
      await _offline.database.enqueueSync(
        entityType: 'expense',
        operation: 'delete',
        endpoint: '/api/v1/expenses/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
      );
      await _offline.refreshStatus();
    }
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
}
