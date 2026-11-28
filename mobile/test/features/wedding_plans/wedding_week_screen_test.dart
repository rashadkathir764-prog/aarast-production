import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_week_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/home_fixtures.dart';

// D134: «أسبوع العرس», the page the home's card opens. It reads the plan's
// events itself, so it opens from a link as it opens from the card.

PlanEventsView _view({String? weddingDay = '2099-01-21'}) =>
    PlanEventsView.fromJson({
      'weddingPlanId': 'plan-1',
      'canEdit': true,
      'items': [
        {
          'id': 'samra',
          'type': 'SAMRA',
          'date': '2099-01-19',
          'timeSlot': 'AFTER_ISHA',
          'placeLabel': 'الديوان',
        },
        {
          'id': 'maqeel',
          'type': 'MAQEEL',
          'date': '2099-01-20',
          'timeSlot': 'AFTER_DHUHR',
          'placeLabel': 'بيت الوالد',
        },
        {
          'id': 'wedding',
          'type': 'WEDDING',
          'date': weddingDay,
          'isMain': true,
        },
      ],
      'suggestions': const [],
    });

class _Api extends PlanEventsApi {
  _Api(this.view) : super(ApiClient(tokenProvider: () async => null));

  PlanEventsView view;

  /// The server is out of reach and the phone has no copy.
  bool fails = false;
  int reads = 0;

  @override
  Future<PlanEventsView> list(String weddingPlanId) async {
    reads++;
    if (fails) {
      throw const ApiException('ما قدرنا نوصل', isNetworkFailure: true);
    }
    return view;
  }
}

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 2200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<PlanEventsProvider>(
      create: (_) => PlanEventsProvider(api: api),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: WeddingWeekScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Plans extends WeddingPlansApi {
  _Plans() : super(ApiClient(tokenProvider: () async => null));

  final asked = <String>[];

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async {
    asked.add(planId);
    return homeSummary(date: DateTime(2099, 1, 21), today: DateTime(2099));
  }
}

void main() {
  // Opened from a link, the home has not read this plan; and back from a
  // payment, the summary is the one that says what is still due. The page
  // read neither, so it showed the programme without today's payment, and
  // a payment just recorded stayed «دفعة اليوم».
  testWidgets('the page reads the plan\'s summary when the home has not', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2200);
    addTearDown(tester.view.reset);
    final plans = _Plans();
    final dashboard = DashboardSummaryProvider(weddingPlansApi: plans);
    final events = _Api(_view());
    Widget page() => MultiProvider(
      providers: [
        ChangeNotifierProvider<PlanEventsProvider>(
          create: (_) => PlanEventsProvider(api: events),
        ),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(
          value: dashboard,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: WeddingWeekScreen(weddingPlanId: homePlanId),
        ),
      ),
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(plans.asked, [homePlanId]);
    expect(dashboard.summary?.planId, homePlanId);

    // The summary is already this plan's: it is not read a second time.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(plans.asked, [homePlanId]);
  });

  testWidgets('the page names itself and shows the week\'s program from the '
      'plan\'s events', (tester) async {
    await _pump(tester, _Api(_view()));

    expect(find.text('أسبوع العرس'), findsWidgets);
    expect(
      find.byKey(const ValueKey('aarast-dashboard-week-program')),
      findsOneWidget,
    );
    expect(find.text('السمرة'), findsOneWidget);
    expect(find.text('المقيل'), findsOneWidget);
    expect(find.text('الزفاف'), findsOneWidget);
    expect(find.text('الديوان · بعد العشاء'), findsOneWidget);
  });

  testWidgets('a plan with no day yet says so, and offers to set it', (
    tester,
  ) async {
    await _pump(tester, _Api(_view(weddingDay: null)));

    expect(find.byKey(const ValueKey('wedding-week-no-date')), findsOneWidget);
    expect(find.text('ثبّت الموعد'), findsOneWidget);
    expect(find.byKey(const ValueKey('wedding-week-view')), findsNothing);
  });

  testWidgets('a failed read is said as a failure, and read again', (
    tester,
  ) async {
    final api = _Api(_view())..fails = true;
    await _pump(tester, api);

    // Never an empty week when the read failed.
    expect(find.byKey(const ValueKey('wedding-week-view')), findsNothing);
    expect(find.text('السمرة'), findsNothing);

    api.fails = false;
    final reads = api.reads;
    expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
    expect(api.reads, greaterThan(reads));
    expect(find.text('السمرة'), findsOneWidget);
  });
}
