import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_board.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// f01 the board, f04 offers side by side, f05 asking for the booking, x10
// declining politely, w31 an expired offer, x11 cancelling, and the review
// once the day passed.

const _photo = MarketplaceService(
  id: 'service-photo',
  providerId: 'p1',
  title: 'صور وفيديو',
  category: ProviderCategory(id: 'cat-photo', nameAr: 'تصوير'),
  isFeatured: false,
  isActive: true,
);

QuoteRequest _offer(
  String id,
  String provider,
  String amount, {
  String lifecycle = 'RECEIVED',
  String offerStatus = 'PENDING',
  bool expired = false,
  MarketplaceBooking? booking,
  String? costId,
  String plan = 'plan-1',
}) => QuoteRequest(
  id: id,
  providerId: 'provider-$id',
  weddingPlanId: plan,
  status: lifecycle,
  lifecycleStatus: lifecycle,
  eventDate: DateTime(2027, 1, 21),
  provider: ProviderSummary(
    id: 'provider-$id',
    businessName: provider,
    ratingAverage: 4.8,
    ratingCount: 63,
  ),
  service: _photo,
  offers: [
    QuoteOffer(
      id: 'offer-$id',
      status: offerStatus,
      amount: amount,
      currency: 'YER',
      title: 'مصورين اثنين وألبوم',
      message: 'فيلم 10 دقائق',
      serverIsExpired: expired,
    ),
  ],
  booking: booking,
  costSuggestion: costId == null
      ? null
      : QuoteCostSuggestion(
          providerId: 'provider-$id',
          providerName: provider,
          suggestedAction: 'VIEW_COST',
          automaticCostCreated: true,
          costId: costId,
          availableActions: const ['VIEW_COST'],
        ),
);

QuoteRequest _waiting(String id, String provider) => QuoteRequest(
  id: id,
  providerId: 'provider-$id',
  weddingPlanId: 'plan-1',
  status: 'SENT',
  lifecycleStatus: 'PENDING_PROVIDER',
  provider: ProviderSummary(
    id: 'provider-$id',
    businessName: provider,
    ratingAverage: 0,
    ratingCount: 0,
  ),
  service: _photo,
);

MarketplaceBooking _booking(String status, {String? lifecycle}) =>
    MarketplaceBooking.fromJson({
      'id': 'booking-1',
      'quoteRequestId': 'q1',
      'providerId': 'provider-q1',
      'eventDate': '2027-01-21',
      'status': status,
      'lifecycleStatus': lifecycle ?? status,
    });

QuoteRequest _accepted({MarketplaceBooking? booking}) => _offer(
  'q1',
  'ضوء صنعاء',
  '550000',
  lifecycle: 'ACCEPTED',
  offerStatus: 'ACCEPTED',
  booking: booking,
  costId: 'cost-q1',
);

