import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// b07: the home once the wedding day has passed.

final _now = DateTime(2027, 2, 1, 9);

Future<int Function()> _pump(
  WidgetTester tester, {
  DateTime? weddingDate,
  DashboardAfterWedding? debt,
  bool showHijri = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1100);
  addTearDown(tester.view.reset);
  var reviews = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AarastDashboardView(
            summary: _summary(weddingDate ?? DateTime(2027, 1, 21)),
            userName: 'رشاد',
            bottomPadding: 24,
            now: _now,
            afterWedding: debt,
            showHijri: showHijri,
            onOpenReviews: () => reviews += 1,
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
  return () => reviews;
}

void main() {
  testWidgets('after the day: the debt, the providers to rate, nothing else', (
    tester,
  ) async {
    final reviews = await _pump(
      tester,
      debt: const DashboardAfterWedding(
        left: 1900000,
        paid: 2300000,
        total: 4200000,
      ),
    );

    expect(find.text('ألف مبروك يا رشاد'), findsOneWidget);
    expect(find.text('1.9'), findsOneWidget);
    expect(find.text('مليون باقي عليك'), findsOneWidget);
    expect(find.text('بعد العرس'), findsOneWidget);
    expect(find.text('سددت 2.3 مليون ر.ي من 4.2 مليون ر.ي'), findsOneWidget);
    // No payoff date is planned anywhere, so none is promised.
    expect(find.textContaining('تخلص منها'), findsNothing);
    // The rafd cards and «كتاب عرسك» have nothing behind them.
    expect(find.textContaining('رفد'), findsNothing);
    expect(find.text('كتاب عرسك'), findsNothing);
    // The planning cards are done with.
    expect(
      find.byKey(const ValueKey('aarast-dashboard-money-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('aarast-dashboard-tile-tasks')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('aarast-dashboard-sharing')),
      findsNothing,
    );

    await tester.tap(find.text('قيّم'));
    expect(reviews(), 1);
  });

  testWidgets('after the day with nothing owed, the hero congratulates', (
    tester,
  ) async {
    await _pump(
      tester,
      debt: const DashboardAfterWedding(left: 0, paid: 900000, total: 900000),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-after-hero')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('aarast-dashboard-plan-moment')),
      findsOneWidget,
    );
    expect(find.text('قيّم مزودينك'), findsOneWidget);
  });

  testWidgets('g02 turns the Hijri date off on the home', (tester) async {
    await _pump(tester, weddingDate: DateTime(2027, 3, 1));
    expect(find.text('الاثنين 1 مارس · 22 رمضان'), findsOneWidget);

    await _pump(tester, weddingDate: DateTime(2027, 3, 1), showHijri: false);
    expect(find.text('الاثنين 1 مارس'), findsOneWidget);
  });

  testWidgets('before the day the home stays the planning home', (
    tester,
  ) async {
    await _pump(tester, weddingDate: DateTime(2027, 3, 1));

    expect(find.text('أهلًا رشاد'), findsOneWidget);
    expect(find.text('قيّم مزودينك'), findsNothing);
    expect(
      find.byKey(const ValueKey('aarast-dashboard-money-card')),
      findsOneWidget,
    );
  });
}

DashboardSummary _summary(DateTime weddingDate) {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'عرس رشاد',
    status: 'PLANNING',
    progressPercentage: 45,
    weddingDate: weddingDate,
    daysRemaining: weddingDate.difference(_now).inDays,
    city: 'صنعاء',
    budgetTotal: '1000000',
    confirmedCostTotal: '250000',
    paidTotal: '100000',
    outstandingTotal: '150000',
    remainingBudget: '750000',
    totalTasks: 3,
    completedTasks: 1,
    overdueTasks: 0,
    todayTasks: 0,
    guestCount: 25,
    venueSecured: true,
    confirmedGuests: 10,
    providerCount: 1,
    quoteRequestsCount: 1,
    participantCount: 4,
    pendingInvites: 2,
    currentUserRole: 'OWNER',
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: const DashboardPermissionSummary(
      isOwner: true,
      canViewMoney: true,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: true,
      canManageMembers: true,
      canManageMoney: true,
      canManagePlan: true,
      role: 'OWNER',
    ),
  );
}
