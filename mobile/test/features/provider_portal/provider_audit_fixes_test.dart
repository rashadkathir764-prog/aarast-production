import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_offer_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_tabs.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_request_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_booking_screen.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_request_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_requests_test.dart' as requests;

// The provider portal's audit fixes (D35): the provider declines a request
// and marks it seen, gives his offer an end date and renews an expired one,
// gives a reason with a booking decision, sees which reviews are public,
// and in a closed state reads what is true and can reach support.

Map<String, dynamic> _quoteJson({
  String id = 'quote-1',
  String status = 'SENT',
  List<Map<String, dynamic>> offers = const [],
}) => {
  'id': id,
  'providerId': 'provider-1',
  'status': status,
  'contactName': 'أحمد العريس',
  'service': {
    'id': 'service-1',
    'providerId': 'provider-1',
    'title': 'تصوير زفاف',
  },
  'weddingPlan': {'id': 'plan-1', 'title': 'عرس أحمد', 'currency': 'YER'},
  'offers': offers,
};

Map<String, dynamic> _offerJson({required DateTime validUntil}) => {
  'id': 'offer-1',
  'status': 'PENDING',
  'title': 'صور وفيديو',
  'message': 'تصوير ليلة كاملة',
  'amount': '550000',
  'currency': 'YER',
  'validUntil': validUntil.toUtc().toIso8601String(),
};

