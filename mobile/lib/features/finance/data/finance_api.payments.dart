part of 'finance_api.dart';

// Cost payments.
mixin _FinancePaymentsApi on _FinanceApiCore {
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
      if (paidAt != null) 'paidAt': _dateOnly(paidAt),
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
      );
      return local;
    }
  }
}
