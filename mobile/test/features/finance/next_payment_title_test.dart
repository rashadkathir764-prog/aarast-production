import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-38: «الدفعة الجاية» on the money tab named its agreement «دفعة»: the
// summary's next payment carried no title. The server sends the agreement's
// title with it now, and the card reads it.
void main() {
  test('the next payment names its agreement', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'paymentSchedules': {
        'totalCount': 1,
        'upcomingCount': 1,
        'overdueCount': 0,
        'paidCount': 0,
        'next': {
          'id': 'schedule-1',
          'weddingCostId': 'cost-1',
          'costTitle': 'القاعة',
          'amount': '200000',
          'dueDate': '2026-12-01T00:00:00.000Z',
          'status': 'PENDING',
        },
      },
    });

    expect(summary.paymentSchedules.next?.costId, 'cost-1');
    expect(summary.paymentSchedules.next?.costTitle, 'القاعة');
  });
}
