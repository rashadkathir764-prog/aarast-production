import 'package:aarast_mobile/features/wedding_plans/data/plan_bookings_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.13: when the wedding moves, the bookings made for the old
// day are named.

void main() {
  test('a booking reads its provider, day and whether it is confirmed', () {
    final confirmed = PlanBookingDay.fromJson({
      'providerName': 'قاعة الماسة',
      'eventDate': '2027-04-10',
      'status': 'CONFIRMED',
    });
    expect(confirmed.providerName, 'قاعة الماسة');
    expect(confirmed.confirmed, isTrue);
    final requested = PlanBookingDay.fromJson({
      'eventDate': '2027-04-10',
      'status': 'REQUESTED',
    });
    expect(requested.providerName, 'مزوّد');
    expect(requested.confirmed, isFalse);
  });

  test(
    'only the bookings of the old wedding day are picked, by calendar day',
    () {
      final bookings = [
        PlanBookingDay.fromJson({
          'providerName': 'القاعة',
          'eventDate': '2027-04-10',
        }),
        PlanBookingDay.fromJson({
          'providerName': 'الحناء',
          'eventDate': '2027-04-09',
        }),
        PlanBookingDay.fromJson({
          'providerName': 'المصور',
          'eventDate': '2027-04-10',
        }),
      ];
      // The plan's wedding date arrives from the server as UTC midnight.
      final oldDay = DateTime.parse('2027-04-10T00:00:00.000Z');
      expect(
        bookingsOnDay(bookings, oldDay).map((booking) => booking.providerName),
        ['القاعة', 'المصور'],
      );
      expect(bookingsOnDay(bookings, DateTime(2027, 5, 1)), isEmpty);
    },
  );
}
