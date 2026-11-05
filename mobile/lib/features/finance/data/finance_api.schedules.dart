part of 'finance_api.dart';

// Payment schedules.
mixin _FinanceSchedulesApi on _FinanceApiCore {
  /// D85: the phone's copy of the due schedules alone.
  Future<List<PaymentSchedule>> cachedDueSchedules(String planId) async {
    final cached = await _readCachedPlanList(
      OfflineTables.cachedPaymentSchedules,
      planId,
    );
    return _dueSchedules(cached);
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
      // D86: the due ones join the phone's copy; the paid and the far ones
      // a cost's own read kept are not thrown away.
      for (final item in items) {
        await _cache(table, item);
      }
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
      OfflineReads.noteCopyServed();
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
        planId: _requiredPlanId(schedule.weddingPlanId),
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
        planId: _requiredPlanId(schedule.weddingPlanId),
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
        planId: _requiredPlanId(schedule.weddingPlanId),
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
        planId: _requiredPlanId(schedule.weddingPlanId),
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
      if (paidAt != null) 'paidAt': _dateOnly(paidAt),
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
        planId: cost.weddingPlanId,
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
        planId: cost.weddingPlanId,
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
}
