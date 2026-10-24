import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_tabs.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_services_screen.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_calendar_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'provider_requests_test.dart' show RequestsApi, bookingJson, quoteJson;

// Provider slice 3 (D39): p28 the month at day level and p29 one day. A day
// is booked, waiting for his confirmation, closed or free; no «باقي N», no
// team, no period, no outside booking (D-2).

final _today = providerToday();
final _next = DateTime(_today.year, _today.month + 1);
DateTime _nextDay(int day) => DateTime(_next.year, _next.month, day);
String _day(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class CalendarApi extends RequestsApi {
  CalendarApi({
    super.quotes,
    super.bookings,
    List<DateTime> closed = const [],
  }) {
    blocked.addAll(closed);
  }

  final unblocked = <DateTime>[];

  @override
  Future<List<DateTime>> getBlockedDates() async => [...blocked];

  @override
  Future<void> unblockDate(DateTime day) async {
    unblocked.add(day);
    blocked.removeWhere((closed) => providerSameDay(closed, day));
  }
}

CalendarApi _api() => CalendarApi(
  quotes: [
    quoteJson(
      status: 'ACCEPTED',
      eventDate: _day(_nextDay(10)),
      booking: bookingJson(status: 'CONFIRMED', day: _day(_nextDay(10))),
    ),
    quoteJson(
      id: 'quote-2',
      name: 'سلمى السقاف',
      status: 'ACCEPTED',
      eventDate: _day(_nextDay(12)),
      booking: bookingJson(
        id: 'booking-2',
        quoteId: 'quote-2',
        day: _day(_nextDay(12)),
        name: 'سلمى السقاف',
      ),
    ),
  ],
  bookings: [
    bookingJson(status: 'CONFIRMED', day: _day(_nextDay(10))),
    bookingJson(
      id: 'booking-2',
      quoteId: 'quote-2',
      day: _day(_nextDay(12)),
      name: 'سلمى السقاف',
    ),
  ],
  closed: [_nextDay(14)],
);

Future<ProviderDashboardProvider> _pump(
  WidgetTester tester,
  CalendarApi api,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderCalendarTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/provider/requests/:id',
        builder: (_, state) =>
            Scaffold(body: Text('طلب ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ProviderDashboardProvider>.value(
      value: dashboard,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return dashboard;
}

Future<void> _toNextMonth(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('provider-calendar-next')));
  await tester.pumpAndSettle();
}

Finder _cell(int day) => find.byKey(Key('provider-calendar-day-$day'));

void main() {
  group('p28 month', () {
    testWidgets('each day reads booked, waiting, closed or free; no capacity', (
      tester,
    ) async {
      await _pump(tester, _api());
      expect(find.text('التقويم'), findsOneWidget);
      expect(find.text('أقفل أيام'), findsOneWidget);
      expect(find.text('حجز من برا'), findsNothing);
      expect(find.textContaining('باقي'), findsNothing);
      expect(find.textContaining('حدّثته'), findsNothing);

      await _toNextMonth(tester);
      expect(find.textContaining(providerMonthLabel(_next)), findsOneWidget);
      expect(
        find.descendant(of: _cell(10), matching: find.text('محجوز')),
        findsOne,
      );
      expect(
        find.descendant(of: _cell(12), matching: find.text('ينتظرك')),
        findsOne,
      );
      expect(
        find.descendant(of: _cell(14), matching: find.text('مقفول')),
        findsOne,
      );
      expect(
        find.descendant(of: _cell(15), matching: find.byType(Text)),
        findsOne,
      );
      // The legend names the three states shown.
      expect(find.text('طلب ينتظرك'), findsOneWidget);
      expect(find.text('فيه فرق فاضية'), findsNothing);
    });

    testWidgets('the month before this one is not offered', (tester) async {
      await _pump(tester, _api());
      final previous = tester.widget<JourneyRoundButton>(
        find.byKey(const Key('provider-calendar-previous')),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('«أقفل أيام» closes the days picked, together', (tester) async {
      final api = _api();
      await _pump(tester, api);
      await _toNextMonth(tester);
      await tester.tap(find.byKey(const Key('provider-calendar-close-days')));
      await tester.pumpAndSettle();
      expect(find.text('اختر الأيام اللي تقفلها'), findsOneWidget);

      // A booked or closed day cannot be picked.
      await tester.tap(_cell(10));
      await tester.tap(_cell(14));
      await tester.tap(_cell(20));
      await tester.tap(_cell(21));
      await tester.pumpAndSettle();
      expect(find.text('أقفل يومين'), findsOneWidget);

      await tester.tap(find.byKey(const Key('provider-calendar-close-picked')));
      await tester.pumpAndSettle();
      expect(
        api.blocked.where((day) => day.month == _next.month).map((d) => d.day),
        unorderedEquals([14, 20, 21]),
      );
      expect(find.text('أقفل أيام'), findsOneWidget);
      expect(
        find.descendant(of: _cell(20), matching: find.text('مقفول')),
        findsOne,
      );
    });
  });

  group('p29 day', () {
    testWidgets('a free day closes from its sheet', (tester) async {
      final api = _api();
      await _pump(tester, api);
      await _toNextMonth(tester);
      await tester.tap(_cell(15));
      await tester.pumpAndSettle();
      expect(find.textContaining('· فاضي'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-day-close')));
      await tester.pumpAndSettle();
      expect(api.blocked.any((d) => providerSameDay(d, _nextDay(15))), isTrue);
      expect(find.byKey(const Key('provider-day-close')), findsNothing);
    });

    testWidgets('a closed day opens again', (tester) async {
      final api = _api();
      await _pump(tester, api);
      await _toNextMonth(tester);
      await tester.tap(_cell(14));
      await tester.pumpAndSettle();
      expect(find.textContaining('قفلته في تقويمك'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-day-open')));
      await tester.pumpAndSettle();
      expect(api.unblocked.single, _nextDay(14));
      expect(
        find.descendant(of: _cell(14), matching: find.text('مقفول')),
        findsNothing,
      );
    });

    testWidgets('a booked day shows its booking, cannot close, and opens it', (
      tester,
    ) async {
      await _pump(tester, _api());
      await _toNextMonth(tester);
      await tester.tap(_cell(10));
      await tester.pumpAndSettle();
      expect(find.textContaining('عندك حجز مؤكد'), findsOneWidget);
      expect(find.text('عرس محمد الحمدي'), findsOneWidget);
      expect(find.byKey(const Key('provider-day-close')), findsNothing);
      expect(find.textContaining('فريق'), findsNothing);
      await tester.tap(find.byKey(const Key('provider-day-booking-booking-1')));
      await tester.pumpAndSettle();
      expect(find.text('طلب quote-1'), findsOneWidget);
    });

    testWidgets('a waiting day shows the request to confirm', (tester) async {
      await _pump(tester, _api());
      await _toNextMonth(tester);
      await tester.tap(_cell(12));
      await tester.pumpAndSettle();
      expect(find.textContaining('طلب ينتظر تأكيدك'), findsOneWidget);
      expect(find.text('عرس سلمى السقاف'), findsOneWidget);
      expect(find.text('ينتظر تأكيدك'), findsOneWidget);
    });
  });

  testWidgets('«ملفي» opens his services, which left the bottom bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);
    final dashboard = ProviderDashboardProvider(CalendarApi());
    await dashboard.loadDashboard();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: ProviderProfileTab()),
        ),
        GoRoute(
          path: '/provider/services',
          builder: (_, _) => const Scaffold(body: Text('خدماتك')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderDashboardProvider>.value(
        value: dashboard,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('أضف خدماتك وأسعارك'), findsOneWidget);
    await tester.tap(find.byKey(const Key('provider-profile-services')));
    await tester.pumpAndSettle();
    expect(find.text('خدماتك'), findsOneWidget);
  });

  testWidgets('his services open as their own page', (tester) async {
    final dashboard = ProviderDashboardProvider(CalendarApi());
    await dashboard.loadDashboard();
    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderDashboardProvider>.value(
        value: dashboard,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProviderServicesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // p36 (D40) rebuilt the page the services list was parked on.
    expect(find.text('خدماتك'), findsOneWidget);
    expect(find.byKey(const Key('provider-services-empty')), findsOneWidget);
    expect(find.byTooltip('رجوع'), findsOneWidget);
  });
}
