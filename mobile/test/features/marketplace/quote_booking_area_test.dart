import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/widgets/quote_booking_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The customer's side of a booking (V1 checklist 4.6) and the review that
// opens once the booked day has passed (3.1).

QuoteRequest _quote({Map<String, dynamic>? booking}) => QuoteRequest.fromJson({
  'id': 'quote-1',
  'providerId': 'provider-1',
  'status': 'ACCEPTED',
  'lifecycleStatus': 'ACCEPTED',
  'eventDate': '2027-02-18T00:00:00.000Z',
  'provider': {'id': 'provider-1', 'businessName': 'الفنان علي'},
  'booking': ?booking,
});

Map<String, dynamic> _booking(String status, {String? lifecycle}) => {
  'id': 'booking-1',
  'quoteRequestId': 'quote-1',
  'providerId': 'provider-1',
  'eventDate': '2027-02-18',
  'status': status,
  'lifecycleStatus': lifecycle ?? status,
};

Future<_MarketplaceApiFake> _pump(WidgetTester tester, QuoteRequest quote) async {
  final api = _MarketplaceApiFake();
  await tester.pumpWidget(
    ChangeNotifierProvider<ProviderMarketplaceProvider>(
      create: (_) => ProviderMarketplaceProvider(api),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: QuoteBookingArea(quote: quote, isSubmitting: false),
          ),
        ),
      ),
    ),
  );
  return api;
}

void main() {
  testWidgets('an accepted quote asks for its own wedding day', (tester) async {
    final api = await _pump(tester, _quote());

    final request = find.byKey(const Key('quote-booking-request-quote-1'));
    expect(request, findsOneWidget);
    expect(find.text('يوم آخر'), findsOneWidget);
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(api.bookingRequests, [null]);
    expect(find.textContaining('أرسلنا طلب الحجز'), findsOneWidget);
  });

  testWidgets('a pending request can be cancelled, a confirmed day shows booked', (
    tester,
  ) async {
    await _pump(tester, _quote(booking: _booking('REQUESTED')));
    expect(find.text('بانتظار تأكيد المزوّد'), findsOneWidget);
    expect(find.text('إلغاء الطلب'), findsOneWidget);

    await _pump(tester, _quote(booking: _booking('CONFIRMED')));
    expect(find.text('محجوز'), findsOneWidget);
    expect(find.text('إلغاء الحجز'), findsOneWidget);
  });

  testWidgets('after the day the customer rates the provider', (tester) async {
    final api = await _pump(
      tester,
      _quote(booking: _booking('CONFIRMED', lifecycle: 'COMPLETED')),
    );

    await tester.tap(find.byKey(const Key('quote-booking-review-quote-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('الفنان علي'), findsOneWidget);

    final submit = find.byKey(const Key('review-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.byKey(const Key('review-star-5')));
    await tester.enterText(find.byKey(const Key('review-comment')), 'ممتاز');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(api.reviews, ['provider-1:5:ممتاز']);
    expect(find.byKey(const Key('review-submit')), findsNothing);
  });
}

class _MarketplaceApiFake extends MarketplaceApi {
  _MarketplaceApiFake() : super(ApiClient(tokenProvider: () async => null));

  final bookingRequests = <DateTime?>[];
  final reviews = <String>[];

  @override
  Future<QuoteRequest> requestBooking({
    required String quoteRequestId,
    DateTime? eventDate,
  }) async {
    bookingRequests.add(eventDate);
    return _quote(booking: _booking('REQUESTED'));
  }

  @override
  Future<void> createProviderReview({
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    reviews.add('$providerId:$rating:${comment ?? ''}');
  }
}
