import '../models/wedding_cost.dart';
import 'finance_money_rules.dart';

Map<String, num> localNetPaidByCost(Iterable<Map<String, dynamic>> payments) {
  final paidByCost = <String, num>{};
  for (final payment in payments) {
    final costId = payment['costId']?.toString();
    if (costId == null) continue;
    final amount = FinanceMoneyRules.value(payment['amount']);
    final signed = payment['entryType']?.toString() == 'REVERSAL'
        ? -amount
        : amount;
    paidByCost[costId] = (paidByCost[costId] ?? 0) + signed;
  }
  return paidByCost;
}

class LocalPaymentScheduleSummary {
  const LocalPaymentScheduleSummary({
    required this.pending,
    required this.upcomingCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.paidCount,
  });

  factory LocalPaymentScheduleSummary.from(
    List<Map<String, dynamic>> schedules,
    DateTime today,
  ) {
    final pending =
        schedules
            .where((schedule) => schedule['status']?.toString() == 'PENDING')
            .toList()
          ..sort(
            (a, b) => (dateTimeOrNull(a['dueDate']) ?? DateTime(9999))
                .compareTo(dateTimeOrNull(b['dueDate']) ?? DateTime(9999)),
          );
    final overdueCount = pending.where((schedule) {
      final dueDate = dateTimeOrNull(schedule['dueDate']);
      return dueDate != null && dueDate.isBefore(today);
    }).length;
    final upcoming = pending.where((schedule) {
      final dueDate = dateTimeOrNull(schedule['dueDate']);
      return dueDate != null && !dueDate.isBefore(today);
    }).toList();
    final dueSoonEnd = today.add(const Duration(days: 7));
    final dueSoonCount = upcoming.where((schedule) {
      final dueDate = dateTimeOrNull(schedule['dueDate']);
      return dueDate != null && !dueDate.isAfter(dueSoonEnd);
    }).length;
    return LocalPaymentScheduleSummary(
      pending: pending,
      upcomingCount: upcoming.length,
      overdueCount: overdueCount,
      dueSoonCount: dueSoonCount,
      paidCount: schedules
          .where((schedule) => schedule['status']?.toString() == 'PAID')
          .length,
    );
  }

  final List<Map<String, dynamic>> pending;
  final int upcomingCount;
  final int overdueCount;
  final int dueSoonCount;
  final int paidCount;
}
