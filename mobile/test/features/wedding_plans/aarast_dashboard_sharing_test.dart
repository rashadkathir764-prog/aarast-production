import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows the real plan team at 320px RTL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    var sharingOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _summary(),
              userName: 'رشاد',
              bottomPadding: 24,
              now: DateTime(2026, 7, 7, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () => sharingOpens += 1,
              onOpenWeddingDay: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    );

    final sharing = find.byKey(const ValueKey('aarast-dashboard-sharing'));
    await tester.ensureVisible(sharing);
    await tester.pumpAndSettle();

    expect(find.text('فريق الخطة'), findsOneWidget);
    expect(find.text('4 مشاركين'), findsOneWidget);
    expect(find.text('2 دعوات بانتظار الرد'), findsOneWidget);

    await tester.tap(sharing);
    await tester.pump();
    expect(sharingOpens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard mosaic stays compact and complete below the plan hero',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AarastDashboardView(
                summary: _summary(),
                userName: 'رشاد',
                bottomPadding: 24,
                now: DateTime(2026, 7, 7, 9),
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

      final mosaic = find.byKey(
        const ValueKey('aarast-dashboard-mobile-mosaic'),
      );
      expect(mosaic, findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-signal-tasks')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-signal-guests')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-signal-providers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('aarast-dashboard-money-card')),
        findsOneWidget,
      );
      expect(tester.getSize(mosaic).height, lessThanOrEqualTo(450));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard exposes wedding day mode only in its real window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    var opens = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _summary(weddingDate: DateTime(2026, 7, 7)),
              userName: 'رشاد',
              bottomPadding: 24,
              now: DateTime(2026, 7, 7, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () {},
              onOpenWeddingDay: () => opens += 1,
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    );

    final entry = find.byKey(const Key('wedding-day-mode-entry'));
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });
}

DashboardSummary _summary({DateTime? weddingDate}) {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'خطة الزفاف',
    status: 'PLANNING',
    progressPercentage: 45,
    weddingDate: weddingDate ?? DateTime(2026, 12, 20),
    daysRemaining: 166,
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
