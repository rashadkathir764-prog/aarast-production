import 'package:aarast_mobile/core/media/media_upload_api.dart';
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
import 'package:aarast_mobile/features/provider_portal/screens/provider_offer_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_tabs.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider slice 2 (D37): the request from its arrival to the offer. p13
// home, p15 lists, p16 new request, p17 offer, p18 apology, p19 answered,
// p20 ended, p45 quick offer. Nothing shows a figure or a promise the server
// does not keep (reasons). Since B2 (D50) a request carries its seven-day
// answer window, an offer its version, and the customer's phone and budget
// reach the provider only when shared.

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
String _day(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

Map<String, dynamic> quoteJson({
  String id = 'quote-1',
  String status = 'SENT',
  String name = 'محمد الحمدي',
  String eventDate = '2027-01-21',
  List<Map<String, dynamic>> offers = const [],
  Map<String, dynamic>? booking,
  DateTime? createdAt,
  bool share = false,
}) => {
  'id': id,
  'providerId': 'provider-1',
  'status': status,
  // B-04: seven days from the request to answer it.
  'expiresAt': (createdAt ?? _now.subtract(const Duration(days: 1)))
      .add(const Duration(days: 7))
      .toUtc()
      .toIso8601String(),
  // B-08: the server sends the phone and the budget only when shared.
  'shareBudget': share,
  'shareContact': share,
  'contactName': name,
  'contactPhone': share ? '777123456' : null,
  'budgetMin': share ? '300000' : null,
  'budgetMax': share ? '600000' : null,
  'guestCount': 124,
  'eventDate': eventDate,
  'message': 'نشتي تصوير الزفة من دخول العريس',
  'location': {'governorate': 'أمانة العاصمة', 'city': 'صنعاء'},
  'service': {
    'id': 'service-1',
    'providerId': 'provider-1',
    'title': 'صور وفيديو',
  },
  'weddingPlan': {'id': 'plan-1', 'title': 'عرس محمد', 'currency': 'YER'},
  'offers': offers,
  'booking': ?booking,
  'createdAt': (createdAt ?? _now.subtract(const Duration(days: 1)))
      .toUtc()
      .toIso8601String(),
  'updatedAt': _now.toUtc().toIso8601String(),
};

Map<String, dynamic> offerJson({
  String id = 'offer-1',
  String status = 'PENDING',
  DateTime? validUntil,
}) => {
  'id': id,
  'status': status,
  'title': 'صور وفيديو',
  'message': 'تصوير ليلة كاملة',
  'amount': '550000',
  'currency': 'YER',
  'validUntil': (validUntil ?? _now.add(const Duration(days: 8)))
      .toUtc()
      .toIso8601String(),
};

Map<String, dynamic> bookingJson({
  String id = 'booking-1',
  String quoteId = 'quote-1',
  String status = 'REQUESTED',
  String? day,
  String name = 'محمد الحمدي',
}) => {
  'id': id,
  'quoteRequestId': quoteId,
  'providerId': 'provider-1',
  'eventDate': day ?? '2027-01-21',
  'status': status,
  'lifecycleStatus': status,
  'customerName': name,
};

void main() {
  group('p13 home', () {
    testWidgets('who waits, since when, and «ردّ الآن» opens the requests', (
      tester,
    ) async {
      final opened = <int>[];
      final api = RequestsApi(
        quotes: [
          quoteJson(),
          quoteJson(id: 'quote-2', name: 'سلمى السقاف', status: 'VIEWED'),
          quoteJson(id: 'quote-3', name: 'عادل الريمي'),
        ],
      );
      await pumpHarness(tester, api, home: (tab) => opened.add(tab));

      expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
      expect(find.text('تصوير · صنعاء'), findsOneWidget);
      expect(find.text('ينتظرونك'), findsOneWidget);
      expect(find.text('3 طلبات ما رديت عليها'), findsOneWidget);
      // B-04: the first of them to end, as p13 draws it.
      expect(find.text('أقدمها من أمس · ينتهي بعد 6 أيام'), findsOneWidget);

      await tester.tap(find.byKey(const Key('provider-home-answer')));
      expect(opened, [1]);
    });

    testWidgets('an accepted offer asks to book, and this week lists the '
        'confirmed weddings', (tester) async {
      final inThree = _today.add(const Duration(days: 3));
      final api = RequestsApi(
        quotes: [
          quoteJson(status: 'ACCEPTED', booking: bookingJson()),
          quoteJson(
            id: 'quote-2',
            name: 'عادل الريمي',
            status: 'ACCEPTED',
            eventDate: _day(inThree),
          ),
        ],
        bookings: [
          bookingJson(),
          bookingJson(
            id: 'booking-2',
            quoteId: 'quote-2',
            status: 'CONFIRMED',
            day: _day(inThree),
            name: 'عادل الريمي',
          ),
        ],
      );
      await pumpHarness(tester, api, home: (_) {});

      expect(find.byKey(const Key('provider-home-none-waiting')), findsOne);
      expect(find.text('محمد قبل عرضك'), findsOneWidget);
      expect(find.text('يشتي يحجز الخميس 21 يناير'), findsOneWidget);
      expect(find.text('عرس عادل الريمي · صور وفيديو'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('provider-home-confirm-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProviderRequestScreen), findsOneWidget);
      expect(
        find.byKey(const Key('provider-booking-confirm-booking-1')),
        findsOne,
      );
    });
  });

  group('p15 requests and p20 ended', () {
    List<Map<String, dynamic>> allStates() => [
      quoteJson(),
      quoteJson(id: 'quote-2', name: 'سلمى السقاف', status: 'VIEWED'),
      quoteJson(
        id: 'quote-3',
        name: 'فهد العمري',
        status: 'ACCEPTED',
        booking: bookingJson(id: 'booking-3', quoteId: 'quote-3'),
      ),
      quoteJson(
        id: 'quote-4',
        name: 'خالد',
        status: 'RESPONDED',
        offers: [offerJson()],
      ),
      quoteJson(
        id: 'quote-5',
        name: 'يحيى',
        status: 'ACCEPTED',
        booking: bookingJson(
          id: 'booking-5',
          quoteId: 'quote-5',
          status: 'CONFIRMED',
        ),
      ),
      quoteJson(id: 'quote-6', name: 'خالد المطري', status: 'CANCELLED'),
      quoteJson(
        id: 'quote-7',
        name: 'عادل',
        status: 'RESPONDED',
        offers: [offerJson(validUntil: _now.subtract(const Duration(days: 1)))],
      ),
      quoteJson(
        id: 'quote-8',
        name: 'فهد',
        status: 'REJECTED',
        offers: [offerJson(status: 'REJECTED')],
      ),
    ];

    testWidgets('the lists are read from the request, offer and booking', (
      tester,
    ) async {
      await pumpHarness(tester, RequestsApi(quotes: allStates()));

      expect(find.text('2 ينتظرون ردك'), findsOneWidget);
      // The booking to confirm is listed without adding to the count.
      expect(find.text('جديد 2'), findsOneWidget);
      expect(find.text('ردّيت 1'), findsOneWidget);
      expect(find.text('محجوز 1'), findsOneWidget);
      expect(find.text('انتهى'), findsOneWidget);
      expect(find.text('محمد الحمدي'), findsOneWidget);
      expect(find.text('الخميس 21 يناير · صور وفيديو'), findsWidgets);
      expect(find.text('أكّد الحجز: يشتي يحجز'), findsOneWidget);
      expect(find.text('قبلوا عرضك'), findsOneWidget);
      // B-04: each new request counts its seven days, as p15 draws it.
      expect(find.text('ردّ: باقي 6 أيام'), findsNWidgets(2));
      expect(find.text('أمس'), findsWidgets);

      await tester.tap(find.byKey(const Key('provider-requests-tab-replied')));
      await tester.pumpAndSettle();
      expect(find.text('خالد'), findsOneWidget);
      expect(find.textContaining('عرضك صالح لين'), findsOneWidget);

      await tester.tap(find.byKey(const Key('provider-requests-tab-ended')));
      await tester.pumpAndSettle();
      expect(find.text('اللي ما كمّل، وليش'), findsOneWidget);
      expect(find.text('عرضك لعادل انتهى'), findsOneWidget);
      expect(find.text('فهد اختار غيرك'), findsOneWidget);
      expect(find.text('خالد المطري لغى الطلب'), findsOneWidget);
      expect(find.text('قبل ما ترد. ما عليك شيء.'), findsOneWidget);
      expect(find.textContaining('السبب'), findsNothing);
      expect(find.textContaining('بدون رد'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-offer-renew-quote-7')));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderOfferScreen), findsOneWidget);
      expect(
        find.byKey(const Key('provider-offer-validity-keep')),
        findsNothing,
      );
    });

    testWidgets('a card opens its request', (tester) async {
      await pumpHarness(tester, RequestsApi(quotes: [quoteJson()]));
      await tester.tap(find.byKey(const Key('provider-request-quote-1')));
      await tester.pumpAndSettle();
      expect(find.text('طلب جديد'), findsOneWidget);
    });
  });

  group('p16 new request and p18 apology', () {
    testWidgets('shows what the server holds, never his phone or budget', (
      tester,
    ) async {
      final api = RequestsApi(quotes: [quoteJson()]);
      await pumpHarness(tester, api, initial: '/provider/requests/quote-1');

      expect(find.text('طلب جديد'), findsOneWidget);
      expect(find.textContaining('وصل أمس'), findsOneWidget);
      expect(find.text('محمد الحمدي'), findsOneWidget);
      expect(find.textContaining('الخميس 21 يناير'), findsOneWidget);
      expect(find.textContaining('أمانة العاصمة'), findsOneWidget);
      expect(find.text('124 تقريبًا'), findsOneWidget);
      expect(find.text('صور وفيديو'), findsOneWidget);
      expect(find.text('«نشتي تصوير الزفة من دخول العريس»'), findsOneWidget);
      expect(find.text('يوم الخميس فاضي عندك'), findsOneWidget);
      expect(find.textContaining('777123456'), findsNothing);
      expect(find.textContaining('300'), findsNothing);
      expect(find.text('المناسبة'), findsNothing);
      expect(find.text('الفترة'), findsNothing);
      expect(api.statusUpdates, ['quote-1:VIEWED']);

      await tester.tap(find.byKey(const Key('provider-request-ask')));
      await tester.pumpAndSettle();
      expect(find.text('محادثة الطلب quote-1'), findsOneWidget);
    });

    testWidgets('a confirmed booking on that day is said, at day level', (
      tester,
    ) async {
      final api = RequestsApi(
        quotes: [quoteJson()],
        bookings: [
          bookingJson(id: 'booking-9', quoteId: 'quote-9', status: 'CONFIRMED'),
        ],
      );
      await pumpHarness(tester, api, initial: '/provider/requests/quote-1');
      expect(find.text('يوم الخميس عندك حجز مؤكد'), findsOneWidget);
    });

    testWidgets('the apology goes to the chat, declines, and closes the day', (
      tester,
    ) async {
      final api = RequestsApi(quotes: [quoteJson()]);
      final chat = await pumpHarness(tester, api);
      await tester.tap(find.byKey(const Key('provider-request-quote-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider-quote-decline-quote-1')));
      await tester.pumpAndSettle();
      expect(find.text('تعتذر من محمد؟'), findsOneWidget);
      expect(find.text('ونقفل ليلة الخميس في تقويمك'), findsOneWidget);

      // Nothing is sent before a reason is picked.
      await tester.tap(find.byKey(const Key('provider-quote-decline-confirm')));
      await tester.pumpAndSettle();
      expect(chat.sent, isEmpty);

      await tester.tap(find.byKey(const Key('provider-decline-busy')));
      await tester.pumpAndSettle();
      expect(
        find.text('«نعتذر، ما نقدر ليلة 21 يناير. الله يتمم لك على خير.»'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('provider-quote-decline-confirm')));
      await tester.pumpAndSettle();

      expect(chat.sent, [
        'quote-1:نعتذر، ما نقدر ليلة 21 يناير. الله يتمم لك على خير.',
      ]);
      expect(api.statusUpdates, ['quote-1:VIEWED', 'quote-1:REJECTED']);
      expect(api.blocked, [DateTime(2027, 1, 21)]);
      expect(find.byType(ProviderRequestScreen), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('another reason sends its line and closes no day', (
      tester,
    ) async {
      final api = RequestsApi(quotes: [quoteJson()]);
      final chat = await pumpHarness(
        tester,
        api,
        initial: '/provider/requests/quote-1',
      );
      await tester.tap(find.byKey(const Key('provider-quote-decline-quote-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-decline-area')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-quote-decline-confirm')));
      await tester.pumpAndSettle();

      expect(chat.sent.single, contains('خارج منطقة شغلنا'));
      expect(api.blocked, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed line declines nothing', (tester) async {
      final api = RequestsApi(quotes: [quoteJson()]);
      final chat = await pumpHarness(
        tester,
        api,
        initial: '/provider/requests/quote-1',
      );
      chat.failSend = true;
      await tester.tap(find.byKey(const Key('provider-quote-decline-quote-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-decline-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-quote-decline-confirm')));
      await tester.pumpAndSettle();

      expect(api.statusUpdates, ['quote-1:VIEWED']);
      expect(find.text('ما وصلت الرسالة'), findsOneWidget);
    });
  });

  group('p17 offer', () {
    testWidgets('a package fills the title and price; the preview sends it', (
      tester,
    ) async {
      final api = RequestsApi(quotes: [quoteJson()], packages: packages);
      await pumpHarness(
        tester,
        api,
        initial: '/provider/requests/quote-1/offer',
      );

      expect(find.text('عرضك لمحمد'), findsOneWidget);
      expect(find.text('ر.ي'), findsOneWidget);
      expect(find.text('الدفعة المقدمة'), findsNothing);
      expect(find.text('الباقي'), findsNothing);
      expect(find.text('مخصص'), findsOneWidget);
      // A package in another currency cannot price this plan's offer.
      expect(find.text('باقة بالريال السعودي'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-offer-package-pkg-2')));
      await tester.pumpAndSettle();
      expect(find.text('550,000'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('provider-offer-message')),
        '300 صورة معدّلة وفيلم 10 دقايق. الدرون مو داخل.',
      );
      await tester.tap(find.byKey(const Key('provider-offer-preview')));
      await tester.pumpAndSettle();
      expect(find.text('كذا يوصل محمد'), findsOneWidget);
      expect(find.text('550,000 ر.ي'), findsOneWidget);

      final before = DateTime.now();
      await tester.tap(find.byKey(const Key('provider-offer-submit')));
      await tester.pumpAndSettle();
      final created = api.created.single;
      expect(created.title, 'صور وفيديو');
      expect(created.amount, '550000');
      expect(created.currency, 'YER');
      expect(
        created.validUntil!
            .difference(before.add(const Duration(days: 10)))
            .inMinutes
            .abs(),
        lessThan(2),
      );
      expect(find.byType(ProviderOfferScreen), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an empty price or message is named, nothing is sent', (
      tester,
    ) async {
      final api = RequestsApi(quotes: [quoteJson()]);
      await pumpHarness(
        tester,
        api,
        initial: '/provider/requests/quote-1/offer',
      );
      await tester.tap(find.byKey(const Key('provider-offer-preview')));
      await tester.pumpAndSettle();
      expect(find.text('اكتب سعر العرض.'), findsOneWidget);
      expect(find.text('اكتب ايش يشمل العرض.'), findsOneWidget);
      expect(find.text('كذا يوصل محمد'), findsNothing);
      expect(api.created, isEmpty);
    });
  });

  group('p19 answered', () {
    testWidgets('the offer, its version, its end date, the edit and the '
        'withdrawal; no seen line', (tester) async {
      final api = RequestsApi(
        quotes: [
          quoteJson(status: 'RESPONDED', offers: [offerJson()]),
        ],
      );
      await pumpHarness(tester, api, initial: '/provider/requests/quote-1');

      expect(find.text('محمد الحمدي'), findsOneWidget);
      expect(find.text('الخميس 21 يناير · صور وفيديو'), findsOneWidget);
      expect(find.text('ردّيت'), findsOneWidget);
      // B-06: p19 «550,000 ر.ي · نسخة 1».
      expect(find.text('550,000 ر.ي · نسخة 1'), findsOneWidget);
      expect(find.textContaining('صالح لين'), findsOneWidget);
      expect(find.textContaining('باقي 8 أيام'), findsOneWidget);
      expect(find.text('عدّل العرض'), findsOneWidget);
      expect(find.text('اسحب العرض'), findsOneWidget);
      expect(
        find.text(
          'التعديل يوصله نسخة 2 فيها «ايش تغيّر». والسحب يقفل العرض ويوصله سطر هادي.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('شافه'), findsNothing);
      expect(
        find.byKey(const Key('provider-quote-decline-quote-1')),
        findsNothing,
      );
      expect(api.statusUpdates, isEmpty);
    });

    testWidgets('«اسحب العرض» asks first, then the request is new again with '
        'seven days (B-03)', (tester) async {
      final api = RequestsApi(
        quotes: [
          quoteJson(status: 'RESPONDED', offers: [offerJson()]),
        ],
      );
      await pumpHarness(tester, api, initial: '/provider/requests/quote-1');

      await tester.tap(
        find.byKey(const Key('provider-offer-withdraw-quote-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('تسحب عرضك لمحمد؟'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-offer-withdraw-keep')));
      await tester.pumpAndSettle();
      expect(api.withdrawn, isEmpty);

      await tester.tap(
        find.byKey(const Key('provider-offer-withdraw-quote-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('provider-offer-withdraw-confirm')),
      );
      await tester.pumpAndSettle();
      expect(api.withdrawn, ['offer-1']);
      // The request is p16 again, with what happened and his new deadline.
      expect(find.text('طلب جديد'), findsOneWidget);
      expect(
        find.byKey(const Key('provider-request-withdrawn')),
        findsOneWidget,
      );
      expect(find.textContaining('سحبت عرضك اليوم.'), findsOneWidget);
    });
  });

  group('B-04 and B-08 on p15, p16 and p20', () {
    testWidgets('a new request counts its days left, and an unanswered one '
        'ends in «انتهى»', (tester) async {
      final api = RequestsApi(
        quotes: [
          quoteJson(),
          quoteJson(id: 'quote-2', name: 'يحيى السنيدار', status: 'EXPIRED'),
        ],
      );
      await pumpHarness(tester, api);

      expect(find.text('ردّ: باقي 6 أيام'), findsOneWidget);
      await tester.tap(find.text('انتهى').first);
      await tester.pumpAndSettle();
      expect(find.text('طلب يحيى السنيدار انتهى بدون رد'), findsOneWidget);
      expect(
        find.text('7 أيام ما رديت. هذا ينحسب في سرعة ردك.'),
        findsOneWidget,
      );
    });

    testWidgets('p16 says what was not shared, and shows what was', (
      tester,
    ) async {
      final api = RequestsApi(
        quotes: [
          quoteJson(),
          quoteJson(id: 'quote-2', name: 'عادل الريمي', share: true),
        ],
      );
      await pumpHarness(tester, api, initial: '/provider/requests/quote-1');
      expect(
        find.text(
          'ميزانيته ورقمه ما يوصلونك إلا إذا شاركهم. تكلّم معه من «اسأل».',
        ),
        findsOneWidget,
      );
      expect(find.text('ميزانيته'), findsNothing);

      final shared = RequestsApi(
        quotes: [quoteJson(id: 'quote-2', name: 'عادل الريمي', share: true)],
      );
      await pumpHarness(tester, shared, initial: '/provider/requests/quote-2');
      expect(find.text('300,000 لين 600,000 ر.ي'), findsOneWidget);
      expect(find.text('777123456'), findsOneWidget);
      expect(find.byKey(const Key('provider-request-privacy')), findsNothing);
    });
  });

  group('p45 quick offer', () {
    testWidgets('a package answers a new request in one tap', (tester) async {
      final api = RequestsApi(quotes: [quoteJson()], packages: packages);
      await pumpHarness(tester, api);

      // B-04: the quick line keeps the days left of the request.
      expect(find.text('ردّ سريع: باقي 6 أيام'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-quick-offer-quote-1')));
      await tester.pumpAndSettle();
      expect(find.text('رد سريع'), findsOneWidget);
      expect(find.text('صور فقط · 350,000'), findsOneWidget);
      expect(find.text('صور وفيديو · 550,000'), findsOneWidget);
      expect(find.textContaining('آخر 5'), findsNothing);
      expect(find.textContaining('سعر الموسم'), findsNothing);
      expect(api.statusUpdates, ['quote-1:VIEWED']);

      await tester.tap(
        find.byKey(const Key('provider-quick-offer-package-pkg-2')),
      );
      await tester.pumpAndSettle();
      final before = DateTime.now();
      await tester.tap(find.byKey(const Key('provider-quick-offer-send')));
      await tester.pumpAndSettle();

      final created = api.created.single;
      expect(created.title, 'صور وفيديو');
      expect(created.amount, '550000');
      expect(created.message, 'تصوير ليلة كاملة بالفيديو');
      expect(
        created.validUntil!
            .difference(before.add(const Duration(days: 10)))
            .inMinutes
            .abs(),
        lessThan(2),
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('without a package the card simply opens the request', (
      tester,
    ) async {
      await pumpHarness(tester, RequestsApi(quotes: [quoteJson()]));
      expect(find.text('ردّ: باقي 6 أيام'), findsOneWidget);
      expect(
        find.byKey(const Key('provider-quick-offer-quote-1')),
        findsNothing,
      );
    });
  });
}

const packages = [
  ProviderPackage(
    id: 'pkg-1',
    providerId: 'provider-1',
    title: 'صور فقط',
    isActive: true,
    price: '350000',
    currency: 'YER',
    description: 'تصوير الليلة',
  ),
  ProviderPackage(
    id: 'pkg-2',
    providerId: 'provider-1',
    title: 'صور وفيديو',
    isActive: true,
    price: '550000',
    currency: 'YER',
    description: 'تصوير ليلة كاملة بالفيديو',
  ),
  ProviderPackage(
    id: 'pkg-3',
    providerId: 'provider-1',
    title: 'باقة بالريال السعودي',
    isActive: true,
    price: '5000',
    currency: 'SAR',
  ),
];

typedef CreatedOffer = ({
  String? title,
  String message,
  String amount,
  String currency,
  DateTime? validUntil,
});

/// Pumps the provider's request screens behind a router: `/` holds the
/// requests tab, `/home` the home tab (when [home] is given).
Future<RecordingChatProvider> pumpHarness(
  WidgetTester tester,
  RequestsApi api, {
  String initial = '/',
  ValueChanged<int>? home,
  Size size = const Size(420, 1400),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final chat = RecordingChatProvider(storage);
  addTearDown(chat.dispose);
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  final router = GoRouter(
    initialLocation: home == null ? initial : '/home',
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
        path: '/home',
        builder: (_, _) => Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderHomeTab(onOpenTab: home ?? (_) {}),
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
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('التنبيهات')),
      ),
      GoRoute(
        path: '/provider/notifications',
        builder: (_, _) => const Scaffold(body: Text('تنبيهات المزود')),
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
  return chat;
}

/// Records the lines sent to a request's chat.
class RecordingChatProvider extends ChatProvider {
  RecordingChatProvider(AuthStorage storage)
    : super(
        api: ChatApi(ApiClient(tokenProvider: () async => null)),
        realtime: ChatRealtimeClient(storage),
        authStorage: storage,
      );

  final sent = <String>[];
  bool failSend = false;

  @override
  List<ChatConversation> get conversations => const [];

  @override
  String? get errorMessage => failSend ? 'ما وصلت الرسالة' : null;

  @override
  Future<void> initialize() async {}

  @override
  Future<ChatConversation?> openQuote(String quoteRequestId) async =>
      ChatConversation.fromJson({
        'id': 'chat-$quoteRequestId',
        'canSend': true,
      });

  @override
  Future<bool> send(
    String conversationId,
    String body, {
    List<MediaUploadTicket> attachments = const [],
  }) async {
    if (failSend) return false;
    sent.add('${conversationId.replaceFirst('chat-', '')}:$body');
    return true;
  }
}

class RequestsApi extends ProviderDashboardApi {
  RequestsApi({
    List<Map<String, dynamic>> quotes = const [],
    this.bookings = const [],
    this.packages = const [],
  }) : _quotes = [for (final quote in quotes) Map.of(quote)],
       super(ApiClient(tokenProvider: () async => null));

  final List<Map<String, dynamic>> _quotes;
  final List<Map<String, dynamic>> bookings;
  final List<ProviderPackage> packages;
  final statusUpdates = <String>[];
  final created = <CreatedOffer>[];
  final blocked = <DateTime>[];
  final withdrawn = <String>[];

  /// B-03 as the server does it: the offer is taken back and the request
  /// waits for the provider again, seven days from now.
  @override
  Future<QuoteRequest> withdrawQuoteOffer({
    required String quoteOfferId,
    String? reason,
  }) async {
    withdrawn.add(quoteOfferId);
    final quote = _quotes.firstWhere(
      (item) => (item['offers'] as List).any(
        (offer) => (offer as Map)['id'] == quoteOfferId,
      ),
    );
    final now = DateTime.now();
    quote['status'] = 'VIEWED';
    quote['expiresAt'] = now
        .add(const Duration(days: 7))
        .toUtc()
        .toIso8601String();
    quote['offers'] = [
      for (final offer in quote['offers'] as List)
        (offer as Map)['id'] == quoteOfferId
            ? {
                ...Map<String, dynamic>.from(offer),
                'status': 'WITHDRAWN',
                'withdrawnAt': now.toUtc().toIso8601String(),
              }
            : offer,
    ];
    return QuoteRequest.fromJson(quote);
  }

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استوديو ضوء صنعاء',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
        city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
        primaryCategory: ProviderCategory(id: 'cat-1', nameAr: 'تصوير'),
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.empty();

  @override
  Future<List<MarketplaceService>> getServices() async => const [];

  @override
  Future<List<ProviderPackage>> getPackages() async => packages;

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => [
    for (final quote in _quotes) QuoteRequest.fromJson(quote),
  ];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async => [
    for (final booking in bookings) MarketplaceBooking.fromJson(booking),
  ];

  @override
  Future<List<DateTime>> getBlockedDates() async => blocked;

  @override
  Future<void> blockDate(DateTime day) async =>
      blocked.add(DateTime(day.year, day.month, day.day));

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
    if (blockDay) {
      final day = DateTime.parse(quote['eventDate'].toString());
      blocked.add(DateTime(day.year, day.month, day.day));
    }
    return QuoteRequest.fromJson(quote);
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
  }) async {
    created.add((
      title: title,
      message: message,
      amount: amount,
      currency: currency,
      validUntil: validUntil,
    ));
    final quote = _quotes.firstWhere((item) => item['id'] == quoteRequestId);
    quote['status'] = 'RESPONDED';
    quote['offers'] = [
      {
        'id': 'offer-new',
        'status': 'PENDING',
        'title': title,
        'message': message,
        'amount': amount,
        'currency': currency,
        'validUntil': validUntil?.toUtc().toIso8601String(),
      },
    ];
    return QuoteOffer.fromJson({'id': 'offer-new', 'status': 'PENDING'});
  }
}