void main() {
  group('f01 board', () {
    const items = [
      (id: 'hall', name: 'القاعة'),
      (id: 'photo', name: 'التصوير'),
      (id: 'qat', name: 'القات'),
      (id: 'mahr', name: 'المهر'),
    ];

    test('rows are the wedding services, with how far each got', () {
      final rows = buildProviderBoard(
        items: items,
        costs: const [
          (budgetCategoryId: 'hall', providerId: null, partyName: 'قاعة سبأ'),
        ],
        costItemById: const {},
        quotes: [
          _offer('q1', 'ضوء صنعاء', '550000'),
          _offer('q2', 'عدسة سبأ', '480000'),
          _offer('q9', 'خطة ثانية', '1', plan: 'plan-2'),
        ].where((quote) => quote.weddingPlanId == 'plan-1').toList(),
      );

      expect(rows.map((row) => row.title), ['القاعة', 'التصوير', 'القات']);
      expect(rows[0].stage, 4);
      expect(rows[0].detail, 'قاعة سبأ · خارج اعّرست');
      expect(rows[1].stage, 2);
      expect(rows[1].detail, 'عرضين وصلوا');
      expect(rows[1].waitingOffers, 2);
      expect(rows[2].stage, 0);
      expect(rows[2].detail, 'ما بدأت');
      // المهر is not a service: no row.
      expect(providerBoardStatus(rows), 'محجوز 1 · عرضين ينتظرونك');
    });

    test('an accepted offer files under the item its cost went to', () {
      final rows = buildProviderBoard(
        items: items,
        costs: const [
          (budgetCategoryId: 'photo', providerId: 'provider-q1', partyName: null),
        ],
        costItemById: const {'cost-q1': 'photo'},
        quotes: [
          _accepted(booking: _booking('CONFIRMED')),
          _waiting('q3', 'مقوّت الروضة'),
        ],
      );
      final photo = rows.firstWhere((row) => row.key == 'photo');
      expect(photo.stage, 4);
      expect(photo.detail, startsWith('ضوء صنعاء · أكّد'));
      // A request whose service matches no item gets its own row; here the
      // photo service matched, so the waiting one joined the photo row.
      expect(rows.where((row) => row.key.startsWith('category:')), isEmpty);
    });

    test('waiting requests and a requested booking read truthfully', () {
      final rows = buildProviderBoard(
        items: items,
        costs: const [],
        costItemById: const {},
        quotes: [_waiting('q3', 'أ'), _waiting('q4', 'ب')],
      );
      expect(rows.firstWhere((row) => row.key == 'photo').detail,
          'طلبت من اثنين · ينتظر الرد');
      final booked = buildProviderBoard(
        items: items,
        costs: const [],
        costItemById: const {'cost-q1': 'photo'},
        quotes: [_accepted(booking: _booking('REQUESTED'))],
      );
      final photo = booked.firstWhere((row) => row.key == 'photo');
      expect(photo.stage, 3);
      expect(photo.detail, 'ضوء صنعاء · ينتظر تأكيده');
    });
  });

  testWidgets('f04 two offers side by side; choosing one asks for the booking', (
    tester,
  ) async {
    final h = await _pump(tester, [
      _offer('q1', 'ضوء صنعاء', '550000'),
      _offer('q2', 'عدسة سبأ', '480000'),
    ]);

    expect(find.text('قارن عروض التصوير'), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-offer-q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-offer-q2')), findsOneWidget);
    expect(find.text('فيلم 10 دقائق'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('requests-choose-note')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('requests-choose-q1')));
    await tester.pumpAndSettle();

    expect(h.marketplace.acceptedQuoteIds, ['q1']);
    // Money reloads with the cost the server created from the offer.
    expect(h.finance.loadedPlanId, 'plan-1');
    // f05 opens on the request's day.
    expect(find.text('نطلب الحجز؟'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-no-payment')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-request')));
    await tester.pumpAndSettle();
    expect(h.marketplace.bookingDays, [DateTime(2027, 1, 21)]);
  });

  testWidgets('x10 the polite message goes first, then the offer is declined', (
    tester,
  ) async {
    final h = await _pump(tester, [_offer('q1', 'ضوء صنعاء', '550000')]);

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    expect(find.text('ما يناسبك العرض؟'), findsOneWidget);
    expect(find.text('بندك ما ينذكر'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('decline-reason-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();

    expect(h.chat.sent.single, contains('اخترنا مزود ثاني'));
    expect(h.marketplace.rejectedQuoteIds, ['q1']);
  });

  testWidgets('x10 nothing is declined when the message did not arrive', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      [_offer('q1', 'ضوء صنعاء', '550000')],
      chatFails: true,
    );

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();

    expect(h.marketplace.rejectedQuoteIds, isEmpty);
    expect(find.text('ما وصلت رسالتك. جرّب مرة ثانية.'), findsOneWidget);
  });

  testWidgets('waiting and expired requests: no decisions, ask again', (
    tester,
  ) async {
    await _pump(tester, [
      _waiting('q3', 'مزود ينتظر'),
      _offer('q4', 'عدسة سبأ', '350000', expired: true),
    ]);

    expect(find.byKey(const ValueKey('requests-waiting-q3')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-choose-q3')), findsNothing);
    expect(find.byKey(const ValueKey('requests-expired-q4')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-choose-q4')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('requests-new-q4')));
    await tester.pumpAndSettle();
    expect(find.text('opened /providers/provider-q4/quote'), findsOneWidget);
  });

  testWidgets('the chosen provider: book, see the cost in money', (tester) async {
    final h = await _pump(tester, [_accepted()]);

    expect(find.text('باقي تطلب منهم حجز يوم عرسك'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('requests-book-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-other-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-request')));
    await tester.pumpAndSettle();
    expect(h.marketplace.bookingDays, [DateTime(2027, 1, 22)]);

    await tester.tap(find.byKey(const ValueKey('requests-view-cost-q1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cost-q1'), findsOneWidget);
  });

  testWidgets('a requested booking waits for them and can be withdrawn', (
    tester,
  ) async {
    await _pump(tester, [_accepted(booking: _booking('REQUESTED'))]);

    expect(find.text('ينتظر تأكيدهم'), findsOneWidget);
    expect(find.text('ألغِ الطلب'), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-book-q1')), findsNothing);
  });

  testWidgets('a confirmed booking can be cancelled after seeing what happens', (
    tester,
  ) async {
    final h = await _pump(tester, [_accepted(booking: _booking('CONFIRMED'))]);

    expect(find.text('محجوز'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('requests-cancel-booking-q1')));
    await tester.pumpAndSettle();
    expect(find.text('يوصلهم إن الحجز انلغى'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('requests-cancel-booking-confirm')),
    );
    await tester.pumpAndSettle();
    expect(h.marketplace.cancelledBookings, ['q1']);
  });

  testWidgets('after the day, the groom rates the provider', (tester) async {
    await _pump(tester, [
      _accepted(booking: _booking('CONFIRMED', lifecycle: 'COMPLETED')),
    ]);

    // D21: rating happens on «قيّم مزودينك» (g04), not in a sheet here.
    await tester.tap(find.byKey(const ValueKey('requests-rate-q1')));
    await tester.pumpAndSettle();
    expect(
      find.text('opened /wedding-plans/plan-1/providers/reviews?provider=provider-q1'),
      findsOneWidget,
    );
  });

  testWidgets('a notification opens its request without knowing the row', (
    tester,
  ) async {
    await _pump(
      tester,
      [_offer('q1', 'ضوء صنعاء', '550000'), _waiting('q3', 'مزود ثاني')],
      itemKey: null,
      quoteId: 'q3',
    );
    expect(find.byKey(const ValueKey('requests-waiting-q3')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-offer-q1')), findsOneWidget);
  });

  testWidgets('offers stay readable at 320px and 1.3 text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, [
      _offer('q1', 'ضوء صنعاء', '550000'),
      _offer('q2', 'عدسة سبأ', '480000'),
    ], width: 320);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('requests-choose-q2')), findsOneWidget);
  });
}

class _Harness {
  _Harness(this.marketplace, this.finance, this.chat);

  final _Marketplace marketplace;
  final FinanceProvider finance;
  final _Chat chat;
}

Future<_Harness> _pump(
  WidgetTester tester,
  List<QuoteRequest> quotes, {
  String? itemKey = 'photo',
  String? quoteId,
  bool chatFails = false,
  double width = 420,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);
  final marketplace = _Marketplace(quotes);
  final finance = FinanceProvider(_Finance());
  await finance.loadMoney('plan-1');
  final chat = _Chat(fails: chatFails);
  final router = GoRouter(
    initialLocation: '/requests',
    routes: [
      GoRoute(
        path: '/requests',
        builder: (context, state) => ProviderRequestsScreen(
          weddingPlanId: 'plan-1',
          itemKey: itemKey,
          quoteId: quoteId,
          pickDay: (context, initial) async => DateTime(2027, 1, 22),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(body: Text('opened ${state.uri}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
        ),
        ChangeNotifierProvider<FinanceProvider>.value(value: finance),
        Provider<ChatApi>.value(value: chat),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(marketplace, finance, chat);
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(List<QuoteRequest> quotes)
    : _quotes = List.of(quotes),
      super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> _quotes;
  final acceptedQuoteIds = <String>[];
  final rejectedQuoteIds = <String>[];
  final bookingDays = <DateTime?>[];
  final cancelledBookings = <String>[];
  final reviews = <String>[];

  @override
  List<QuoteRequest> get quoteRequests => _quotes;

  @override
  bool get isSubmitting => false;

  @override
  Future<void> loadScopedQuoteRequests() async {}

  @override
  Future<bool> acceptQuote(QuoteRequest quote) async {
    acceptedQuoteIds.add(quote.id);
    return true;
  }

  @override
  Future<bool> rejectQuote(QuoteRequest quote) async {
    rejectedQuoteIds.add(quote.id);
    return true;
  }

  @override
  Future<bool> requestBooking(QuoteRequest quote, {DateTime? eventDate}) async {
    bookingDays.add(eventDate);
    return true;
  }

  @override
  Future<bool> cancelBooking(QuoteRequest quote) async {
    cancelledBookings.add(quote.id);
    return true;
  }

  @override
  Future<String?> reviewProvider({
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    reviews.add('$providerId:$rating:${comment ?? ''}');
    return null;
  }
}

class _Chat extends ChatApi {
  _Chat({required this.fails})
    : super(ApiClient(tokenProvider: () async => null));

  final bool fails;
  final sent = <String>[];

  @override
  Future<ChatConversation> conversationForQuote(String quoteRequestId) async {
    if (fails) throw StateError('offline');
    return ChatConversation.fromJson({
      'id': 'conversation-$quoteRequestId',
      'weddingPlanId': 'plan-1',
      'providerId': 'provider-$quoteRequestId',
    });
  }

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<Object> attachments = const [],
  }) async {
    sent.add(body);
    return ChatMessage.fromJson({
      'id': 'm1',
      'conversationId': conversationId,
      'body': body,
      'createdAt': '2026-10-23T10:00:00.000Z',
    });
  }
}

class _Finance extends FinanceApi {
  _Finance() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async =>
      const MoneySummary(
        planId: 'plan-1',
        categories: [
          MoneyCategorySummary(
            categoryId: 'photo',
            name: 'التصوير',
            allocatedAmount: '600000',
            confirmedCost: '0',
            outstanding: '0',
            costsCount: 0,
          ),
        ],
      );

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
    String? payer,
  }) async => const FinancePage(
    items: [
      WeddingCost(
        id: 'cost-q1',
        weddingPlanId: 'plan-1',
        budgetCategoryId: 'photo',
        title: 'صور وفيديو',
        totalAmount: '550000',
        paidAmount: '0',
        remainingAmount: '550000',
        status: 'OPEN',
        providerId: 'provider-q1',
      ),
    ],
    page: 1,
    pageSize: 30,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];
}
