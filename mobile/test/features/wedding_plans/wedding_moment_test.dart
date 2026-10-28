import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/plan_bookings_lookup.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_moment_ledger.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_moment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D65: y06 «دخلت أسبوع عرسك» and y07 «اليوم عرسك», once per phone.

class _Api extends PlanEventsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<PlanEventsView> list(String weddingPlanId) async =>
      PlanEventsView.fromJson({
        'weddingPlanId': 'plan-1',
        'canEdit': true,
        'items': [
          {
            'id': 's',
            'type': 'SAMRA',
            'date': '2027-01-19',
            'timeSlot': 'AFTER_ISHA',
            'placeLabel': 'الديوان',
          },
          {
            'id': 'l',
            'type': 'LUNCH',
            'date': '2027-01-21',
            'timeSlot': 'DHUHR',
            'placeLabel': 'بيت الوالد',
          },
          {
            'id': 'w',
            'type': 'WEDDING',
            'date': '2027-01-21',
            'timeSlot': 'AFTER_ASR',
            'placeLabel': 'قاعة سبأ',
          },
        ],
        'suggestions': const [],
      });
}

Future<List<String>> _pump(WidgetTester tester, WeddingMoment moment) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final provider = PlanEventsProvider(api: _Api());
  await provider.load('plan-1');
  final opened = <String>[];
  final router = GoRouter(
    initialLocation: '/moment',
    routes: [
      GoRoute(
        path: '/moment',
        builder: (_, _) => WeddingMomentScreen(
          weddingPlanId: 'plan-1',
          moment: moment,
          loadBookings: (_) async => [
            PlanBookingDay(
              providerName: 'قاعة سبأ',
              eventDate: DateTime(2027, 1, 21),
              confirmed: true,
            ),
            PlanBookingDay(
              providerName: 'فرقة الأفراح',
              eventDate: DateTime(2027, 1, 21),
              confirmed: false,
            ),
          ],
        ),
      ),
    ],
    errorBuilder: (context, state) {
      opened.add(state.uri.toString());
      return const SizedBox.shrink();
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<PlanEventsProvider>.value(
      value: provider,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('each moment shows once per phone for its plan and date', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = WeddingMomentLedger(await SharedPreferences.getInstance());
    final date = DateTime(2027, 1, 21);
    expect(await ledger.firstTime('plan-1', WeddingMoment.week, date), isTrue);
    expect(await ledger.firstTime('plan-1', WeddingMoment.week, date), isFalse);
    expect(await ledger.firstTime('plan-1', WeddingMoment.day, date), isTrue);
    // A postponed wedding is greeted again in its new week.
    expect(
      await ledger.firstTime(
        'plan-1',
        WeddingMoment.week,
        DateTime(2027, 2, 4),
      ),
      isTrue,
    );
  });

  testWidgets('y06: the week\'s events and the providers who confirmed', (
    tester,
  ) async {
    pinAppClock(DateTime(2027, 1, 14, 9));
    final opened = await _pump(tester, WeddingMoment.week);

    expect(find.text('الخميس 14 يناير'), findsOneWidget);
    expect(find.text('دخلت أسبوع عرسك'), findsOneWidget);
    expect(
      find.text('سبعة أيام على عرسك.\nمن اليوم الرئيسية تمشي معك ليلة ليلة.'),
      findsOneWidget,
    );
    expect(find.text('السمرة'), findsOneWidget);
    expect(find.text('الثلاثاء · الديوان'), findsOneWidget);
    expect(find.text('الزفاف'), findsOneWidget);
    expect(find.text('الخميس · قاعة سبأ'), findsOneWidget);
    expect(find.text('1 من 2 أكّدوا'), findsOneWidget);
    // No source for the cash of the nights: no row is invented.
    expect(find.text('الكاش'), findsNothing);

    await tester.tap(find.text('وريني برنامج الأسبوع'));
    await tester.pumpAndSettle();
    expect(opened, ['/wedding-plans/plan-1/dashboard']);
  });

  testWidgets('y07: the day\'s programme by its time', (tester) async {
    pinAppClock(DateTime(2027, 1, 21, 8));
    await _pump(tester, WeddingMoment.day);

    expect(find.text('اليوم عرسك'), findsOneWidget);
    expect(
      find.text('بارك الله لكما، وبارك عليكما،\nوجمع بينكما في خير.'),
      findsOneWidget,
    );
    expect(find.text('الغداء'), findsOneWidget);
    expect(find.text('الظهر · بيت الوالد'), findsOneWidget);
    expect(find.text('بعد العصر · قاعة سبأ'), findsOneWidget);
    expect(find.text('السمرة'), findsNothing);
    expect(find.text('ابدأ يومك'), findsOneWidget);
  });
}
