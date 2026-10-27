import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/data/provider_offer_queue.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_requests_test.dart'
    show RequestsApi, bookingJson, offerJson, quoteJson;

// Provider slice 3 (D39): p43 without the network. What was read stays
// with its time, a new offer waits on the phone and goes once the network
// is back (a second create is refused by the server, F6), and confirming a
// booking says it needs the network.

class OfflineApi extends RequestsApi {
  OfflineApi({super.quotes, super.bookings});

  bool offline = false;
  bool alreadyExists = false;

  /// What the server answers for the requests from now on, when set.
  List<Map<String, dynamic>>? replaced;

  static const _noNetwork = ApiException('بدون نت', isNetworkFailure: true);

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async {
    final answer = replaced;
    if (answer == null) return super.getQuoteRequests();
    return [for (final quote in answer) QuoteRequest.fromJson(quote)];
  }

  @override
  Future<ProviderDashboardProfile> getProfile() {
    if (offline) throw _noNetwork;
    return super.getProfile();
  }

  @override
  Future<QuoteOffer> createQuoteOffer({
    required String quoteRequestId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) {
    if (offline) throw _noNetwork;
    if (alreadyExists) {
      throw const ApiException(
        'x',
        statusCode: 409,
        serverCode: 'QUOTE_OFFER_ALREADY_EXISTS',
      );
    }
    return super.createQuoteOffer(
      quoteRequestId: quoteRequestId,
      message: message,
      amount: amount,
      currency: currency,
      title: title,
      validUntil: validUntil,
    );
  }
}

OfflineApi _api() {
  final asked = bookingJson(id: 'booking-2', quoteId: 'quote-2');
  return OfflineApi(
    quotes: [
      quoteJson(name: 'عادل الريمي'),
      quoteJson(
        id: 'quote-2',
        status: 'ACCEPTED',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: asked,
      ),
    ],
    bookings: [asked],
  );
}

Future<ProviderOfferSend> _offerOffline(
  ProviderDashboardProvider dashboard,
  OfflineApi api,
) {
  api.offline = true;
  return dashboard.createQuoteOffer(
    quoteRequestId: 'quote-1',
    message: 'تصوير ليلة كاملة',
    amount: '550000',
    currency: 'YER',
    title: 'صور وفيديو',
  );
}

Future<void> _pumpTab(
  WidgetTester tester,
  ProviderDashboardProvider dashboard,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<ProviderDashboardProvider>.value(
      value: dashboard,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderRequestsTab(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

late SharedPreferences _preferences;

Future<ProviderOfferQueue> _queue() async => ProviderOfferQueue(_preferences);

/// Unmounts the tab and stops the dashboard's retry.
Future<void> _done(
  WidgetTester tester,
  ProviderDashboardProvider dashboard,
) async {
  await tester.pumpWidget(const SizedBox());
  dashboard.dispose();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  testWidgets('without the network the lists stay, with the time they were '
      'read, and confirming waits for the network', (tester) async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await tester.runAsync(dashboard.loadDashboard);
    api.offline = true;
    await tester.runAsync(dashboard.loadDashboard);
    expect(dashboard.isOffline, isTrue);

    await _pumpTab(tester, dashboard);
    expect(find.byKey(const Key('provider-offline-bar')), findsOne);
    expect(
      find.text(
        'بدون نت. العرض اللي ترسله ينحفظ في جوالك ويوصل لما يرجع النت.',
      ),
      findsOne,
    );
    expect(find.text('تأكيد الحجز يحتاج نت'), findsOne);
    expect(find.text('آخر تحديث قبل لحظات'), findsOne);
    // The lists read before are still there.
    expect(find.text('عادل الريمي'), findsOne);
    await _done(tester, dashboard);
  });

  testWidgets('an offer sent without the network waits on the phone', (
    tester,
  ) async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await tester.runAsync(dashboard.loadDashboard);
    final result = (await tester.runAsync(
      () => _offerOffline(dashboard, api),
    ))!;
    expect(result, ProviderOfferSend.queued);
    expect(dashboard.queuedOfferFor('quote-1'), isNotNull);
    expect(api.created, isEmpty);

    await _pumpTab(tester, dashboard);
    expect(find.text('عرضك لعادل ينتظر النت'), findsOne);
    expect(find.text('محفوظ على جوالك، وينرسل أول ما يرجع النت'), findsOne);

    // It is kept on the phone, not only in memory.
    expect(
      _preferences.getString('aarast_provider_offer_queue:provider-1'),
      contains('quote-1'),
    );
    await _done(tester, dashboard);
  });

  test('the waiting offer goes once the network is back, once', () async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await dashboard.loadDashboard();
    await _offerOffline(dashboard, api);

    api.offline = false;
    await dashboard.loadDashboard();
    expect(api.created.single.message, 'تصوير ليلة كاملة');
    expect(dashboard.queuedOffers, isEmpty);
    expect(dashboard.isOffline, isFalse);
    expect(
      dashboard.quoteRequests.firstWhere((q) => q.id == 'quote-1').status,
      'RESPONDED',
    );
    // A later read sends nothing again.
    await dashboard.loadDashboard();
    expect(api.created, hasLength(1));
    dashboard.dispose();
  });

  test('an offer the server already holds counts as sent', () async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await dashboard.loadDashboard();
    await _offerOffline(dashboard, api);

    api
      ..offline = false
      ..alreadyExists = true;
    await dashboard.loadDashboard();
    expect(dashboard.queuedOffers, isEmpty);
    expect(dashboard.errorMessage, isNull);
    dashboard.dispose();
  });

