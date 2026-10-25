import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// b01: a new plan leads with its steps (budget, venue, guests, and the mahr
// for a groom's or a bride's plan, B5), each done by a server fact (C24 for
// the venue, the money section's `mahr` for the mahr); b02 then carries the
// mahr agreement until it is complete.

DashboardSummary _summary({
  String? budget,
  bool venueSecured = false,
  int guests = 0,
  bool isOwner = true,
}) {
  return DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'عرس محمد',
    'city': 'صنعاء',
    'currency': 'YER',
    'status': 'PLANNING',
    'weddingDate': '2027-01-21',
    'daysRemaining': 96,
    'progressPercentage': 0,
    'totalTasks': 0,
    'completedTasks': 0,
    'overdueTasks': 0,
    'todayTasks': 0,
    'guestCount': guests,
    'confirmedGuests': 0,
    'providerCount': 0,
    'quoteRequestsCount': 0,
    'unreadNotificationsCount': 0,
    'nextBestActions': const [],
    'venueSecured': venueSecured,
    'moneySummary': {'totalBudget': budget},
    'permissions': {
      'isOwner': isOwner,
      'canViewMoney': true,
      'canManageMoney': isOwner,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManagePlan': isOwner,
    },
  });
}

Future<void> _pump(
  WidgetTester tester,
  DashboardSummary summary, {
  DashboardHomeMahr? mahr,
  VoidCallback? onOpenMahr,
  JourneyProfile profile = JourneyProfile.groom,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: JourneyProfileScope(
          profile: profile,
          child: Scaffold(
            body: AarastDashboardView(
              summary: summary,
              mahr: mahr,
              onOpenMahr: onOpenMahr,
              userName: 'محمد',
              bottomPadding: 24,
              now: DateTime(2026, 10, 17, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () {},
              onOpenWeddingDay: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new plan leads with three steps, the first to do', (
    tester,
  ) async {
    await _pump(tester, _summary());

    expect(find.text('ثلاث خطوات وعرسك منظم'), findsOneWidget);
    expect(find.text('خلصت 0 من 3'), findsOneWidget);
    expect(find.text('ميزانيتك'), findsOneWidget);
    expect(find.text('القاعة'), findsOneWidget);
    expect(find.text('ضيوفك'), findsOneWidget);
    // B5: no mahr step without a groom's or a bride's plan behind it.
    expect(find.text('المهر'), findsNothing);
    // Only the current step offers «كمّل».
    expect(find.text('كمّل'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('aarast-dashboard-setup-step-1')),
        matching: find.text('كمّل'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a secured venue is done only when the server says so', (
    tester,
  ) async {
    await _pump(tester, _summary(budget: '7000000', venueSecured: true));

    expect(find.text('خلصت 2 من 3'), findsOneWidget);
    expect(find.text('محجوزة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('aarast-dashboard-setup-step-3')),
        matching: find.text('كمّل'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with every step done, the home shows the plan itself', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(budget: '7000000', venueSecured: true, guests: 40),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-setup-steps')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('aarast-dashboard-tile-guests')),
      findsOneWidget,
    );
  });

  testWidgets('B5 b01: a groom\'s plan without its mahr has four steps, the '
      'mahr second, opening a06', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      _summary(budget: '7000000'),
      mahr: const DashboardHomeMahr.notRecorded(MahrHomeSide.pays),
      onOpenMahr: () => opened++,
    );

    expect(find.text('أربع خطوات وعرسك منظم'), findsOneWidget);
    expect(find.text('خلصت 1 من 4'), findsOneWidget);
    final step = find.byKey(const ValueKey('aarast-dashboard-setup-step-2'));
    expect(
      find.descendant(of: step, matching: find.text('المهر')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: step,
        matching: find.text('اللي بتسلّمه لأهل العروسة، نحسبه لحاله'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: step, matching: find.text('كمّل')));
    await tester.pump();
    expect(opened, 1);
    // Not recorded, no agreement card.
    expect(
      find.byKey(const ValueKey('aarast-dashboard-mahr-card')),
      findsNothing,
    );
  });

  testWidgets('B5 b01: the bride\'s recorded mahr is a done step in her '
      'words', (tester) async {
    await _pump(
      tester,
      _summary(),
      profile: JourneyProfile.bride,
      mahr: const DashboardHomeMahr(
        side: MahrHomeSide.receives,
        recorded: true,
        total: 3000000,
        settled: 2000000,
      ),
    );

    expect(find.text('خلصت 1 من 4'), findsOneWidget);
    expect(find.text('3 مليون من العريس · استلمتِ 2'), findsOneWidget);
  });

  testWidgets('B5 b02: once the steps are done the agreement stays on the '
      'home until it is complete', (tester) async {
    final done = _summary(budget: '7000000', venueSecured: true, guests: 40);
    await _pump(
      tester,
      done,
      mahr: DashboardHomeMahr(
        side: MahrHomeSide.pays,
        recorded: true,
        total: 3000000,
        settled: 2000000,
        nextDueAt: DateTime(2026, 11, 15),
      ),
    );

    final card = find.byKey(const ValueKey('aarast-dashboard-mahr-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('الاتفاق مع أهل العروسة')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('سلّمت 2 من 3 مليون · الباقي 15 نوفمبر'),
      ),
      findsOneWidget,
    );

    await _pump(
      tester,
      done,
      mahr: const DashboardHomeMahr(
        side: MahrHomeSide.pays,
        recorded: true,
        total: 3000000,
        settled: 3000000,
        complete: true,
      ),
    );
    expect(card, findsNothing);
  });

  testWidgets('a participant who is not the owner never sees the steps', (
    tester,
  ) async {
    await _pump(tester, _summary(isOwner: false));

    expect(
      find.byKey(const ValueKey('aarast-dashboard-setup-steps')),
      findsNothing,
    );
  });
}
