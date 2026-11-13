import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-297 (batch 9): the server's refusals were said to the provider in
// the customer's words or in the wrong ones, and a refused step after a
// lost answer left the page as the phone held it.
void main() {
  test('a booking refusal is said to the provider, not the customer', () {
    expect(
      providerBookingErrorMessage('BOOKING_DAY_FULL'),
      'يومك هذا مليان بحجوزات مؤكدة على قد طاقتك.',
    );
    for (final code in [
      'BOOKING_DATE_UNAVAILABLE',
      'BOOKING_DAY_FULL',
      'BOOKING_DATE_IN_PAST',
      'BOOKING_NOT_ALLOWED',
    ]) {
      expect(providerBookingErrorMessage(code), isNot(contains('اختر')));
      expect(providerBookingErrorMessage(code), isNot(contains('المزوّد')));
    }
  });

  test('«not active» is not «suspended» to one waiting for approval', () async {
    final api = _Api()..refuseCreate = 'PROVIDER_NOT_ACTIVE';
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    expect(
      await dashboard.createService(title: 'زفة', categoryId: 'photo'),
      isFalse,
    );
    expect(dashboard.errorMessage, 'هذا يصير لما يكون ملفك نشط.');
  });

  test('a reply that went before its answer was lost is the reply', () async {
    final api = _Api()..replyAlreadyThere = true;
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    expect(await dashboard.replyToReview('review-1', 'شكرًا لكم'), isTrue);
    expect(dashboard.reviews.single.reply?.body, 'شكرًا لكم');
  });

  test(
    'a refused booking step reads the booking again, and says why',
    () async {
      final api = _Api()..refuseDecision = 'BOOKING_NOT_ALLOWED';
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadDashboard();
      final readsBefore = api.bookingReads;

      expect(
        await dashboard.decideBooking(bookingId: 'b1', action: 'confirm'),
        isFalse,
      );
      expect(api.bookingReads, readsBefore + 1);
      expect(dashboard.errorMessage, 'الحجز تغيّر. هذا حاله الحين.');
    },
  );

  test('a booking step with no network reads nothing more', () async {
    final api = _Api()..decisionOffline = true;
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();
    final readsBefore = api.bookingReads;

    expect(
      await dashboard.decideBooking(bookingId: 'b1', action: 'confirm'),
      isFalse,
    );
    expect(api.bookingReads, readsBefore);
  });
}

class _Api extends ProviderDashboardApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  String? refuseCreate;
  String? refuseDecision;
  bool decisionOffline = false;
  bool replyAlreadyThere = false;
  int bookingReads = 0;

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استديو الفن',
        status: 'ACTIVE',
        ratingAverage: 5,
        ratingCount: 1,
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.empty();

  @override
  Future<List<MarketplaceService>> getServices() async => const [];

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => [
    ProviderReview(
      id: 'review-1',
      rating: 5,
      reply: replyAlreadyThere
          ? const ProviderReviewReply(body: 'شكرًا لكم')
          : null,
    ),
  ];

  @override
  Future<List<MarketplaceBooking>> getBookings() async {
    bookingReads++;
    return const [];
  }

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];

  @override
  Future<MarketplaceService> createService({
    required String title,
    required String categoryId,
    required String clientRequestId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    throw ApiException(
      'المزود موقوف الحين، ما يستقبل رسائل ولا طلبات.',
      statusCode: 403,
      serverCode: refuseCreate,
    );
  }

  @override
  Future<ProviderReview> replyToReview({
    required String reviewId,
    required String body,
  }) async {
    throw const ApiException(
      'already replied',
      statusCode: 409,
      serverCode: 'REVIEW_ALREADY_REPLIED',
    );
  }

  @override
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    if (decisionOffline) {
      throw const ApiException('offline', isNetworkFailure: true);
    }
    throw ApiException(
      'not allowed',
      statusCode: 409,
      serverCode: refuseDecision,
    );
  }
}
