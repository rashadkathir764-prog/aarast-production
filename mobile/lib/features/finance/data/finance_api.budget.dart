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
    String? expectedBudgetVersion,
  }) async {
    final version = _nullableTrimmed(expectedBudgetVersion);
    final payload = {
      // D112 (Q-4): the budget this save was made from, as the server last
      // told it. A budget changed on another phone since refuses the save
      // instead of being overwritten by it.
      'expectedBudgetVersion': ?version,
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
      // The server's answer is the phone's copy of the picture (D86), with
      // the budget's new version: a save made later without a connection is
      // made from this one, not from the version before it.
      if (json['summary'] case final Map<String, dynamic> summaryJson) {
        await _offline?.database.setMeta(
          FinanceApi._summaryKey(planId),
          jsonEncode(summaryJson),
        );
      }
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

  /// D109: the item's own estimate («تقديرك»), apart from its allocation:
  /// free, may pass the budget, needs none; null clears it; zero is an
  /// answer («ما بيكلف شي»). Nothing else of the item changes.
  Future<BudgetCategory> setItemEstimate({
    required BudgetCategory category,
    required String? estimatedAmount,
  }) async {
    final estimate = _nullableTrimmed(estimatedAmount);
    if (estimate != null &&
        !FinanceMoneyRules.serverAmount.hasMatch(estimate)) {
      throw const ApiException('اكتب التقدير رقمًا صحيحًا.');
    }
    final payload = <String, dynamic>{'estimatedAmount': estimate};
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

  /// D72: the owner's answer to the home suggesting an item: «ما أحتاجها»
  /// (`NOT_NEEDED`), «بعدين» (`LATER`), or null to suggest it again. The item
  /// itself does not change. A plan kept on the phone gets no suggestions.
  Future<void> setBudgetItemSuggestion({
    required String weddingPlanId,
    required String categoryId,
    required String? choice,
  }) async {
    if (FinanceLocalDataSource.isLocalGuestPlanId(weddingPlanId)) return;
    // RA-MO-158 (D85): the home's suggestions are worked out by the server,
    // so the answer does not wait on the phone; offline it says why.
    await OfflineWrites(_apiClient, _offline).serverOnly(
      reason: 'الاقتراحات يرتبها الخادم، فجوابك يحتاج النت.',
      method: 'PUT',
      path: '/api/v1/budget-categories/$categoryId/suggestion',
      body: {'choice': choice},
      clientRequestId: _uuidV4(),
    );
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

  /// The budget total a plan kept on the phone holds now, as its money
  /// screens read it; null when it was never set or changed there.
  Future<String?> localBudgetTotal(String planId) async {
    final total = (await _local.readBudget(planId))?['totalBudget'];
    final text = total?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<MoneyBudgetReplaceResult> _localBudgetResult(String planId) async {
    final context = await _localPlanContextLoader?.call(planId);
    final summary = await _local.moneySummary(
      planId,
      estimatedBudget: context?.estimatedBudget,
      currency: context?.currency,
      persona: context?.persona,
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
          'ما قدرنا نحفظ التصنيفات. صار خطأ عندنا، جرّب مرة ثانية.',
        );
      }
      if (clientId != null && !_uuidV4Pattern.hasMatch(clientId)) {
        throw const ApiException('ما قدرنا نحفظ البند الجديد. جرّب مرة ثانية.');
      }
      final name = category['name']?.toString().trim() ?? '';
      if (name.isEmpty) throw const ApiException('اكتب اسم البند.');
      // D86: the server compares names with their spaces collapsed; so
      // does the phone, before a budget waits to be refused.
      final folded = name.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (!names.add(folded)) {
        throw const ApiException('فيه بند بنفس الاسم.');
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
    // D112 (Q-4): several saves made without a connection go as one, the
    // last. It was made from the budget the first of them read (what the
    // phone shows since is its own unsent work), so it keeps that version.
    var payload = mutation.payload;
    if (payload['expectedBudgetVersion'] == null) {
      final waiting = (await offline.database.pendingSyncItems())
          .where(
            (item) =>
                item.entityType == 'money_budget' &&
                item.localEntityId == planId,
          )
          .firstOrNull;
      final inherited = waiting?.payload['expectedBudgetVersion'];
      if (inherited is String && inherited.isNotEmpty) {
        payload = {...payload, 'expectedBudgetVersion': inherited};
      }
    }
    await offline.database.enqueueSync(
      entityType: 'money_budget',
      operation: 'replace',
      endpoint: mutation.endpoint,
      method: mutation.method,
      payload: payload,
      planId: planId,
      localEntityId: planId,
      replacePendingForEntity: true,
      clientRequestId: mutation.clientRequestId,
    );
    await offline.refreshStatus();
  }
}
