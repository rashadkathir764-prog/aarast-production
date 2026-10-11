part of 'finance_api.dart';

// Wedding costs.
mixin _FinanceCostsApi on _FinanceApiCore {
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
    String? payer,
    String? payerName,
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
      payer: payer,
      payerName: payerName,
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
        planId: planId,
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
    String? payer,
    String? payerName,
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
      payer: payer,
      payerName: payerName,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
      );
      return local;
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
    String? payer,
    String? payerName,
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
      // Always sent, so an edit can also clear who pays.
      'payer': _nullableTrimmed(payer),
      'payerName': _nullableTrimmed(payerName),
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
}