void main() {
  // Slice 2 (D37) moved these steps onto the request (p16, p19), the
  // apology sheet (p18) and the offer page (p17); the behaviour is D35's.
  group('requests', () {
    testWidgets('a new request is declined after a confirmation', (
      tester,
    ) async {
      final api = _PortalApi(quotes: [_quoteJson()], hasBooking: false);
      await _pumpRequests(tester, api);
      await _openRequest(tester);

      await tester.tap(find.byKey(const Key('provider-quote-decline-quote-1')));
      await tester.pumpAndSettle();
      expect(find.text('تعتذر من أحمد؟'), findsOneWidget);
      expect(api.statusUpdates, ['quote-1:VIEWED']);

      await tester.tap(find.byKey(const Key('provider-decline-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-quote-decline-confirm')));
      await tester.pumpAndSettle();

      expect(api.statusUpdates, ['quote-1:VIEWED', 'quote-1:REJECTED']);
      expect(
        find.byKey(const Key('provider-quote-decline-quote-1')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a request with an offer cannot be declined', (tester) async {
      final api = _PortalApi(
        hasBooking: false,
        quotes: [
          _quoteJson(
            status: 'RESPONDED',
            offers: [
              _offerJson(
                validUntil: DateTime.now().add(const Duration(days: 5)),
              ),
            ],
          ),
        ],
      );
      await _pumpRequests(tester, api);
      await tester.tap(find.byKey(const Key('provider-requests-tab-replied')));
      await tester.pumpAndSettle();
      await _openRequest(tester);

      expect(
        find.byKey(const Key('provider-quote-decline-quote-1')),
        findsNothing,
      );
      expect(find.text('عدّل العرض'), findsOneWidget);
    });

    testWidgets('opening a new request tells the customer it was seen, once', (
      tester,
    ) async {
      final api = _PortalApi(quotes: [_quoteJson()], hasBooking: false);
      await _pumpRequests(tester, api);

      await _openRequest(tester);
      await tester.tap(find.byKey(const Key('provider-request-ask')));
      await tester.pumpAndSettle();
      expect(find.text('محادثة الطلب quote-1'), findsOneWidget);
      expect(api.statusUpdates, ['quote-1:VIEWED']);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      await _openRequest(tester);
      expect(api.statusUpdates, ['quote-1:VIEWED']);
    });

    testWidgets(
      'a new offer is open ten days unless another length is picked',
      (tester) async {
        final api = _PortalApi(quotes: [_quoteJson()], hasBooking: false);
        await _pumpRequests(tester, api);
        await _openRequest(tester);

        await tester.tap(find.byKey(const Key('provider-request-offer')));
        await tester.pumpAndSettle();
        expect(find.text('صالح لـ'), findsOneWidget);
        expect(find.text('7 أيام'), findsOneWidget);
        expect(find.text('10 أيام'), findsOneWidget);
        expect(find.text('14 يوم'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('provider-offer-amount')),
          '550000',
        );
        await tester.enterText(
          find.byKey(const Key('provider-offer-message')),
          'تصوير ليلة كاملة',
        );
        final before = DateTime.now();
        await _sendOffer(tester);

        expect(api.createdOffers, hasLength(1));
        _expectDaysAhead(api.createdOffers.single, before, 10);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('an expired offer is renewed with a new end date', (
      tester,
    ) async {
      final api = _PortalApi(
        hasBooking: false,
        quotes: [
          _quoteJson(
            status: 'RESPONDED',
            offers: [
              _offerJson(
                validUntil: DateTime.now().subtract(const Duration(days: 1)),
              ),
            ],
          ),
        ],
      );
      await _pumpRequests(tester, api);
      await tester.tap(find.byKey(const Key('provider-requests-tab-ended')));
      await tester.pumpAndSettle();
      await _openRequest(tester);

      expect(find.text('جدّد العرض'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-offer-open-quote-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('provider-offer-validity-keep')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('provider-offer-validity-14')));
      await tester.pumpAndSettle();

      final before = DateTime.now();
      await _sendOffer(tester);

      expect(api.updatedOfferIds, ['offer-1']);
      // RA-MO-289: the edit names the version it was made from.
      expect(api.updatedOfferVersions, [1]);
      _expectDaysAhead(api.updatedOffers.single, before, 14);
      expect(api.createdOffers, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('editing an open offer keeps its end date by default', (
      tester,
    ) async {
      final ends = DateTime.now().add(const Duration(days: 4));
      final api = _PortalApi(
        hasBooking: false,
        quotes: [
          _quoteJson(
            status: 'RESPONDED',
            offers: [_offerJson(validUntil: ends)],
          ),
        ],
      );
      await _pumpRequests(tester, api);
      await tester.tap(find.byKey(const Key('provider-requests-tab-replied')));
      await tester.pumpAndSettle();
      await _openRequest(tester);

      await tester.tap(find.byKey(const Key('provider-offer-open-quote-1')));
      await tester.pumpAndSettle();
      await _sendOffer(tester);

      expect(
        api.updatedOffers.single!.difference(ends).inSeconds.abs(),
        lessThan(1),
      );
      await tester.pump(const Duration(seconds: 5));
    });

    test('the offer end date reaches the server as an instant', () async {
      final client = _RecordingClient();
      await ProviderDashboardApi(client).createQuoteOffer(
        quoteRequestId: 'quote-1',
        message: 'عرض',
        amount: '100',
        currency: 'YER',
        validUntil: DateTime.utc(2026, 11, 3, 9),
      );
      expect(client.lastBody?['validUntil'], '2026-11-03T09:00:00.000Z');
    });

    // RA-MO-289 (batch 9): a title taken off and «بدون» for the delivery
    // were left out of the request, so the server kept the old ones.
    test(
      'an offer edit says what was taken off: no title, no delivery',
      () async {
        final client = _RecordingClient();
        await ProviderDashboardApi(client).updateQuoteOffer(
          quoteOfferId: 'offer-1',
          message: 'عرض',
          amount: '100',
          currency: 'YER',
        );
        expect(client.lastBody!.containsKey('title'), isTrue);
        expect(client.lastBody!['title'], isNull);
        expect(client.lastBody!.containsKey('deliveryDays'), isTrue);
        expect(client.lastBody!['deliveryDays'], isNull);
        // RA-MO-289: no version known, none sent (an older offer).
        expect(client.lastBody!.containsKey('baseVersionNo'), isFalse);

        await ProviderDashboardApi(client).updateQuoteOffer(
          quoteOfferId: 'offer-1',
          message: 'عرض',
          amount: '100',
          currency: 'YER',
          baseVersionNo: 3,
        );
        expect(client.lastBody!['baseVersionNo'], 3);
      },
    );
  });

  testWidgets('a cancelled booking carries the reason typed', (tester) async {
    final api = _PortalApi(bookingStatus: 'CONFIRMED');
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();
    // p22's cancel (D39) asks with the same optional reason.
    await tester.pumpWidget(
      _host(
        dashboard,
        ProviderBookingScreen(
          quote: QuoteRequest.fromJson(const {
            'id': 'quote-1',
            'providerId': 'provider-1',
            'status': 'ACCEPTED',
            'contactName': 'محمد الحمدي',
          }),
          booking: dashboard.bookings.single,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('provider-booking-cancel-booking-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('provider-booking-reason')),
      'تعطلت المعدات',
    );
    await tester.tap(find.byKey(const Key('provider-booking-cancel-send')));
    await tester.pumpAndSettle();

    expect(api.decisions, ['booking-1:cancel:تعطلت المعدات']);
    await tester.pump(const Duration(seconds: 5));
  });

  // RA-MO-291 (batch 9): a booking he recorded «ما صار» stayed «محجوز»,
  // with reminders and a cancel the server always refuses.
  testWidgets('a booking recorded «ما صار» is over: no cancel, no reminders', (
    tester,
  ) async {
    final dashboard = ProviderDashboardProvider(
      _PortalApi(bookingStatus: 'CONFIRMED'),
    );
    final quote = QuoteRequest.fromJson(const {
      'id': 'quote-1',
      'providerId': 'provider-1',
      'status': 'ACCEPTED',
      'contactName': 'محمد الحمدي',
    });
    final booking = MarketplaceBooking.fromJson(const {
      'id': 'booking-1',
      'quoteRequestId': 'quote-1',
      'providerId': 'provider-1',
      'eventDate': '2026-10-01',
      'status': 'CONFIRMED',
      'lifecycleStatus': 'NOT_HAPPENED',
      'notHappenedAt': '2026-10-02T09:00:00.000Z',
      'notHappenedReason': 'CUSTOMER_CANCELLED',
    });
    expect(providerCaseOf(quote, booking), ProviderCaseState.notHappened);

    await tester.pumpWidget(
      _host(dashboard, ProviderBookingScreen(quote: quote, booking: booking)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما صار'), findsWidgets);
    expect(find.text('محجوز'), findsNothing);
    expect(
      find.byKey(const Key('provider-booking-cancel-booking-1')),
      findsNothing,
    );
    expect(find.textContaining('نذكّرك'), findsNothing);
    expect(
      find.byKey(const Key('provider-booking-not-happened-note')),
      findsOneWidget,
    );
  });

  // RA-MO-294 (batch 9): the server leaves the day open when a confirmed
  // booking holds it, and says so; the phone drew the day closed anyway.
  test(
    '«مشغول ذاك اليوم»: the day is closed only when the server closed it',
    () async {
      for (final closedByServer in [true, false]) {
        final api = _PortalApi(
          quotes: const [
            {
              'id': 'quote-1',
              'providerId': 'provider-1',
              'status': 'VIEWED',
              'eventDate': '2027-01-21',
            },
          ],
        )..dayBlockedAnswer = closedByServer;
        final dashboard = ProviderDashboardProvider(api);
        await dashboard.loadDashboard();

        final declined = await dashboard.updateQuoteStatus(
          quoteRequestId: 'quote-1',
          status: 'REJECTED',
          blockDay: true,
        );

        expect(declined, isTrue);
        expect(dashboard.lastDeclineClosedDay, closedByServer);
        expect(dashboard.blockedDates, hasLength(closedByServer ? 1 : 0));
      }
    },
  );

  group('reviews', () {
    test('a review keeps its status; public ones count as published', () {
      final hidden = ProviderReview.fromJson({
        'id': 'review-1',
        'rating': 2,
        'status': 'HIDDEN',
      });
      final public = ProviderReview.fromJson({'id': 'review-2', 'rating': 5});
      expect(hidden.isPublished, isFalse);
      expect(public.status, 'PUBLISHED');
      expect(public.isPublished, isTrue);
    });

    testWidgets('the profile lists only the published reviews', (tester) async {
      final api = _PortalApi(
        reviews: const [
          ProviderReview(id: 'review-1', rating: 5, comment: 'تصوير رائع'),
          ProviderReview(
            id: 'review-2',
            rating: 1,
            comment: 'تعليق مخفي',
            status: 'HIDDEN',
          ),
        ],
      );
      await _pumpPortalTab(tester, api, const ProviderProfileTab());

      // p35 (D40): «التقييمات» opens the published reviews in a sheet.
      await tester.tap(find.byKey(const Key('provider-me-reviews')));
      await tester.pumpAndSettle();
      // Each review reads as p27's card: the words in quotes.
      expect(find.text('«تصوير رائع»'), findsOneWidget);
      expect(find.textContaining('تعليق مخفي'), findsNothing);
      expect(
        find.text('تقييم واحد في ملفك، وتقييم ما يظهر للعرسان'),
        findsOneWidget,
      );
    });
  });

  group('closed states', () {
    testWidgets('a suspended or rejected profile shows no edit controls', (
      tester,
    ) async {
      for (final status in ['SUSPENDED', 'REJECTED']) {
        final api = _PortalApi(status: status);
        await _pumpPortalTab(tester, api, const ProviderProfileTab());
        // p35 (D40): details, logo and cover sit behind «عدّل ملفك».
        expect(find.byTooltip('عدّل ملفك'), findsNothing, reason: status);
      }

      await _pumpPortalTab(tester, _PortalApi(), const ProviderProfileTab());
      expect(find.byTooltip('عدّل ملفك'), findsOneWidget);
      await tester.tap(find.byTooltip('عدّل ملفك'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('provider-me-edit-details')), findsOne);
      expect(find.byKey(const Key('provider-me-edit-logo')), findsOne);
      expect(find.byKey(const Key('provider-me-edit-cover')), findsOne);
    });

    // A refused profile opens p11 (slice 5); a tab closes only when the
    // server refuses an active profile's operations (its status changed).
    testWidgets('a closed portal tab offers support and pulls to refresh', (
      tester,
    ) async {
      final api = _PortalApi(denyOperations: true);
      await _pumpPortal(tester, api, initialTab: 'requests');

      expect(find.text('عمليات المزود مو متاحة'), findsOneWidget);
      expect(
        find.text('اسحب الصفحة لتحت عشان تتحدّث حالة حسابك.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('provider-operations-support')),
        findsOneWidget,
      );

      final loads = api.profileLoads;
      await tester.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(api.profileLoads, greaterThan(loads));

      await tester.tap(find.byKey(const Key('provider-operations-support')));
      await tester.pumpAndSettle();
      expect(find.text('صفحة الدعم'), findsOneWidget);
    });

    // A suspended profile now opens p12 (D36), which keeps the way to
    // support as its main action.
    testWidgets('a suspended profile reaches support from p12', (tester) async {
      final api = _PortalApi(status: 'SUSPENDED');
      await _pumpPortal(tester, api);

      expect(find.text('حسابك موقوف مؤقتًا'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-suspended-support')));
      await tester.pumpAndSettle();
      expect(find.text('صفحة الدعم'), findsOneWidget);
    });

    testWidgets('a link opens the portal on its requests tab', (tester) async {
      await _pumpPortal(tester, _PortalApi(), initialTab: 'requests');
      expect(
        find.byKey(const Key('provider-requests-tab-fresh')).hitTestable(),
        findsOneWidget,
      );
    });

    test('no line promises a review path the server does not have', () {
      final edit = File(
        'lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
      ).readAsStringSync();
      final home = File(
        'lib/features/provider_portal/screens/provider_home_tab.dart',
      ).readAsStringSync();
      expect(edit, isNot(contains('مسار مراجعة منفصل')));
      expect(edit, contains("'NEEDS_CHANGES' => 'يحتاج تعديل'"));
      expect(home, isNot(contains('ليُراجع من جديد')));
      expect(home, isNot(contains('قبل تحديث الملف')));
    });
  });
}

void _expectDaysAhead(DateTime? sent, DateTime before, int days) {
  expect(sent, isNotNull);
  final expected = before.add(Duration(days: days));
  expect(sent!.difference(expected).inMinutes.abs(), lessThan(2));
}

Widget _host(ProviderDashboardProvider dashboard, Widget child) =>
    ChangeNotifierProvider<ProviderDashboardProvider>.value(
      value: dashboard,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

Future<void> _pumpRequests(WidgetTester tester, _PortalApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final chat = requests.RecordingChatProvider(
    AuthStorage(await SharedPreferences.getInstance()),
  );
  addTearDown(chat.dispose);
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderRequestsTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/provider/requests/:id',
        builder: (_, state) =>
            ProviderRequestScreen(quoteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/requests/:id/offer',
        builder: (_, state) =>
            ProviderOfferScreen(quoteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quotes/:id/conversation',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('محادثة الطلب ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the request from its card in the list.
Future<void> _openRequest(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('provider-request-quote-1')));
  await tester.pumpAndSettle();
}

/// «شوف العرض قبل ما يوصله», then the send in its sheet.
Future<void> _sendOffer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('provider-offer-preview')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('provider-offer-submit')));
  await tester.pumpAndSettle();
}

Future<void> _pumpPortalTab(
  WidgetTester tester,
  _PortalApi api,
  Widget tab,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  await tester.pumpWidget(_host(dashboard, tab));
  await tester.pumpAndSettle();
}

Future<void> _pumpPortal(
  WidgetTester tester,
  _PortalApi api, {
  String? initialTab,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final chat = _IdleChatProvider(storage);
  addTearDown(chat.dispose);
  final router = GoRouter(
    initialLocation: initialTab == null ? '/portal' : '/portal?tab=$initialTab',
    routes: [
      GoRoute(
        path: '/portal',
        builder: (_, state) =>
            ProviderPortalScreen(initialTab: state.uri.queryParameters['tab']),
      ),
      GoRoute(
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('صفحة الدعم')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderDashboardProvider>(
          create: (_) => ProviderDashboardProvider(api),
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _IdleChatProvider extends ChatProvider {
  _IdleChatProvider(AuthStorage storage)
    : super(
        api: ChatApi(ApiClient(tokenProvider: () async => null)),
        realtime: ChatRealtimeClient(storage),
        authStorage: storage,
      );

  @override
  List<ChatConversation> get conversations => const [];

  @override
  Future<void> initialize() async {}
}

class _RecordingClient extends ApiClient {
  _RecordingClient() : super(tokenProvider: () async => null);

  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    lastBody = body;
    return {'id': 'offer-1', 'status': 'PENDING'};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    lastBody = body;
    return {'id': 'offer-1', 'status': 'PENDING'};
  }
}

class _PortalApi extends ProviderDashboardApi {
  _PortalApi({
    this.status = 'ACTIVE',
    List<Map<String, dynamic>> quotes = const [],
    this.reviews = const [],
    this.bookingStatus = 'REQUESTED',
    this.hasBooking = true,
    this.denyOperations = false,
  }) : _quotes = [for (final quote in quotes) Map.of(quote)],
       super(ApiClient(tokenProvider: () async => null));

  final String status;

  /// The server refuses the operations (403) although the profile reads
  /// as active.
  final bool denyOperations;
  final List<Map<String, dynamic>> _quotes;
  final List<ProviderReview> reviews;
  String bookingStatus;

  /// A request under answer has no booking yet (slice 2 reads its state
  /// from the booking too).
  final bool hasBooking;
  int profileLoads = 0;
  final statusUpdates = <String>[];
  final createdOffers = <DateTime?>[];
  final updatedOffers = <DateTime?>[];
  final updatedOfferIds = <String>[];
  final updatedOfferVersions = <int?>[];
  final decisions = <String>[];

  @override
  Future<ProviderDashboardProfile> getProfile() async {
    profileLoads += 1;
    return ProviderDashboardProfile(
      id: 'provider-1',
      businessName: 'استديو الفن',
      status: status,
      ratingAverage: 0,
      ratingCount: 0,
    );
  }

  @override
  Future<ProviderDashboardSummary> getSummary() async {
    if (denyOperations) {
      throw const ApiException('forbidden', statusCode: 403);
    }
    return ProviderDashboardSummary.empty();
  }

  @override
  Future<List<MarketplaceService>> getServices() async => const [];

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => [
    for (final quote in _quotes) QuoteRequest.fromJson(quote),
  ];

  @override
  Future<List<ProviderReview>> getReviews() async => reviews;

  @override
  Future<List<MarketplaceBooking>> getBookings() async => [
    if (hasBooking)
      MarketplaceBooking.fromJson({
        'id': 'booking-1',
        'quoteRequestId': 'quote-1',
        'providerId': 'provider-1',
        'eventDate': '2027-02-18',
        'status': bookingStatus,
        'lifecycleStatus': bookingStatus,
      }),
  ];

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];

  @override
  Future<QuoteRequest> updateQuoteRequestStatus({
    required String quoteRequestId,
    required String status,
    String? declineReason,
    String? declineMessage,
    bool blockDay = false,
  }) async {
    statusUpdates.add('$quoteRequestId:$status');
    final quote = _quotes.firstWhere((item) => item['id'] == quoteRequestId);
    quote['status'] = status;
    return QuoteRequest.fromJson({
      ...quote,
      if (blockDay) 'dayBlocked': dayBlockedAnswer,
    });
  }

  /// B-05: what the server says of the day on «مشغول ذاك اليوم».
  bool dayBlockedAnswer = true;

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
  }) async {
    createdOffers.add(validUntil);
    return QuoteOffer.fromJson({'id': 'offer-new', 'status': 'PENDING'});
  }

  @override
  Future<QuoteOffer> updateQuoteOffer({
    required String quoteOfferId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
    int? baseVersionNo,
  }) async {
    updatedOfferIds.add(quoteOfferId);
    updatedOfferVersions.add(baseVersionNo);
    updatedOffers.add(validUntil);
    return QuoteOffer.fromJson({'id': quoteOfferId, 'status': 'PENDING'});
  }

  @override
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    decisions.add('$bookingId:$action:${note ?? ''}');
    bookingStatus = action == 'confirm' ? 'CONFIRMED' : 'CANCELLED';
    return MarketplaceBooking.fromJson({
      'id': bookingId,
      'quoteRequestId': 'quote-1',
      'providerId': 'provider-1',
      'eventDate': '2027-02-18',
      'status': bookingStatus,
    });
  }
}
