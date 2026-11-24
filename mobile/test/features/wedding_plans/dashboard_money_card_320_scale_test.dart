import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/preview_fonts.dart';

// RA-MO-328: on a 320 phone at text scale 1.3 the money card's figures took
// four lines («اتفقت على» apart from its figure, «منها المهر» apart from
// its own). Each figure is its words and its amount on one line.

DashboardSummary _ownerPlan() => DashboardSummary.fromJson({
  'planId': 'plan-1',
  'title': 'عرس محمد',
  'currency': 'YER',
  'status': 'PLANNING',
  'daysRemaining': 93,
  'progressPercentage': 10,
  'totalTasks': 20,
  'completedTasks': 0,
  'overdueTasks': 0,
  'todayTasks': 0,
  'guestCount': 40,
  'venueSecured': true,
  'confirmedGuests': 0,
  'providerCount': 0,
  'quoteRequestsCount': 0,
  'unreadNotificationsCount': 0,
  'nextBestActions': const [],
  'budgetIncludesMahr': true,
  'moneySummary': {
    'totalBudget': '7000000',
    'confirmedCost': '2000000',
    'paid': '500000',
    'paidByOwner': '500000',
    'paidByOthers': '0',
    'outstanding': '1500000',
    'remainingBudget': '5000000',
  },
  'permissions': {
    'isOwner': true,
    'canViewMoney': true,
    'canManageTasks': true,
    'canManageMoney': true,
    'canManagePlan': true,
  },
});

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('each money figure keeps its words and amount on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _ownerPlan(),
              funding: const DashboardHomeFunding(
                inHand: 0,
                pledged: 0,
                shortfall: null,
                sourcesCount: 0,
                ownerLeft: 1500000,
              ),
              mahr: const DashboardHomeMahr(
                side: MahrHomeSide.pays,
                recorded: true,
                total: 2000000,
                settled: 500000,
              ),
              amountsHidden: false,
              onToggleAmounts: () {},
              userName: 'محمد',
              bottomPadding: 24,
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final figures = find.byKey(const ValueKey('dashboard-money-figures'));
    expect(figures, findsOneWidget);
    final lines = find.descendant(of: figures, matching: find.byType(RichText));
    expect(lines, findsWidgets);
    // One 13-14sp line at 1.3 is under 30dp tall; a wrapped one is 40+.
    for (final line in lines.evaluate()) {
      final box = line.renderObject! as RenderBox;
      expect(
        box.size.height,
        lessThan(30),
        reason: 'a money figure wrapped to two lines',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
