import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// b01: a new plan leads with three steps (budget, venue, guests), each done
// by a server fact (C24 for the venue); the mahr step waits for its section.

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

Future<void> _pump(WidgetTester tester, DashboardSummary summary) async {
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
        child: Scaffold(
          body: AarastDashboardView(
            summary: summary,
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
    // C1: the mahr step waits for the agreement section.
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
