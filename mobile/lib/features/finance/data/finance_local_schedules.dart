part of 'finance_local_data_source.dart';

/// The phone's copy of an agreement's payment reminders, kept in step with
/// what the server does to them when the agreement's money changes.
extension _LocalSchedules on FinanceLocalDataSource {
  /// RA-BE-53: after a payment kept on the phone, each pending reminder of
  /// the agreement asks for at most what is now left, as the server reads it.
  Future<void> _refreshScheduleDues(String costId, String remaining) async {
    final schedules = await _offline?.database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    for (final schedule in schedules ?? const <Map<String, dynamic>>[]) {
      if (schedule['costId']?.toString() != costId ||
          schedule['status']?.toString() != 'PENDING') {
        continue;
      }
      final due = PaymentSchedule.fromJson(
        schedule,
      ).withRemaining(remaining).amountDue;
      if (due == schedule['amountDue']?.toString() &&
          remaining == schedule['costRemainingAmount']?.toString()) {
        continue;
      }
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...schedule,
        'amountDue': due,
        'costRemainingAmount': remaining,
      }, dirty: true);
    }
  }

  /// R4: an agreement paid in full cancels its pending reminders, marked as
  /// cancelled by it ([paidInFull]) so they come back once money is owed on
  /// it again (RA-BE-25); a cancelled agreement's do not.
  Future<void> _cancelPendingSchedules(
    String costId, {
    String? exceptScheduleId,
    bool paidInFull = false,
  }) async {
    final schedules = await _offline?.database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    for (final schedule in schedules ?? const <Map<String, dynamic>>[]) {
      if (schedule['costId']?.toString() != costId ||
          schedule['status']?.toString() != 'PENDING' ||
          schedule['id']?.toString() == exceptScheduleId) {
        continue;
      }
      final now = DateTime.now().toIso8601String();
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...schedule,
        'status': 'CANCELLED',
        'paidAt': null,
        'cancelledByPaidInFullAt': paidInFull ? now : null,
        'updatedAt': now,
      }, dirty: true);
    }
  }

  /// RA-BE-25 (backend `restoreSchedulesWhenOwedAgain`): the reminders its
  /// being paid in full cancelled come back once money is owed on it again
  /// (a payment reversed, the total raised), never asking more than what is
  /// now left.
  Future<void> _restoreSchedulesWhenOwedAgain(
    String costId,
    String remaining,
  ) async {
    final left = FinanceMoneyRules.value(remaining);
    if (left <= 0) return;
    final schedules = await _offline?.database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    for (final schedule in schedules ?? const <Map<String, dynamic>>[]) {
      if (schedule['costId']?.toString() != costId ||
          schedule['status']?.toString() != 'CANCELLED' ||
          schedule['cancelledByPaidInFullAt'] == null) {
        continue;
      }
      final amount = FinanceMoneyRules.value(schedule['amount']);
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...schedule,
        'status': 'PENDING',
        'paidAt': null,
        'cancelledByPaidInFullAt': null,
        'amount': FinanceMoneyRules.asMoney(amount > left ? left : amount),
        'updatedAt': DateTime.now().toIso8601String(),
      }, dirty: true);
    }
  }

  /// A reversed reminder payment puts its reminder back to pending.
  Future<void> _restoreScheduleAfterReversal(String? scheduleId) async {
    final id = scheduleId?.trim();
    if (id == null || id.isEmpty) return;
    final cached = await _read(OfflineTables.cachedPaymentSchedules, id);
    if (cached == null) return;
    await _save(OfflineTables.cachedPaymentSchedules, {
      ...cached,
      'status': 'PENDING',
      'paidAt': null,
      'updatedAt': DateTime.now().toIso8601String(),
    }, dirty: true);
  }
}

/// D105, D106, D107 as the server writes them, for the phone's copy.
extension _LocalMoneyWrites on FinanceLocalDataSource {
  /// D106: a reversed partial payment gives its amount back to its date
  /// while the date is still to pay, never above what is left.
  Future<void> _giveBackPartialPayment(
    CostPayment payment,
    String costId,
  ) async {
    final scheduleId = payment.lowersScheduleId;
    if (scheduleId == null) return;
    final cached = await _read(
      OfflineTables.cachedPaymentSchedules,
      scheduleId,
    );
    if (cached == null || cached['status']?.toString() != 'PENDING') return;
    final costNow = await _read(OfflineTables.cachedCosts, costId);
    if (costNow == null) return;
    final left = FinanceMoneyRules.value(costNow['remainingAmount']);
    final restored =
        FinanceMoneyRules.value(cached['amount']) +
        FinanceMoneyRules.value(payment.amount);
    await _save(OfflineTables.cachedPaymentSchedules, {
      ...cached,
      'amount': FinanceMoneyRules.asMoney(restored < left ? restored : left),
      'updatedAt': DateTime.now().toIso8601String(),
    }, dirty: true);
    await _refreshScheduleDues(costId, costNow['remainingAmount'].toString());
  }

  /// D105, D107: what an agreement settles of its item's estimate, as the
  /// server writes it: an expense with no choice is a part at its value.
  Map<String, dynamic> _coverOf(
    Map<String, dynamic> payload, {
    required bool isExpense,
    required num total,
  }) {
    final cover =
        payload['estimateCover']?.toString() ?? (isExpense ? 'PART' : 'WHOLE');
    if (cover != 'PART') {
      return {'estimateCover': 'WHOLE', 'estimatePart': null};
    }
    // No part typed is the agreement's own amount, read when it counts,
    // as on the server (RA-BE-120).
    final part = FinanceMoneyRules.value(payload['estimatePart']);
    return {
      'estimateCover': 'PART',
      'estimatePart': part > 0 ? FinanceMoneyRules.asMoney(part) : null,
    };
  }

  /// D106: a reminder day of its own is between today and the due day (days
  /// in Sana'a, D11).
  void _assertRemindDay(Object? remindAt, Object? dueDate) {
    final remind = _dayOf(remindAt);
    final due = _dayOf(dueDate);
    final today = planDayToJson(sanaaToday());
    if (remind == null ||
        due == null ||
        remind.compareTo(today) < 0 ||
        remind.compareTo(due) > 0) {
      throw const ApiException(
        'يوم التذكير لازم يكون من اليوم لين يوم الموعد.',
      );
    }
  }

  /// The calendar day a stored date falls on in Sana'a, as YYYY-MM-DD.
  String? _dayOf(Object? value) {
    final day = planDayFromJson(
      value is DateTime ? value.toIso8601String() : value,
    );
    return day == null ? null : planDayToJson(day);
  }
}