  test('a request no longer waiting drops its offer unsent', () async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await dashboard.loadDashboard();
    await _offerOffline(dashboard, api);

    // He answered from another phone meanwhile.
    await api.updateQuoteRequestStatus(
      quoteRequestId: 'quote-1',
      status: 'CANCELLED',
    );
    api.offline = false;
    await dashboard.loadDashboard();
    expect(api.created, isEmpty);
    expect(dashboard.queuedOffers, isEmpty);
    dashboard.dispose();
  });

  test('after he withdrew his offer, the offer kept offline goes', () async {
    final api = OfflineApi(
      quotes: [
        quoteJson(
          name: 'عادل الريمي',
          status: 'VIEWED',
          offers: [offerJson(status: 'WITHDRAWN')],
        ),
      ],
    );
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await dashboard.loadDashboard();
    await _offerOffline(dashboard, api);

    api.offline = false;
    await dashboard.loadDashboard();
    expect(api.created.single.message, 'تصوير ليلة كاملة');
    expect(dashboard.queuedOffers, isEmpty);
    expect(dashboard.droppedOffers, isEmpty);
    dashboard.dispose();
  });

  testWidgets('an offer that cannot go is said, with why, until he closes it', (
    tester,
  ) async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await tester.runAsync(dashboard.loadDashboard);
    await tester.runAsync(() => _offerOffline(dashboard, api));
    await tester.runAsync(
      () => api.updateQuoteRequestStatus(
        quoteRequestId: 'quote-1',
        status: 'CANCELLED',
      ),
    );
    api.offline = false;
    await tester.runAsync(dashboard.loadDashboard);
    expect(api.created, isEmpty);
    expect(dashboard.queuedOffers, isEmpty);
    expect(
      dashboard.droppedOffers.single.reason,
      ProviderOfferDropReason.cancelled,
    );

    await _pumpTab(tester, dashboard);
    expect(
      find.text('ما أرسلنا عرضك المحفوظ لعادل: ألغى الطلب'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('provider-dropped-offers-dismiss')),
    );
    await tester.pump();
    expect(find.byKey(const Key('provider-dropped-offers')), findsNothing);
    await _done(tester, dashboard);
  });

  test('a request whose seven days ended keeps its offer, and says so', () async {
    final api = _api();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    await dashboard.loadDashboard();
    await _offerOffline(dashboard, api);

    // The network comes back after the request's deadline.
    api
      ..offline = false
      ..replaced = [
        quoteJson(
          name: 'عادل الريمي',
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
      ];
    await dashboard.loadDashboard();
    expect(api.created, isEmpty);
    expect(
      dashboard.droppedOffers.single.reason,
      ProviderOfferDropReason.expired,
    );
    expect(
      dashboard.quoteRequests.single.status,
      'EXPIRED',
      reason: 'the server takes no answer past the deadline',
    );
    dashboard.dispose();
  });

  test(
    'with no place on the phone, an offline offer fails and says so',
    () async {
      final api = _api();
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadDashboard();
      expect(await _offerOffline(dashboard, api), ProviderOfferSend.failed);
      expect(dashboard.errorMessage, isNotNull);
      expect(dashboard.queuedOffers, isEmpty);
      dashboard.dispose();
    },
  );

  test('a booking change without the network is said, not kept', () async {
    final api = _BookingOfflineApi();
    final dashboard = ProviderDashboardProvider(
      api,
      offerQueue: await _queue(),
    );
    expect(
      await dashboard.decideBooking(bookingId: 'booking-2', action: 'confirm'),
      isFalse,
    );
    expect(dashboard.lastChangeOffline, isTrue);
    dashboard.dispose();
  });
}

class _BookingOfflineApi extends RequestsApi {
  @override
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) async => throw const ApiException('بدون نت', isNetworkFailure: true);
}
