import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_request_parts.dart';
import 'package:flutter_test/flutter_test.dart';

MarketplaceBooking _booking(String lifecycle) => MarketplaceBooking.fromJson({
  'id': 'booking-1',
  'quoteRequestId': 'quote-1',
  'providerId': 'provider-1',
  'eventDate': '2026-10-01',
  'status': 'REQUESTED',
  'lifecycleStatus': lifecycle,
});

// RA-MO-263 (batch 7): a booking request whose day passed unanswered read
// «ينتظر تأكيدهم», with a cancel the server refused and no way to ask
// again; the provider was shown «أكّد الحجز», which the server refused too.
// The server now reads it as over (lifecycle EXPIRED) and takes a new one.
void main() {
  test('a request whose day passed unanswered is over, and asked again', () {
    final past = _booking('EXPIRED');
    expect(past.isUnansweredPast, isTrue);
    expect(past.isOpen, isFalse);
    expect(past.canRequestAgain, isTrue);
    expect(bookingStatusLabel(past), 'مرّ يومه وما ردّ المزوّد');
    expect(
      bookingStatusLabel(past, forProvider: true),
      'مرّ يومه وما رديت عليه',
    );

    final waiting = _booking('REQUESTED');
    expect(waiting.isUnansweredPast, isFalse);
    expect(waiting.isOpen, isTrue);
    expect(waiting.canRequestAgain, isFalse);
  });

  test('the provider is not asked to confirm it', () {
    const quote = QuoteRequest(
      id: 'quote-1',
      providerId: 'provider-1',
      status: 'ACCEPTED',
      lifecycleStatus: 'ACCEPTED',
    );
    expect(
      providerCaseOf(quote, _booking('EXPIRED')),
      ProviderCaseState.waitingBooking,
    );
    expect(
      providerCaseOf(quote, _booking('REQUESTED')),
      ProviderCaseState.bookingAsked,
    );
  });
}
