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

  /// R4: an agreement paid in full cancels its pending reminders.
  Future<void> _cancelPendingSchedules(
    String costId, {
    String? exceptScheduleId,
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
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...schedule,
        'status': 'CANCELLED',
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
