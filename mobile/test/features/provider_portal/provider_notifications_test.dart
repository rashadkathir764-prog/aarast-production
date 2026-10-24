import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'provider_requests_test.dart'
    show RequestsApi, bookingJson, offerJson, pumpHarness, quoteJson;

// Provider slice 3 (D39): p42, his notices, each opening its case. Lines
// are written from the request the notice names; deposit, postpone, hold
// and review notices do not exist and are never shown.

AarastNotification _notice(
  String id,
  String type, {
  String title = 'عنوان',
  String body = 'نص',
  String? quoteId = 'quote-1',
  String audience = 'PROVIDER',
  String routeTarget = '/provider/dashboard',
  Map<String, dynamic> extra = const {},
  bool read = false,
}) => AarastNotification.fromJson({
  'id': id,
  'userId': 'provider-user',
  'type': type,
  'title': title,
  'body': body,
  'routeTarget': routeTarget,
  'data': {'quoteRequestId': ?quoteId, 'recipientAudience': audience, ...extra},
  'readAt': read ? '2026-10-01T10:00:00.000Z' : null,
  'createdAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T09:00:00.000Z',
});

class _NoticesApi extends NotificationsApi {
  _NoticesApi(this.items) : super(ApiClient(tokenProvider: () async => null));

  final List<AarastNotification> items;
  final read = <String>[];

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async => NotificationsPage(
    items: items,
    page: 1,
    limit: limit,
    total: items.length,
    totalPages: 1,
    hasMore: false,
  );

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async =>
      items.where((item) => item.isUnread).length;

  @override
  Future<AarastNotification> markRead(String id) async {
    read.add(id);
    final index = items.indexWhere((item) => item.id == id);
    final updated = items[index].copyWith(readAt: DateTime(2026, 10, 2));
    items[index] = updated;
    return updated;
  }
}

RequestsApi _requests() {
  final asked = bookingJson(id: 'booking-2', quoteId: 'quote-2');
  return RequestsApi(
    quotes: [
      quoteJson(name: 'سلمى السقاف'),
      quoteJson(
        id: 'quote-2',
        status: 'ACCEPTED',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: asked,
      ),
      quoteJson(
        id: 'quote-3',
        name: 'فهد العمري',
        status: 'ACCEPTED',
        eventDate: '2027-02-04',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: bookingJson(
          id: 'booking-3',
          quoteId: 'quote-3',
          status: 'CANCELLED',
          day: '2027-02-04',
        ),
      ),
    ],
    bookings: [asked],
  );
}

Future<_NoticesApi> _pump(
  WidgetTester tester,
  List<AarastNotification> items,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1200);
  addTearDown(tester.view.reset);
  final api = _NoticesApi(items);
  final notices = NotificationsProvider(api);
  final dashboard = ProviderDashboardProvider(_requests());
  await dashboard.loadDashboard();
  final router = GoRouter(
    initialLocation: '/notices',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/notices',
        builder: (_, _) => const ProviderNotificationsScreen(),
      ),
      GoRoute(
        path: '/provider/requests/:id',
        builder: (_, state) =>
            Scaffold(body: Text('طلب ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, state) =>
            Scaffold(body: Text('محادثة ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationsProvider>.value(value: notices),
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('his notices read from their requests; the groom\'s are not '
      'here', (tester) async {
    await _pump(tester, [
      _notice('n1', 'QUOTE_REQUEST_SUBMITTED'),
      _notice(
        'n2',
        'BOOKING_UPDATED',
        title: 'طلب حجز جديد',
        quoteId: 'quote-2',
        extra: {'bookingId': 'booking-2'},
      ),
      _notice(
        'n3',
        'BOOKING_UPDATED',
        title: 'أُلغي حجز',
        quoteId: 'quote-3',
        read: true,
      ),
      _notice('n4', 'QUOTE_ACCEPTED', quoteId: 'quote-2', read: true),
      _notice(
        'n5',
        'BOOKING_UPDATED',
        title: 'تذكير بحجز',
        quoteId: 'quote-2',
        extra: {'daysUntil': 1},
        read: true,
      ),
      _notice(
        'n6',
        'QUOTE_OFFER_RECEIVED',
        title: 'وصل عرض سعر',
        audience: 'CUSTOMER',
      ),
    ]);

    expect(find.text('التنبيهات'), findsOne);
    expect(find.text('كل واحد يفتح طلبه'), findsOne);
    expect(find.text('طلب جديد من سلمى'), findsOne);
    expect(find.text('صور وفيديو · 21 يناير'), findsWidgets);
    expect(find.text('محمد يشتي يحجز'), findsOne);
    expect(find.text('أكّد الحجز'), findsWidgets);
    expect(find.text('فهد لغى الحجز'), findsOne);
    expect(find.text('4 فبراير · الحجز انلغى'), findsOne);
    expect(find.text('محمد قبل عرضك'), findsOne);
    expect(find.text('عرس محمد بكرة'), findsOne);
    // The customer's notice stays on his own list.
    expect(find.text('وصل عرض سعر'), findsNothing);
    // Unread ones carry the dot.
    expect(find.byKey(const Key('provider-notice-unread-n1')), findsOne);
    expect(find.byKey(const Key('provider-notice-unread-n3')), findsNothing);
    for (final missing in ['دفعة', 'أجّل', 'المبدئي', 'تقييم']) {
      expect(find.textContaining(missing), findsNothing, reason: missing);
    }
  });

  testWidgets('a notice is read and opens its request', (tester) async {
    final api = await _pump(tester, [
      _notice(
        'n2',
        'BOOKING_UPDATED',
        title: 'طلب حجز جديد',
        quoteId: 'quote-2',
        extra: {'bookingId': 'booking-2'},
      ),
    ]);
    await tester.tap(find.byKey(const Key('provider-notice-n2')));
    await tester.pumpAndSettle();
    expect(api.read, ['n2']);
    expect(find.text('طلب quote-2'), findsOne);
  });

  testWidgets('a message opens its chat', (tester) async {
    await _pump(tester, [
      _notice(
        'n7',
        'CHAT_MESSAGE_RECEIVED',
        quoteId: null,
        routeTarget: '/conversations/chat-1',
        extra: {'conversationId': 'chat-1'},
      ),
    ]);
    expect(find.text('رسالة جديدة'), findsOne);
    await tester.tap(find.byKey(const Key('provider-notice-n7')));
    await tester.pumpAndSettle();
    expect(find.text('محادثة chat-1'), findsOne);
  });

  testWidgets('a request not in his list keeps the server\'s words', (
    tester,
  ) async {
    await _pump(tester, [
      _notice(
        'n8',
        'QUOTE_REQUEST_SUBMITTED',
        title: 'طلب عرض سعر جديد',
        body: 'وصلك طلب عرض سعر جديد.',
        quoteId: 'quote-gone',
      ),
    ]);
    expect(find.text('طلب عرض سعر جديد'), findsOne);
    expect(find.text('وصلك طلب عرض سعر جديد.'), findsOne);
  });

  testWidgets('the home bell opens his notices', (tester) async {
    await pumpHarness(tester, _requests(), home: (_) {});
    await tester.tap(find.byKey(const Key('provider-home-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('تنبيهات المزود'), findsOne);
  });

  testWidgets('with no notice, it says so', (tester) async {
    await _pump(tester, []);
    expect(find.text('ما وصلك تنبيه لسا'), findsOne);
  });
}
