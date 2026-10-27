import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// The 2026-10-27 owner-vision audit: what the phone reads of the server's
// new fields (G23, G24, G25).

void main() {
  test(
    'G25: a booking says what the provider and the customer may do next',
    () {
      final booking = MarketplaceBooking.fromJson({
        'id': 'b1',
        'quoteRequestId': 'q1',
        'providerId': 'p1',
        'eventDate': '2026-11-08',
        'status': 'CONFIRMED',
        'lifecycleStatus': 'COMPLETED',
        'change': {
          'id': 'c1',
          'fromDate': '2026-11-01',
          'toDate': '2026-11-08',
          'status': 'ACCEPTED',
        },
      });
      final today = DateTime(2026, 11, 10);
      expect(booking.canRecordOutcome(today), isTrue);
      expect(booking.canRecordOutcome(DateTime(2026, 11, 7)), isFalse);
      // Past two days the server completes it by itself (D61).
      expect(booking.canRecordOutcome(DateTime(2026, 11, 11)), isFalse);
      expect(booking.canRecordOutcome(DateTime(2026, 11, 16)), isFalse);
      expect(booking.canDeliver, isFalse);
      expect(booking.change?.status, 'ACCEPTED');
      expect(booking.canAskChange(today), isFalse);

      final done = MarketplaceBooking.fromJson({
        'id': 'b2',
        'quoteRequestId': 'q2',
        'providerId': 'p1',
        'eventDate': '2026-12-01',
        'status': 'CONFIRMED',
        'completedAt': '2026-12-02T09:00:00.000Z',
        'deliveredAt': '2026-12-20T09:00:00.000Z',
        'deliveryLink': 'https://example.com/album',
      });
      expect(done.canRecordOutcome(DateTime(2026, 12, 3)), isFalse);
      expect(done.canDeliver, isFalse);
      expect(done.canConfirmDelivery, isTrue);
      expect(done.deliveryLink, 'https://example.com/album');

      final upcoming = MarketplaceBooking.fromJson({
        'id': 'b3',
        'quoteRequestId': 'q3',
        'providerId': 'p1',
        'eventDate': '2026-12-20',
        'status': 'CONFIRMED',
        'change': {
          'id': 'c3',
          'fromDate': '2026-12-20',
          'toDate': '2026-12-27',
          'status': 'PENDING',
        },
      });
      expect(upcoming.canAskChange(today), isFalse);
      expect(upcoming.change?.isPending, isTrue);
    },
  );

  test('G24: an offer reads its lines, delivery days and rejection reason', () {
    final offer = QuoteOffer.fromJson({
      'id': 'o1',
      'status': 'REJECTED',
      'lines': [
        {'label': 'ألبوم', 'kind': 'INCLUDED'},
        {'label': 'درون', 'kind': 'EXTRA', 'amount': '80000'},
        {'label': '', 'kind': 'INCLUDED'},
      ],
      'deliveryDays': 30,
      'rejectReason': 'PRICE',
    });
    expect(offer.lines, hasLength(2));
    expect(offer.lines.last.isExtra, isTrue);
    expect(offer.lines.last.toJson(), {
      'label': 'درون',
      'kind': 'EXTRA',
      'amount': '80000',
    });
    expect(offer.lines.first.toJson().containsKey('amount'), isFalse);
    expect(offer.deliveryDays, 30);
    expect(offer.rejectReason, 'PRICE');
  });

  test('G23: the essentials read their state', () {
    final essential = DashboardEssential.fromJson({
      'key': 'GOLD',
      'status': 'MISSING',
      'budgetCategoryId': 'cat-1',
    });
    expect(essential.status, DashboardEssentialStatus.missing);
    expect(essential.isSettled, isFalse);
    expect(
      DashboardEssential.fromJson({
        'key': 'VENUE',
        'status': 'BOOKED',
      }).isSettled,
      isTrue,
    );
    expect(
      DashboardEssential.fromJson({'key': 'X', 'status': 'WHAT'}).status,
      DashboardEssentialStatus.none,
    );
  });
}
