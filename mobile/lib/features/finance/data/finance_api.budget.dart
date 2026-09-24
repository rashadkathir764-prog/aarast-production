part of 'finance_api.dart';

// Budget categories and the money budget.
mixin _FinanceBudgetApi on _FinanceApiCore {
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
        planId: planId,
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
        planId: category.weddingPlanId,
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
        planId: category.weddingPlanId,
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
        planId: category.weddingPlanId,
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
        planId: category.weddingPlanId,
      );
    }
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
      planId: planId,
      localEntityId: planId,
      replacePendingForEntity: true,
      clientRequestId: mutation.clientRequestId,
    );
    await offline.refreshStatus();
  }
}
