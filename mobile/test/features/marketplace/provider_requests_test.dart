import 'dart:async';

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
  isActive: true,
);

QuoteRequest _offer(
  String id,
  String provider,
  String? amount, {
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

MarketplaceBooking _booking(
  String status, {
  String? lifecycle,
  String? notHappenedReason,
}) => MarketplaceBooking.fromJson({
  'id': 'booking-1',
  'quoteRequestId': 'q1',
  'providerId': 'provider-q1',
  'eventDate': '2027-01-21',
  'status': status,
  'lifecycleStatus': lifecycle ?? status,
  'notHappenedReason': ?notHappenedReason,
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
    // G40: each item's directory categories as the money summary lists
    // them; المهر has none.
    const items = [
      (id: 'hall', name: 'القاعة', providerCategoryIds: ['cat-hall']),
      (id: 'photo', name: 'التصوير', providerCategoryIds: ['cat-photo']),
      (id: 'qat', name: 'القات', providerCategoryIds: ['cat-qat']),
      (id: 'mahr', name: 'المهر', providerCategoryIds: <String>[]),
    ];

    test(
      'G40: an item is a service by its server categories, not its name',
      () {
        final rows = buildProviderBoard(
          items: const [
            (
              id: 'incense',
              name: 'البخور',
              providerCategoryIds: ['cat-perfume'],
            ),
            (
              id: 'naqsh',
              name: 'المزينة والنقاشة',
              providerCategoryIds: ['cat-henna'],
            ),
            (id: 'subhia', name: 'الصبحية', providerCategoryIds: <String>[]),
          ],
          costs: const [],
          costItemById: const {},
          quotes: [
            QuoteRequest(
              id: 'q5',
              providerId: 'provider-q5',
              weddingPlanId: 'plan-1',
              status: 'SENT',
              lifecycleStatus: 'PENDING_PROVIDER',
              provider: const ProviderSummary(
                id: 'provider-q5',
                businessName: 'عطور الريان',
                ratingAverage: 0,
                ratingCount: 0,
              ),
              service: const MarketplaceService(
                id: 'service-oud',
                providerId: 'provider-q5',
                title: 'بخور وعود',
                category: ProviderCategory(id: 'cat-perfume', nameAr: 'عطور'),
                isActive: true,
              ),
            ),
          ],
        );
        expect(rows.map((row) => row.title), ['البخور', 'المزينة والنقاشة']);
        expect(rows.first.stage, 1);
        expect(rows.last.providerCategoryIds, ['cat-henna']);
      },
    );

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
          (
            budgetCategoryId: 'photo',
            providerId: 'provider-q1',
            partyName: null,
          ),
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
      expect(
        rows.firstWhere((row) => row.key == 'photo').detail,
        'طلبت من اثنين · ينتظر الرد',
      );
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

  testWidgets(
    'f04 two offers side by side; choosing one asks for the booking',
    (tester) async {
      final h = await _pump(tester, [
        _offer('q1', 'ضوء صنعاء', '550000'),
        _offer('q2', 'عدسة سبأ', '480000'),
      ]);

      expect(find.text('قارن عروض التصوير'), findsOneWidget);
      expect(find.byKey(const ValueKey('requests-offer-q1')), findsOneWidget);
      expect(find.byKey(const ValueKey('requests-offer-q2')), findsOneWidget);
      expect(find.text('فيلم 10 دقائق'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('requests-choose-note')),
        findsOneWidget,
      );

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
    },
  );

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
    final h = await _pump(tester, [
      _offer('q1', 'ضوء صنعاء', '550000'),
    ], chatFails: true);

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();

    expect(h.marketplace.rejectedQuoteIds, isEmpty);
    expect(find.text('ما وصلت رسالتك. جرّب مرة ثانية.'), findsOneWidget);
  });

  testWidgets('x10 a refused decline keeps the words and sends them once', (
    tester,
  ) async {
    final marketplace = _Marketplace([_offer('q1', 'ضوء صنعاء', '550000')])
      ..refuseDeclines = 1;
    final h = await _pump(tester, const [], marketplace: marketplace);

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('decline-message')),
        matching: find.byType(EditableText),
      ),
      'شكرًا لكم، لقينا قاعة أقرب',
    );
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();

    // The message arrived, the decline did not: the sheet stays with the
    // groom's own words.
    expect(h.chat.sent, ['شكرًا لكم، لقينا قاعة أقرب']);
    expect(h.marketplace.rejectedQuoteIds, isEmpty);
    expect(find.text('ما يناسبك العرض؟'), findsOneWidget);
    expect(find.text('شكرًا لكم، لقينا قاعة أقرب'), findsOneWidget);

    // Trying again records the decline without a second message.
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();
    expect(h.chat.sent, hasLength(1));
    expect(h.marketplace.rejectedQuoteIds, ['q1']);
    expect(find.text('ما يناسبك العرض؟'), findsNothing);
  });

  // RA-MO-257: closing the sheet forgot that the message arrived, so the
  // sheet opened again sent the polite message a second time.
  testWidgets('x10 the sheet opened again does not send the message twice', (
    tester,
  ) async {
    final marketplace = _Marketplace([_offer('q1', 'ضوء صنعاء', '550000')])
      ..refuseDeclines = 1;
    final h = await _pump(tester, const [], marketplace: marketplace);

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();
    expect(h.chat.sent, hasLength(1));
    expect(h.marketplace.rejectedQuoteIds, isEmpty);

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    expect(find.text('ما يناسبك العرض؟'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('requests-decline-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-send')));
    await tester.pumpAndSettle();

    expect(h.chat.sent, hasLength(1));
    expect(h.marketplace.rejectedQuoteIds, ['q1']);
    // And the message went with a key, so a lost answer is not a second one.
    expect(h.chat.keys.single, startsWith('decline-offer-q1-'));
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

  testWidgets('the earlier list says who said no, and a request past its '
      'seven days has ended', (tester) async {
    QuoteRequest bare(
      String id,
      String provider, {
      required String status,
      required String lifecycle,
      DateTime? expiresAt,
    }) => QuoteRequest(
      id: id,
      providerId: 'provider-$id',
      weddingPlanId: 'plan-1',
      status: status,
      lifecycleStatus: lifecycle,
      provider: ProviderSummary(
        id: 'provider-$id',
        businessName: provider,
        ratingAverage: 0,
        ratingCount: 0,
      ),
      service: _photo,
      expiresAt: expiresAt,
    );
    await _pump(tester, [
      _offer(
        'q5',
        'عدسة سبأ',
        '350000',
        lifecycle: 'REJECTED',
        offerStatus: 'REJECTED',
      ),
      bare('q6', 'استوديو الريان', status: 'REJECTED', lifecycle: 'REJECTED'),
      bare(
        'q7',
        'ستوديو النور',
        status: 'SENT',
        lifecycle: 'PENDING_PROVIDER',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);

    Finder line(String id, String text) => find.descendant(
      of: find.byKey(ValueKey('requests-earlier-$id')),
      matching: find.text(text),
    );
    // He rejected their offer; they declined his request.
    expect(line('q5', 'اعتذرت عن عرضهم'), findsOneWidget);
    expect(line('q6', 'اعتذروا عن الطلب'), findsOneWidget);
    // Past its deadline the server takes no answer: ended, not waiting.
    expect(line('q7', 'ما ردوا خلال 7 أيام'), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-waiting-q7')), findsNothing);
  });

  testWidgets(
    'RA-BE-46: «ما حضرنا» from the provider asks for a review, other reasons send to support',
    (tester) async {
      MarketplaceBooking notHappened(String reason) =>
          MarketplaceBooking.fromJson({
            'id': 'booking-1',
            'quoteRequestId': 'q1',
            'providerId': 'provider-q1',
            'eventDate': '2027-01-21',
            'status': 'CONFIRMED',
            'lifecycleStatus': 'NOT_HAPPENED',
            'notHappenedReason': reason,
          });

      await _pump(tester, [
        _accepted(booking: notHappened('WE_DID_NOT_ATTEND')),
      ]);
      expect(find.textContaining('قالوا إنهم ما حضروا'), findsOneWidget);
      expect(find.textContaining('كلّم الدعم'), findsNothing);

      await _pump(tester, [
        _accepted(booking: notHappened('CUSTOMER_NO_SHOW')),
      ]);
      expect(
        find.text('سجّلوا إن الحجز ما تم. لو عندك ملاحظة كلّم الدعم.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the chosen provider: book, see the cost in money', (
    tester,
  ) async {
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

  testWidgets(
    'a confirmed booking can be cancelled after seeing what happens',
    (tester) async {
      final h = await _pump(tester, [
        _accepted(booking: _booking('CONFIRMED')),
      ]);

      expect(find.text('محجوز'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('requests-cancel-booking-q1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('يوصلهم إن الحجز انلغى'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('requests-cancel-booking-confirm')),
      );
      await tester.pumpAndSettle();
      expect(h.marketplace.cancelledBookings, ['q1']);
    },
  );

  testWidgets('after the day, the groom rates the provider', (tester) async {
    await _pump(tester, [
      _accepted(booking: _booking('CONFIRMED', lifecycle: 'COMPLETED')),
    ]);

    // The server cancels only before the day, so a finished booking has no
    // cancel to offer.
    expect(
      find.byKey(const ValueKey('requests-cancel-booking-q1')),
      findsNothing,
    );
    // D21: rating happens on «قيّم مزودينك» (g04), not in a sheet here.
    await tester.tap(find.byKey(const ValueKey('requests-rate-q1')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'opened /wedding-plans/plan-1/providers/reviews?provider=provider-q1',
      ),
      findsOneWidget,
    );
  });

  // RA-MO-246: the card said «قالوا إنهم ما حضروا. قيّمهم» and gave no way
  // to do it; the server takes exactly this review (RA-BE-46).
  testWidgets('their own absence leaves a way to rate them', (tester) async {
    await _pump(tester, [
      _accepted(
        booking: _booking(
          'CONFIRMED',
          lifecycle: 'NOT_HAPPENED',
          notHappenedReason: 'WE_DID_NOT_ATTEND',
        ),
      ),
    ]);

    expect(find.textContaining('قالوا إنهم ما حضروا'), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-rate-q1')), findsOneWidget);
    // The day has passed: the server would refuse a cancel.
    expect(
      find.byKey(const ValueKey('requests-cancel-booking-q1')),
      findsNothing,
    );
  });

  testWidgets('any other «ما صار» closes the review', (tester) async {
    await _pump(tester, [
      _accepted(
        booking: _booking(
          'CONFIRMED',
          lifecycle: 'NOT_HAPPENED',
          notHappenedReason: 'CUSTOMER_CANCELLED',
        ),
      ),
    ]);

    expect(find.byKey(const ValueKey('requests-rate-q1')), findsNothing);
  });

  // RA-MO-248: choosing makes a money item, so the server asks for the
  // money right. The button was shown to every providers manager and the
  // server then refused; and an amount the server kept back read «بدون
  // مبلغ», a false word about the offer.
  testWidgets('a reader without the money right is not offered «اختر هذا»', (
    tester,
  ) async {
    await _pump(tester, [
      _offer('q1', 'ضوء صنعاء', '550000'),
    ], managesMoney: false);

    expect(find.byKey(const ValueKey('requests-choose-q1')), findsNothing);
    expect(find.byKey(const ValueKey('requests-choose-note')), findsNothing);
    expect(
      find.byKey(const ValueKey('requests-choose-by-money')),
      findsOneWidget,
    );
    // Saying no and talking to them need no money right.
    expect(find.byKey(const ValueKey('requests-decline-q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-chat-q1')), findsOneWidget);
  });

  testWidgets('an amount kept from the reader is not «بدون مبلغ»', (
    tester,
  ) async {
    await _pump(
      tester,
      [_offer('q1', 'ضوء صنعاء', null)],
      // Without the money there are no items: the page finds its request.
      itemKey: null,
      quoteId: 'q1',
      seesMoney: false,
      managesMoney: false,
    );

    expect(find.text('بدون مبلغ'), findsNothing);
    expect(
      find.byKey(const ValueKey('requests-offer-amount-hidden-q1')),
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

  // R12: a second «اختر هذا» would put a second agreement on the same item.
  testWidgets('a service already chosen offers no second choice', (
    tester,
  ) async {
    await _pump(tester, [
      _offer('q1', 'ضوء صنعاء', '550000', lifecycle: 'ACCEPTED'),
      _offer('q2', 'عدسة سبأ', '480000'),
    ]);

    expect(find.byKey(const ValueKey('requests-offer-q2')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-choose-q2')), findsNothing);
    expect(find.byKey(const ValueKey('requests-decline-q2')), findsOneWidget);
  });

  // R15: the notification can be the first thing opened, before the
  // providers tab ever read the plan's requests.
  testWidgets('a notification opened first loads its offer', (tester) async {
    final marketplace = _Marketplace(
      const [],
      toLoad: [_offer('q1', 'ضوء صنعاء', '550000')],
      holdLoad: true,
    );
    await _pump(
      tester,
      const [],
      itemKey: null,
      quoteId: 'q1',
      marketplace: marketplace,
      settle: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('requests-empty')), findsNothing);

    marketplace.finishLoad();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('requests-offer-q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('requests-empty')), findsNothing);
  });

  testWidgets('a failed load offers a retry, it never reads as empty', (
    tester,
  ) async {
    final marketplace = _Marketplace(
      const [],
      toLoad: [_offer('q1', 'ضوء صنعاء', '550000')],
      failLoads: 1,
    );
    await _pump(
      tester,
      const [],
      itemKey: null,
      quoteId: 'q1',
      marketplace: marketplace,
    );
    expect(find.byKey(const ValueKey('requests-empty')), findsNothing);

    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
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
  _Marketplace? marketplace,
  bool settle = true,
  bool seesMoney = true,
  bool managesMoney = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);
  marketplace ??= _Marketplace(quotes);
  final finance = FinanceProvider(_Finance());
  await finance.loadMoney(
    'plan-1',
    canViewMoney: seesMoney,
    canManageMoney: managesMoney,
  );
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
    errorBuilder: (context, state) =>
        Scaffold(body: Text('opened ${state.uri}')),
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
  if (settle) await tester.pumpAndSettle();
  return _Harness(marketplace, finance, chat);
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(
    List<QuoteRequest> quotes, {
    List<QuoteRequest> toLoad = const [],
    bool holdLoad = false,
    int failLoads = 0,
  }) : _quotes = List.of(quotes),
       _toLoad = List.of(toLoad),
       _held = holdLoad ? Completer<void>() : null,
       _failLoads = failLoads,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> _quotes;
  final List<QuoteRequest> _toLoad;
  final Completer<void>? _held;
  int _failLoads;
  String? _loadError;
  final acceptedQuoteIds = <String>[];
  final rejectedQuoteIds = <String>[];
  final bookingDays = <DateTime?>[];
  final cancelledBookings = <String>[];
  final reviews = <String>[];

  @override
  List<QuoteRequest> get quoteRequests => _quotes;

  @override
  bool get isSubmitting => false;

  void finishLoad() => _held?.complete();

  @override
  String? get quoteRequestsErrorMessage => _loadError;

  /// As the real provider: nothing comes back until the account's scope is
  /// set.
  @override
  Future<void> loadScopedQuoteRequests() async {
    if (!includesAccountData) return;
    await _held?.future;
    if (_failLoads > 0) {
      _failLoads -= 1;
      _loadError = 'ما قدرنا نوصل للخادم.';
    } else {
      _loadError = null;
      _quotes.addAll(_toLoad);
      _toLoad.clear();
    }
    notifyListeners();
  }

  @override
  Future<bool> acceptQuote(QuoteRequest quote) async {
    acceptedQuoteIds.add(quote.id);
    return true;
  }

  /// How many declines the server refuses before taking one.
  int refuseDeclines = 0;

  @override
  Future<bool> rejectQuote(QuoteRequest quote, {String? reason}) async {
    if (refuseDeclines > 0) {
      refuseDeclines -= 1;
      return false;
    }
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
  final keys = <String?>[];

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
    String? clientRequestId,
  }) async {
    sent.add(body);
    keys.add(clientRequestId);
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
            // G40: the server lists the photo kind under this item.
            providerCategoryIds: ['cat-photo'],
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
