import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import 'finance_local_data_source.dart';
import 'finance_money_rules.dart';

class LocalFinancePlanContext {
  const LocalFinancePlanContext({this.estimatedBudget, this.currency});

  final String? estimatedBudget;
  final String? currency;
}

typedef LocalFinancePlanContextLoader =
    Future<LocalFinancePlanContext?> Function(String weddingPlanId);

class MoneyBudgetReplaceResult {
  const MoneyBudgetReplaceResult({
    required this.summary,
    required this.categories,
    required this.idMap,
  });

  factory MoneyBudgetReplaceResult.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'];
    final categoriesJson = json['categories'];
    final idMapJson = json['idMap'];
    if (summaryJson is! Map || categoriesJson is! List || idMapJson is! Map) {
      throw const ApiException(aarastBackendConnectionErrorMessage);
    }
    return MoneyBudgetReplaceResult(
      summary: MoneySummary.fromJson(Map<String, dynamic>.from(summaryJson)),
      categories: categoriesJson
          .whereType<Map>()
          .map(
            (item) => BudgetCategory.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      idMap: {
        for (final entry in idMapJson.entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  final MoneySummary summary;
  final List<BudgetCategory> categories;
  final Map<String, String> idMap;
}

class FinanceApi {
  const FinanceApi(
    this._apiClient, {
    OfflineSyncService? offline,
    LocalFinancePlanContextLoader? localPlanContextLoader,
  }) : _offline = offline,
       _localPlanContextLoader = localPlanContextLoader;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;
  final LocalFinancePlanContextLoader? _localPlanContextLoader;

  FinanceLocalDataSource get _local => FinanceLocalDataSource(_offline);

  Future<MoneySummary> getMoneySummary(String planId) async {
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final context = await _localPlanContextLoader?.call(planId);
      return _local.moneySummary(
        planId,
        estimatedBudget: context?.estimatedBudget,
        currency: context?.currency,
      );
    }
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$planId/money-summary',
      );
      final summary = MoneySummary.fromJson(json);
      await _cacheSummary(summary, planId);
      return summary;
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final context = await _localPlanContextLoader?.call(planId);
      return _local.moneySummary(
        planId,
        estimatedBudget: context?.estimatedBudget,
        currency: context?.currency,
      );
    }
  }

  Future<List<BudgetCategory>> getBudgetCategories(String planId) async {
    const table = OfflineTables.cachedBudgetCategories;
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final cached = await _readCachedPlanList(table, planId);
      return cached.map(BudgetCategory.fromJson).toList(growable: false);
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$planId/budget-categories',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: planId,
      );
      return items.map(BudgetCategory.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        planId: planId,
      );
      if (cached != null) return cached.map(BudgetCategory.fromJson).toList();
      rethrow;
    }
  }

  Future<MoneySummary> saveMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
  }) async {
    final result = await replaceMoneyBudget(
      planId: planId,
      totalBudget: totalBudget,
      currency: currency,
      categories: categories,
    );
    return result.summary;
  }

  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
  }) async {
    final payload = {
      'totalBudget': _nullableTrimmed(totalBudget),
      'currency': currency.trim().toUpperCase(),
      'categories': [
        for (final category in categories)
          {
            if (_isServerCategoryId(category.id))
              'id': category.id!.trim()
            else
              'clientId': _clientIdForLocalCategory(category.id),
            'name': category.name.trim(),
            'allocatedAmount': _nullableTrimmed(category.allocatedAmount),
          },
      ],
    };
    _validateBudgetPayload(payload);
    final mutation = _mutation(
      'PUT',
      '/api/v1/wedding-plans/$planId/money-budget',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      await _saveBudgetLocally(planId, payload);
      return _localBudgetResult(planId);
    }
    if (_offline?.hasPendingEntity('money_budget', planId) ?? false) {
      await _saveBudgetLocally(planId, payload);
      await _queueMoneyBudget(planId, mutation);
      await _offline?.syncPendingChanges();
      return _localBudgetResult(planId);
    }
    try {
      final json = await mutation.send();
      final result = MoneyBudgetReplaceResult.fromJson(json);
      await _cacheSummary(result.summary, planId);
      await _applyBudgetIdMap(result);
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedBudgetCategories,
        items: result.categories.map(_budgetCategoryJson).toList(),
        parentColumn: 'planId',
        parentId: planId,
        preserveDirty: false,
      );
      await _offline?.syncPendingChanges();
      return result;
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      await _saveBudgetLocally(planId, payload);
      await _queueMoneyBudget(planId, mutation);
      return _localBudgetResult(planId);
    }
  }

  Future<BudgetCategory> createBudgetCategory({
    required String planId,
    required String name,
    String? allocatedAmount,
  }) async {
    final payload = {
      'name': name.trim(),
      'allocatedAmount': _nullableTrimmed(allocatedAmount),
    };
    if (payload['name']!.isEmpty) {
      throw const ApiException('اكتب اسم التصنيف.');
    }
    final mutation = _mutation(
      'POST',
      '/api/v1/wedding-plans/$planId/budget-categories',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      return _local.createBudgetCategory(
        weddingPlanId: planId,
        payload: payload,
      );
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedBudgetCategories, json);
      return BudgetCategory.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.createBudgetCategory(
        weddingPlanId: planId,
        payload: payload,
      );
      await _queue(
        entityType: 'budget_category',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<BudgetCategory> updateBudgetCategory({
    required BudgetCategory category,
    required String name,
    String? allocatedAmount,
  }) async {
    final payload = {
      'name': name.trim(),
      'allocatedAmount': _nullableTrimmed(allocatedAmount),
    };
    if (payload['name']!.isEmpty) {
      throw const ApiException('اكتب اسم التصنيف.');
    }
    final mutation = _mutation(
      'PATCH',
      '/api/v1/budget-categories/${category.id}',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(category.weddingPlanId)) {
      return _local.updateBudgetCategory(category: category, payload: payload);
    }
    if (category.id.startsWith('local-')) {
      final local = await _local.updateBudgetCategory(
        category: category,
        payload: payload,
      );
      await _queue(
        entityType: 'budget_category',
        operation: 'update',
        mutation: mutation,
        localId: category.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedBudgetCategories, json);
      return BudgetCategory.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.updateBudgetCategory(
        category: category,
        payload: payload,
      );
      await _queue(
        entityType: 'budget_category',
        operation: 'update',
        mutation: mutation,
        localId: category.id,
      );
      return local;
    }
  }

  Future<void> deleteBudgetCategory(BudgetCategory category) async {
    if (category.costsCount > 0 || await _local.categoryHasCosts(category.id)) {
      throw const ApiException(
        'انقل تكاليف هذا التصنيف أو احذفها قبل حذف التصنيف.',
      );
    }
    final mutation = _mutation(
      'DELETE',
      '/api/v1/budget-categories/${category.id}',
      const {},
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(category.weddingPlanId)) {
      await _local.markDeleted(
        table: OfflineTables.cachedBudgetCategories,
        id: category.id,
      );
      return;
    }
    if (category.id.startsWith('local-')) {
      await _local.markDeleted(
        table: OfflineTables.cachedBudgetCategories,
        id: category.id,
      );
      await _queue(
        entityType: 'budget_category',
        operation: 'delete',
        mutation: mutation,
        localId: category.id,
      );
      return;
    }
    try {
      await mutation.send();
      await _local.markDeleted(
        table: OfflineTables.cachedBudgetCategories,
        id: category.id,
      );
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      await _local.markDeleted(
        table: OfflineTables.cachedBudgetCategories,
        id: category.id,
      );
      await _queue(
        entityType: 'budget_category',
        operation: 'delete',
        mutation: mutation,
        localId: category.id,
      );
    }
  }

  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
  }) async {
    const table = OfflineTables.cachedCosts;
    final path = Uri(
      path: '/api/v1/wedding-plans/$planId/costs',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (_nullableTrimmed(status) != null) 'status': status!.trim(),
        if (_nullableTrimmed(categoryId) != null)
          'categoryId': categoryId!.trim(),
        if (_nullableTrimmed(search) != null) 'search': search!.trim(),
      },
    ).toString();
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final cached = await _readCachedPlanList(table, planId);
      return _localCostPage(
        cached,
        page: page,
        limit: limit,
        status: status,
        categoryId: categoryId,
        search: search,
      );
    }
    try {
      final json = await _apiClient.getJson(path);
      final result = FinancePage<WeddingCost>.fromJson(
        json,
        WeddingCost.fromJson,
      );
      if (page == 1 && status == null && categoryId == null && search == null) {
        await _offline?.database.replaceCachedList(
          table: table,
          items: _listOfMaps(json['items']),
          parentColumn: 'planId',
          parentId: planId,
        );
      } else {
        for (final item in _listOfMaps(json['items'])) {
          await _cache(table, item);
        }
      }
      return result;
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        planId: planId,
      );
      if (cached != null) {
        return _localCostPage(
          cached,
          page: page,
          limit: limit,
          status: status,
          categoryId: categoryId,
          search: search,
        );
      }
      rethrow;
    }
  }

  Future<WeddingCost> getCost(String costId) async {
    if (costId.startsWith('local-')) {
      final cached = await _offline?.database.readCachedItem(
        table: OfflineTables.cachedCosts,
        id: costId,
      );
      if (cached == null) {
        throw const ApiException('تعذر العثور على التكلفة.');
      }
      return WeddingCost.fromJson(cached);
    }
    try {
      final json = await _apiClient.getJson('/api/v1/costs/$costId');
      await _cache(OfflineTables.cachedCosts, json);
      return WeddingCost.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedCosts,
        id: costId,
      );
      if (cached == null) rethrow;
      return WeddingCost.fromJson(cached);
    }
  }

  Future<WeddingCost> createCost({
    required String planId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    DateTime? agreementDate,
    String? note,
  }) async {
    FinanceMoneyRules.assertCostAmounts(
      totalAmount: totalAmount,
      initialPaymentAmount: initialPaymentAmount,
    );
    _assertPartyChoice(providerId: providerId, partyName: partyName);
    final payload = _costPayload(
      budgetCategoryId: budgetCategoryId,
      title: title,
      totalAmount: totalAmount,
      initialPaymentAmount: initialPaymentAmount,
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      agreementDate: agreementDate,
      note: note,
    );
    final mutation = _mutation(
      'POST',
      '/api/v1/wedding-plans/$planId/costs',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      return _local.createCost(weddingPlanId: planId, payload: payload);
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedCosts, json);
      await _offline?.syncPendingChanges();
      return WeddingCost.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.createCost(
        weddingPlanId: planId,
        payload: payload,
      );
      await _queue(
        entityType: 'cost',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<WeddingCost> updateCost({
    required WeddingCost cost,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    DateTime? agreementDate,
    String? note,
  }) async {
    _assertPartyChoice(providerId: providerId, partyName: partyName);
    final payload = _costPayload(
      budgetCategoryId: budgetCategoryId,
      title: title,
      totalAmount: totalAmount,
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      agreementDate: agreementDate,
      note: note,
    );
    final mutation = _mutation('PATCH', '/api/v1/costs/${cost.id}', payload);
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.updateCost(cost: cost, payload: payload);
    }
    if (cost.id.startsWith('local-')) {
      final local = await _local.updateCost(cost: cost, payload: payload);
      await _queue(
        entityType: 'cost',
        operation: 'update',
        mutation: mutation,
        localId: cost.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedCosts, json);
      return WeddingCost.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.updateCost(cost: cost, payload: payload);
      await _queue(
        entityType: 'cost',
        operation: 'update',
        mutation: mutation,
        localId: cost.id,
      );
      return local;
    }
  }

  Future<void> deleteCost(WeddingCost cost) async {
    if (!cost.canDelete) {
      throw const ApiException(
        'لا يمكن حذف تكلفة لها دفعات. ألغِ التكلفة للاحتفاظ بالسجل الصحيح.',
      );
    }
    final mutation = _mutation('DELETE', '/api/v1/costs/${cost.id}', const {});
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      await _local.markDeleted(table: OfflineTables.cachedCosts, id: cost.id);
      return;
    }
    if (cost.id.startsWith('local-')) {
      await _local.markDeleted(table: OfflineTables.cachedCosts, id: cost.id);
      await _queue(
        entityType: 'cost',
        operation: 'delete',
        mutation: mutation,
        localId: cost.id,
      );
      return;
    }
    try {
      await mutation.send();
      await _local.markDeleted(table: OfflineTables.cachedCosts, id: cost.id);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      await _local.markDeleted(table: OfflineTables.cachedCosts, id: cost.id);
      await _queue(
        entityType: 'cost',
        operation: 'delete',
        mutation: mutation,
        localId: cost.id,
      );
    }
  }

  Future<WeddingCost> cancelCost(WeddingCost cost) async {
    if (cost.hasActivePayments) {
      throw const ApiException('اعكس الدفعات القائمة أولًا قبل إلغاء التكلفة.');
    }
    final mutation = _mutation(
      'POST',
      '/api/v1/costs/${cost.id}/cancel',
      const {},
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.cancelCost(cost);
    }
    if (cost.id.startsWith('local-')) {
      final local = await _local.cancelCost(cost);
      await _queue(
        entityType: 'cost',
        operation: 'cancel',
        mutation: mutation,
        localId: cost.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedCosts, json);
      return WeddingCost.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.cancelCost(cost);
      await _queue(
        entityType: 'cost',
        operation: 'cancel',
        mutation: mutation,
        localId: cost.id,
      );
      return local;
    }
  }

  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    const table = OfflineTables.cachedCostPayments;
    final path = Uri(
      path: '/api/v1/wedding-plans/$planId/cost-payments',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    ).toString();
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final cached = await _readCachedPlanList(table, planId);
      return _localPage(
        cached.map(CostPayment.fromJson).toList(),
        page: page,
        limit: limit,
      );
    }
    try {
      final json = await _apiClient.getJson(path);
      final result = FinancePage<CostPayment>.fromJson(
        json,
        CostPayment.fromJson,
      );
      if (page == 1) {
        await _offline?.database.replaceCachedList(
          table: table,
          items: _listOfMaps(json['items']),
          parentColumn: 'planId',
          parentId: planId,
        );
      } else {
        for (final item in _listOfMaps(json['items'])) {
          await _cache(table, item);
        }
      }
      return result;
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        planId: planId,
      );
      if (cached != null) {
        return _localPage(
          cached.map(CostPayment.fromJson).toList(),
          page: page,
          limit: limit,
        );
      }
      rethrow;
    }
  }

  Future<CostPayment> getPayment(String paymentId) async {
    if (paymentId.startsWith('local-')) {
      final cached = await _offline?.database.readCachedItem(
        table: OfflineTables.cachedCostPayments,
        id: paymentId,
      );
      if (cached == null) {
        throw const ApiException('تعذر العثور على الدفعة.');
      }
      return CostPayment.fromJson(cached);
    }
    try {
      final json = await _apiClient.getJson('/api/v1/cost-payments/$paymentId');
      await _cache(OfflineTables.cachedCostPayments, json);
      return CostPayment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedCostPayments,
        id: paymentId,
      );
      if (cached == null) rethrow;
      return CostPayment.fromJson(cached);
    }
  }

  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async {
    if (costId.startsWith('local-')) {
      final cached = await _offline?.database.readCachedList(
        table: OfflineTables.cachedCostPayments,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .where((item) => item['costId']?.toString() == costId)
          .map(CostPayment.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList('/api/v1/costs/$costId/payments');
      for (final item in items) {
        await _cache(OfflineTables.cachedCostPayments, item);
      }
      return items.map(CostPayment.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedList(
        table: OfflineTables.cachedCostPayments,
      );
      final filtered = cached
          .where((item) => item['costId']?.toString() == costId)
          .toList();
      if (filtered.isEmpty) rethrow;
      return filtered.map(CostPayment.fromJson).toList();
    }
  }

  Future<CostPayment> createPayment({
    required WeddingCost cost,
    required String amount,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    final paymentAmount = FinanceMoneyRules.assertPositive(amount, 'المبلغ');
    FinanceMoneyRules.assertPaymentWithinRemaining(
      cost: {
        'totalAmount': cost.totalAmount,
        'paidAmount': cost.paidAmount,
        'status': cost.status,
      },
      amount: paymentAmount,
    );
    final payload = {
      'amount': amount.trim(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (_nullableTrimmed(method) != null) 'method': method!.trim(),
      if (_nullableTrimmed(note) != null) 'note': note!.trim(),
    };
    final mutation = _mutation(
      'POST',
      '/api/v1/costs/${cost.id}/payments',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.createPayment(cost: cost, payload: payload);
    }
    if (cost.id.startsWith('local-')) {
      final local = await _local.createPayment(cost: cost, payload: payload);
      await _queue(
        entityType: 'cost_payment',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedCostPayments, json);
      return CostPayment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.createPayment(cost: cost, payload: payload);
      await _queue(
        entityType: 'cost_payment',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<CostPayment> reversePayment({
    required CostPayment payment,
    required WeddingCost cost,
    required String reason,
  }) async {
    final payload = {'reason': reason.trim()};
    if (payload['reason']!.isEmpty) {
      throw const ApiException('اكتب سبب عكس الدفعة.');
    }
    final mutation = _mutation(
      'POST',
      '/api/v1/cost-payments/${payment.id}/reverse',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.reversePayment(
        payment: payment,
        cost: cost,
        reason: reason,
      );
    }
    if (payment.id.startsWith('local-')) {
      final local = await _local.reversePayment(
        payment: payment,
        cost: cost,
        reason: reason,
      );
      await _queue(
        entityType: 'cost_payment',
        operation: 'reverse',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedCostPayments, json);
      return CostPayment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.reversePayment(
        payment: payment,
        cost: cost,
        reason: reason,
      );
      await _queue(
        entityType: 'cost_payment',
        operation: 'reverse',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async {
    const table = OfflineTables.cachedPaymentSchedules;
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final cached = await _readCachedPlanList(table, planId);
      return _dueSchedules(cached);
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$planId/payment-schedules/due',
      );
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: 'planId',
        parentId: planId,
      );
      return items.map(PaymentSchedule.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: table,
        planId: planId,
      );
      if (cached != null) return _dueSchedules(cached);
      rethrow;
    }
  }

  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async {
    if (costId.startsWith('local-')) {
      return _cachedSchedulesForCost(costId);
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/costs/$costId/payment-schedules',
      );
      for (final item in items) {
        await _cache(OfflineTables.cachedPaymentSchedules, item);
      }
      return items.map(PaymentSchedule.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _cachedSchedulesForCost(costId);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<PaymentSchedule> createSchedule({
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) async {
    final payload = {
      'amount': amount.trim(),
      'dueDate': _dateOnly(dueDate),
      if (_nullableTrimmed(note) != null) 'note': note!.trim(),
    };
    final mutation = _mutation(
      'POST',
      '/api/v1/costs/${cost.id}/payment-schedules',
      payload,
    );
    FinanceMoneyRules.assertPositive(amount, 'المبلغ');
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.createSchedule(cost: cost, payload: payload);
    }
    if (cost.id.startsWith('local-')) {
      final local = await _local.createSchedule(cost: cost, payload: payload);
      await _queue(
        entityType: 'payment_schedule',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedPaymentSchedules, json);
      return PaymentSchedule.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.createSchedule(cost: cost, payload: payload);
      await _queue(
        entityType: 'payment_schedule',
        operation: 'create',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<PaymentSchedule> updateSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) async {
    final payload = {
      'amount': amount.trim(),
      'dueDate': _dateOnly(dueDate),
      'note': _nullableTrimmed(note),
    };
    final mutation = _mutation(
      'PATCH',
      '/api/v1/payment-schedules/${schedule.id}',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.updateSchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
    }
    if (schedule.id.startsWith('local-')) {
      final local = await _local.updateSchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'update',
        mutation: mutation,
        localId: schedule.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedPaymentSchedules, json);
      return PaymentSchedule.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.updateSchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'update',
        mutation: mutation,
        localId: schedule.id,
      );
      return local;
    }
  }

  Future<void> deleteSchedule(PaymentSchedule schedule) async {
    if (!schedule.isPending) {
      throw const ApiException('لا يمكن حذف موعد مدفوع أو ملغي.');
    }
    final mutation = _mutation(
      'DELETE',
      '/api/v1/payment-schedules/${schedule.id}',
      const {},
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(schedule.weddingPlanId)) {
      await _local.markDeleted(
        table: OfflineTables.cachedPaymentSchedules,
        id: schedule.id,
      );
      return;
    }
    if (schedule.id.startsWith('local-')) {
      await _local.markDeleted(
        table: OfflineTables.cachedPaymentSchedules,
        id: schedule.id,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'delete',
        mutation: mutation,
        localId: schedule.id,
      );
      return;
    }
    try {
      await mutation.send();
      await _local.markDeleted(
        table: OfflineTables.cachedPaymentSchedules,
        id: schedule.id,
      );
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      await _local.markDeleted(
        table: OfflineTables.cachedPaymentSchedules,
        id: schedule.id,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'delete',
        mutation: mutation,
        localId: schedule.id,
      );
    }
  }

  Future<PaymentSchedule> cancelSchedule(PaymentSchedule schedule) async {
    if (schedule.isCancelled) return schedule;
    if (!schedule.isPending) {
      throw const ApiException('اعكس الدفعة أولًا قبل إلغاء موعد الدفع.');
    }
    final mutation = _mutation(
      'POST',
      '/api/v1/payment-schedules/${schedule.id}/cancel',
      const {},
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(schedule.weddingPlanId)) {
      return _cancelScheduleLocally(schedule);
    }
    if (schedule.id.startsWith('local-')) {
      final local = await _cancelScheduleLocally(schedule);
      await _queue(
        entityType: 'payment_schedule',
        operation: 'cancel',
        mutation: mutation,
        localId: schedule.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      await _cache(OfflineTables.cachedPaymentSchedules, json);
      return PaymentSchedule.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _cancelScheduleLocally(schedule);
      await _queue(
        entityType: 'payment_schedule',
        operation: 'cancel',
        mutation: mutation,
        localId: schedule.id,
      );
      return local;
    }
  }

  Future<CostPayment> paySchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    final payload = {
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (_nullableTrimmed(method) != null) 'method': method!.trim(),
      if (_nullableTrimmed(note) != null) 'note': note!.trim(),
    };
    final mutation = _mutation(
      'POST',
      '/api/v1/payment-schedules/${schedule.id}/pay',
      payload,
    );
    if (FinanceLocalDataSource.isLocalGuestPlanId(cost.weddingPlanId)) {
      return _local.paySchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
    }
    if (schedule.id.startsWith('local-')) {
      final local = await _local.paySchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'pay',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
    try {
      final json = await mutation.send();
      if (json['payment'] is! Map || json['schedule'] is! Map) {
        throw const FormatException('Invalid payment schedule pay response.');
      }
      final paymentJson = Map<String, dynamic>.from(json['payment'] as Map);
      final scheduleJson = Map<String, dynamic>.from(json['schedule'] as Map);
      await _cache(OfflineTables.cachedCostPayments, paymentJson);
      await _cache(OfflineTables.cachedPaymentSchedules, scheduleJson);
      return CostPayment.fromJson(paymentJson);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueReplay(error) || _offline == null) rethrow;
      final local = await _local.paySchedule(
        schedule: schedule,
        cost: cost,
        payload: payload,
      );
      await _queue(
        entityType: 'payment_schedule',
        operation: 'pay',
        mutation: mutation,
        localId: local.id,
      );
      return local;
    }
  }

  Future<List<PaymentSchedule>> _cachedSchedulesForCost(String costId) async {
    final cached = await _offline?.database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    return (cached ?? const <Map<String, dynamic>>[])
        .where((item) => item['costId']?.toString() == costId)
        .map(PaymentSchedule.fromJson)
        .toList();
  }

  Future<void> _cacheSummary(MoneySummary summary, String planId) async {
    await _local.saveBudgetMetadata(
      planId: planId,
      totalBudget: summary.budget.total,
      currency: summary.currency,
    );
  }

  Future<MoneyBudgetReplaceResult> _localBudgetResult(String planId) async {
    final context = await _localPlanContextLoader?.call(planId);
    final summary = await _local.moneySummary(
      planId,
      estimatedBudget: context?.estimatedBudget,
      currency: context?.currency,
    );
    final categories = (await _readCachedPlanList(
      OfflineTables.cachedBudgetCategories,
      planId,
    )).map(BudgetCategory.fromJson).toList(growable: false);
    return MoneyBudgetReplaceResult(
      summary: summary,
      categories: categories,
      idMap: const {},
    );
  }

  Future<PaymentSchedule> _cancelScheduleLocally(
    PaymentSchedule schedule,
  ) async {
    final json = _paymentScheduleJson(
      schedule,
      status: 'CANCELLED',
      paidAt: null,
      updatedAt: DateTime.now(),
    );
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedPaymentSchedules,
      json: json,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return PaymentSchedule.fromJson(json);
  }

  Future<void> _saveBudgetLocally(
    String planId,
    Map<String, dynamic> payload,
  ) async {
    final now = DateTime.now();
    final incoming = _listOfMaps(payload['categories']);
    final categories = <Map<String, dynamic>>[];
    for (final category in incoming) {
      categories.add({
        ...category,
        'id':
            _nullableTrimmed(category['id']?.toString()) ??
            _localCategoryId(category['clientId']?.toString()),
        'weddingPlanId': planId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    }
    await _local.saveBudget(
      planId: planId,
      totalBudget: _nullableTrimmed(payload['totalBudget']?.toString()),
      currency: payload['currency']?.toString() ?? 'YER',
      categories: categories,
    );
  }

  Future<void> _applyBudgetIdMap(MoneyBudgetReplaceResult result) async {
    final database = _offline?.database;
    if (database == null || result.idMap.isEmpty) return;
    final remoteById = {
      for (final category in result.categories) category.id: category,
    };
    for (final entry in result.idMap.entries) {
      final remote = remoteById[entry.value];
      if (remote == null) continue;
      final localId = _localCategoryId(entry.key);
      await database.replaceCachedItemId(
        table: OfflineTables.cachedBudgetCategories,
        localId: localId,
        remoteJson: _budgetCategoryJson(remote),
      );
      await database.rewriteQueuedReferences(
        localId: localId,
        remoteId: entry.value,
      );
      await _rewriteCachedMoneyReferences(
        localId: localId,
        remoteId: entry.value,
      );
    }
  }

  Future<void> _rewriteCachedMoneyReferences({
    required String localId,
    required String remoteId,
  }) async {
    final database = _offline?.database;
    if (database == null || localId.isEmpty || localId == remoteId) return;
    for (final table in const [
      OfflineTables.cachedCosts,
      OfflineTables.cachedCostPayments,
      OfflineTables.cachedPaymentSchedules,
    ]) {
      final rows = await database.readCachedList(table: table);
      for (final row in rows) {
        final rewritten = _replaceExactString(row, localId, remoteId);
        if (!identical(rewritten, row)) {
          await database.saveCachedItem(
            table: table,
            json: Map<String, dynamic>.from(rewritten as Map),
            dirty: true,
          );
        }
      }
    }
  }

  Object? _replaceExactString(Object? value, String localId, String remoteId) {
    if (value is String) return value == localId ? remoteId : value;
    if (value is List) {
      var changed = false;
      final next = <Object?>[];
      for (final item in value) {
        final rewritten = _replaceExactString(item, localId, remoteId);
        changed = changed || !identical(rewritten, item);
        next.add(rewritten);
      }
      return changed ? next : value;
    }
    if (value is Map) {
      var changed = false;
      final next = <String, dynamic>{};
      for (final entry in value.entries) {
        final rewritten = _replaceExactString(entry.value, localId, remoteId);
        changed = changed || !identical(rewritten, entry.value);
        next[entry.key.toString()] = rewritten;
      }
      return changed ? next : value;
    }
    return value;
  }

  void _validateBudgetPayload(Map<String, dynamic> payload) {
    final totalRaw = _nullableTrimmed(payload['totalBudget']?.toString());
    final total = totalRaw == null
        ? null
        : FinanceMoneyRules.assertPositive(totalRaw, 'الميزانية');
    final categories = _listOfMaps(payload['categories']);
    final names = <String>{};
    var allocated = 0.0;
    for (final category in categories) {
      final id = _nullableTrimmed(category['id']?.toString());
      final clientId = _nullableTrimmed(category['clientId']?.toString());
      if ((id == null) == (clientId == null)) {
        throw const ApiException(
          'تعذر حفظ التصنيفات: لكل تصنيف معرّف واحد فقط.',
        );
      }
      if (clientId != null && !_uuidV4Pattern.hasMatch(clientId)) {
        throw const ApiException(
          'تعذر حفظ التصنيف الجديد: معرّف المزامنة غير صالح.',
        );
      }
      final name = category['name']?.toString().trim() ?? '';
      if (name.isEmpty) throw const ApiException('اسم التصنيف مطلوب.');
      if (!names.add(name.toLowerCase())) {
        throw const ApiException('لا يمكن تكرار اسم التصنيف.');
      }
      allocated += FinanceMoneyRules.assertOptionalNonNegative(
        category['allocatedAmount'],
        'مخصص التصنيف',
      ).toDouble();
    }
    if (total == null && allocated > 0) {
      throw const ApiException(
        'حدد الميزانية أولًا قبل توزيع مبالغ على التصنيفات.',
      );
    }
    if (total != null && allocated > total) {
      throw const ApiException('مجموع مخصصات التصنيفات يتجاوز الميزانية.');
    }
  }

  Map<String, dynamic> _costPayload({
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    DateTime? agreementDate,
    String? note,
  }) {
    if (budgetCategoryId.trim().isEmpty) {
      throw const ApiException('اختر تصنيف التكلفة.');
    }
    if (title.trim().isEmpty) {
      throw const ApiException('اكتب اسم التكلفة.');
    }
    return {
      'budgetCategoryId': budgetCategoryId.trim(),
      'title': title.trim(),
      'totalAmount': totalAmount.trim(),
      if (_nullableTrimmed(initialPaymentAmount) != null)
        'initialPaymentAmount': initialPaymentAmount!.trim(),
      if (_nullableTrimmed(providerId) != null)
        'providerId': providerId!.trim(),
      if (_nullableTrimmed(quoteOfferId) != null)
        'quoteOfferId': quoteOfferId!.trim(),
      if (_nullableTrimmed(partyName) != null) 'partyName': partyName!.trim(),
      if (_nullableTrimmed(partyPhone) != null)
        'partyPhone': partyPhone!.trim(),
      if (agreementDate != null)
        'agreementDate': agreementDate.toIso8601String(),
      if (_nullableTrimmed(note) != null) 'note': note!.trim(),
    };
  }

  void _assertPartyChoice({String? providerId, String? partyName}) {
    if (_nullableTrimmed(providerId) != null &&
        _nullableTrimmed(partyName) != null) {
      throw const ApiException(
        'اختر مزودًا من أعرست أو جهة خارجية، وليس كليهما.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    try {
      final list = await _apiClient.getJsonList(path);
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode != null || error.isNetworkFailure) rethrow;
      final json = await _apiClient.getJson(path);
      for (final key in const ['items', 'data', 'results']) {
        final value = json[key];
        if (value is List) return _listOfMaps(value);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    required String planId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _readCachedPlanList(table, planId);
    return cached.isEmpty ? null : cached;
  }

  Future<List<Map<String, dynamic>>> _readCachedPlanList(
    String table,
    String planId,
  ) async {
    return await _offline?.database.readCachedList(
          table: table,
          parentColumn: 'planId',
          parentId: planId,
        ) ??
        const [];
  }

  Future<void> _cache(String table, Map<String, dynamic> json) async {
    await _offline?.database.saveCachedItem(table: table, json: json);
  }

  Future<void> _queue({
    required String entityType,
    required String operation,
    required _FinanceMutation mutation,
    required String localId,
  }) async {
    final offline = _offline;
    if (offline == null) return;
    await offline.database.enqueueSync(
      entityType: entityType,
      operation: operation,
      endpoint: mutation.endpoint,
      method: mutation.method,
      payload: mutation.payload,
      localEntityId: localId,
      clientRequestId: mutation.clientRequestId,
    );
    await offline.refreshStatus();
  }

  Future<void> _queueMoneyBudget(
    String planId,
    _FinanceMutation mutation,
  ) async {
    final offline = _offline;
    if (offline == null) return;
    await offline.database.enqueueSync(
      entityType: 'money_budget',
      operation: 'replace',
      endpoint: mutation.endpoint,
      method: mutation.method,
      payload: mutation.payload,
      localEntityId: planId,
      replacePendingForEntity: true,
      clientRequestId: mutation.clientRequestId,
    );
    await offline.refreshStatus();
  }

  _FinanceMutation _mutation(
    String method,
    String endpoint,
    Map<String, dynamic> payload,
  ) => _FinanceMutation(_apiClient, method, endpoint, payload, _uuidV4());
}

class _FinanceMutation {
  const _FinanceMutation(
    this.apiClient,
    this.method,
    this.endpoint,
    this.payload,
    this.clientRequestId,
  );

  final ApiClient apiClient;
  final String method;
  final String endpoint;
  final Map<String, dynamic> payload;
  final String clientRequestId;

  Future<Map<String, dynamic>> send() => apiClient.mutateJson(
    endpoint,
    payload,
    method: method,
    clientRequestId: clientRequestId,
  );
}

class FinancePage<T> {
  const FinancePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory FinancePage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return FinancePage(
      items: _listOfMaps(json['items']).map(fromJson).toList(),
      page: intOrNull(json['page']) ?? 1,
      pageSize: intOrNull(json['pageSize']) ?? 0,
      total: intOrNull(json['total']) ?? 0,
      totalPages: intOrNull(json['totalPages']) ?? 1,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

FinancePage<WeddingCost> _localCostPage(
  List<Map<String, dynamic>> raw, {
  required int page,
  required int limit,
  String? status,
  String? categoryId,
  String? search,
}) {
  final query = search?.trim().toLowerCase();
  final items = raw.map(WeddingCost.fromJson).where((cost) {
    if (_nullableTrimmed(status) != null && cost.status != status) return false;
    if (_nullableTrimmed(categoryId) != null &&
        cost.budgetCategoryId != categoryId) {
      return false;
    }
    if (query != null &&
        query.isNotEmpty &&
        !cost.title.toLowerCase().contains(query) &&
        !(cost.partyLabel?.toLowerCase().contains(query) ?? false)) {
      return false;
    }
    return true;
  }).toList();
  return _localPage(items, page: page, limit: limit);
}

FinancePage<T> _localPage<T>(
  List<T> items, {
  required int page,
  required int limit,
}) {
  final safePage = page < 1 ? 1 : page;
  final safeLimit = limit.clamp(1, 100);
  final start = (safePage - 1) * safeLimit;
  final end = (start + safeLimit).clamp(0, items.length);
  final pageItems = start >= items.length ? <T>[] : items.sublist(start, end);
  final pages = items.isEmpty ? 1 : (items.length / safeLimit).ceil();
  return FinancePage(
    items: pageItems,
    page: safePage,
    pageSize: safeLimit,
    total: items.length,
    totalPages: pages,
  );
}

List<PaymentSchedule> _dueSchedules(List<Map<String, dynamic>> items) {
  final today = DateTime.now();
  final end = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(const Duration(days: 30));
  return items
      .map(PaymentSchedule.fromJson)
      .where(
        (schedule) =>
            schedule.isPending &&
            (schedule.isOverdue || !schedule.dueDate.isAfter(end)),
      )
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

bool _isServerCategoryId(String? value) {
  final id = _nullableTrimmed(value);
  return id != null && !id.startsWith('local-');
}

const _localCategoryPrefix = 'local-budget-category-';

String _clientIdForLocalCategory(String? id) {
  final value = _nullableTrimmed(id);
  if (value != null && value.startsWith(_localCategoryPrefix)) {
    final candidate = value.substring(_localCategoryPrefix.length);
    if (_uuidV4Pattern.hasMatch(candidate)) return candidate;
  }
  return _uuidV4();
}

String _localCategoryId(String? clientId) {
  final value = _nullableTrimmed(clientId);
  if (value == null || !_uuidV4Pattern.hasMatch(value)) {
    throw const ApiException(
      'تعذر حفظ التصنيف الجديد: معرّف المزامنة غير صالح.',
    );
  }
  return '$_localCategoryPrefix$value';
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Map<String, dynamic> _budgetCategoryJson(BudgetCategory category) {
  return {
    'id': category.id,
    'weddingPlanId': category.weddingPlanId,
    'name': category.name,
    'allocatedAmount': category.allocatedAmount,
    'confirmedCost': category.confirmedCost,
    'paid': category.paid,
    'outstanding': category.outstanding,
    'remainingAllocation': category.remainingAllocation,
    'costsCount': category.costsCount,
    'createdAt': category.createdAt?.toIso8601String(),
    'updatedAt': category.updatedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _paymentScheduleJson(
  PaymentSchedule schedule, {
  required String status,
  required DateTime? paidAt,
  required DateTime updatedAt,
}) {
  return {
    'id': schedule.id,
    'costId': schedule.costId,
    'weddingPlanId': schedule.weddingPlanId,
    'budgetCategoryId': schedule.budgetCategoryId,
    'categoryName': schedule.categoryName,
    'providerId': schedule.providerId,
    'providerName': schedule.providerName,
    'costTitle': schedule.costTitle,
    'amount': schedule.amount,
    'dueDate': schedule.dueDate.toIso8601String(),
    'status': status,
    'paidAt': paidAt?.toIso8601String(),
    'note': schedule.note,
    'createdAt': schedule.createdAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

String? _nullableTrimmed(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
