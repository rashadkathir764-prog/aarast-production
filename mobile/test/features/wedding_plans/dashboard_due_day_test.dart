import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// A due day is the Sana'a calendar day the server keeps. Read raw, a
// start-of-Riyadh-day value (21:00 UTC the evening before) fell on the day
// before, so «تستحق اليوم» said yesterday's date and the count was off by one.
void main() {
  test('the next payment is due on the Sana\'a day the server means', () {
    final next = DashboardNextPaymentSchedule.fromJsonOrNull({
      'id': 's-1',
      'weddingCostId': 'c-1',
      'title': 'دفعة القاعة',
      'amount': '500000',
      'status': 'PENDING',
      'dueDate': '2027-01-20T21:00:00.000Z',
    });
    expect(next?.dueDate, DateTime(2027, 1, 21));
  });

  test('a midnight-UTC due day stays that day', () {
    final next = DashboardNextPaymentSchedule.fromJsonOrNull({
      'id': 's-1',
      'dueDate': '2027-01-21T00:00:00.000Z',
    });
    expect(next?.dueDate, DateTime(2027, 1, 21));
  });

  test("an important item's due day reads the same way", () {
    final item = DashboardImportantItem.fromJson({
      'id': 'i-1',
      'dueDate': '2027-01-20T21:00:00.000Z',
    });
    expect(item.dueDate, DateTime(2027, 1, 21));
  });
}
