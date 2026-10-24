import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_booking_sheets.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_first_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Bookings without payment (V1 checklist 4.6): the booking model, the
// provider's decisions and calendar, and the setup checklist that leads a new
// provider to the first service customers need to see them (Q14).

Map<String, dynamic> _bookingJson({
  String status = 'REQUESTED',
  String? lifecycleStatus,
  String? cancelledBy,
}) => {
  'id': 'booking-1',
  'quoteRequestId': 'quote-1',
  'providerId': 'provider-1',
  'eventDate': '2027-02-18',
  'status': status,
  'lifecycleStatus': lifecycleStatus ?? status,
  'cancelledBy': cancelledBy,
  'customerName': 'عريس تجربة',
  'guestCount': 200,
};

void main() {
  test('a quote carries its booking and a booking reads in both voices', () {
    final quote = QuoteRequest.fromJson({
      'id': 'quote-1',
      'providerId': 'provider-1',
      'status': 'ACCEPTED',
      'booking': _bookingJson(),
    });
    final booking = quote.booking!;
    expect(booking.eventDate, DateTime(2027, 2, 18));
    expect(booking.isRequested, isTrue);
    expect(booking.isOpen, isTrue);
    expect(bookingStatusLabel(booking), 'بانتظار تأكيد المزوّد');
    expect(bookingStatusLabel(booking, forProvider: true), 'طلب حجز بانتظار ردّك');

    final completed = MarketplaceBooking.fromJson(
      _bookingJson(status: 'CONFIRMED', lifecycleStatus: 'COMPLETED'),
    );
    expect(bookingStatusLabel(completed), 'تمّ');

    final cancelledByProvider = MarketplaceBooking.fromJson(
      _bookingJson(status: 'CANCELLED', cancelledBy: 'PROVIDER'),
    );
    expect(cancelledByProvider.canRequestAgain, isTrue);
    expect(bookingStatusLabel(cancelledByProvider), 'ألغاه المزوّد');
    expect(MarketplaceBooking.dayParam(DateTime(2027, 3, 1)), '2027-03-01');
    expect(
      QuoteRequest.fromJson({'id': 'q', 'providerId': 'p', 'status': 'SENT'})
          .booking,
      isNull,
    );
  });

  test('booking errors read as Arabic actions', () {
    expect(
      bookingErrorMessage('BOOKING_DATE_UNAVAILABLE'),
      'المزوّد غير متاح في هذا اليوم. اختر يومًا آخر.',
    );
    expect(bookingErrorMessage('SOMETHING_ELSE'), isNull);
  });

  test('the provider confirms a request and the dashboard reloads', () async {
    final api = _BookingsApiFake();
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();
    expect(dashboard.bookings.single.isRequested, isTrue);
    expect(dashboard.errorMessage, isNull);

    expect(
      await dashboard.decideBooking(bookingId: 'booking-1', action: 'confirm'),
      isTrue,
    );
    expect(api.decisions, ['booking-1:confirm']);
    expect(dashboard.bookings.single.isConfirmed, isTrue);
  });

  test('an unavailable day is refused with its reason', () async {
    final api = _BookingsApiFake()..failCode = 'BOOKING_DATE_UNAVAILABLE';
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    expect(
      await dashboard.decideBooking(bookingId: 'booking-1', action: 'confirm'),
      isFalse,
    );
    expect(
      dashboard.errorMessage,
      'المزوّد غير متاح في هذا اليوم. اختر يومًا آخر.',
    );
  });

  test('the provider closes and reopens a day on the calendar', () async {
    final api = _BookingsApiFake();
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    expect(await dashboard.blockDate(DateTime(2027, 3, 1)), isTrue);
    expect(dashboard.blockedDates, [DateTime(2027, 3, 1)]);
    expect(await dashboard.unblockDate(DateTime(2027, 3, 1)), isTrue);
    expect(dashboard.blockedDates, isEmpty);
  });

  testWidgets('a request opens p21 with confirm and decline; confirming '
      'calls the API', (tester) async {
    final api = _BookingsApiFake();
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderDashboardProvider>.value(
        value: dashboard,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showProviderConfirmSheet(
                    context,
                    quote: null,
                    booking: dashboard.bookings.single,
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(find.text('ما أقدر، اعتذر'), findsOneWidget);
    await tester.tap(find.byKey(const Key('provider-booking-confirm-booking-1')));
    await tester.pumpAndSettle();
    expect(api.decisions, ['booking-1:confirm']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a provider without a service is told customers cannot see them', (
    tester,
  ) async {
    final api = _BookingsApiFake()..services = const [];
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    // p14 replaced the setup checklist (D40).
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProviderFirstSteps(
              dashboard: dashboard,
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('أضف خدمة بسعرها'), findsOneWidget);
    expect(find.text('ملفك ما يظهر في الدليل قبل أول خدمة'), findsOneWidget);
  });
}

class _BookingsApiFake extends ProviderDashboardApi {
  _BookingsApiFake() : super(ApiClient(tokenProvider: () async => null));

  String bookingStatus = 'REQUESTED';
  String? failCode;
  final decisions = <String>[];
  final blocked = <DateTime>[];
  List<MarketplaceService> services = const [
    MarketplaceService(
      id: 'service-1',
      providerId: 'provider-1',
      title: 'زفة كاملة',
      isFeatured: false,
      isActive: true,
    ),
  ];

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'الفنان علي',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      const ProviderDashboardSummary(
        servicesCount: 1,
        activeServicesCount: 1,
        quoteRequestsCount: 1,
        newQuoteRequestsCount: 0,
        averageRating: 0,
        ratingCount: 0,
      );

  @override
  Future<List<MarketplaceService>> getServices() async => services;

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async => [
    MarketplaceBooking.fromJson(_bookingJson(status: bookingStatus)),
  ];

  @override
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    final code = failCode;
    if (code != null) {
      throw ApiException('conflict', statusCode: 409, serverCode: code);
    }
    decisions.add('$bookingId:$action');
    bookingStatus = action == 'confirm' ? 'CONFIRMED' : 'DECLINED';
    return MarketplaceBooking.fromJson(_bookingJson(status: bookingStatus));
  }

  @override
  Future<List<DateTime>> getBlockedDates() async => List.of(blocked);

  @override
  Future<void> blockDate(DateTime day) async => blocked.add(day);

  @override
  Future<void> unblockDate(DateTime day) async => blocked.remove(day);
}
