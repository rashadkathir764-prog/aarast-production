@Tags(['golden'])
library;

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/preview_fonts.dart';

const _permissions = DashboardPermissionSummary(
  isOwner: true,
  canViewMoney: true,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: true,
  canManageMembers: true,
  canManageMoney: true,
  canManagePlan: true,
);

DashboardSummary _activePlanSummary() {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'عرس العبسي',
    status: 'PLANNING',
    progressPercentage: 62,
    weddingDate: DateTime(2026, 8, 31),
    daysRemaining: 57,
    city: 'صنعاء - همدان',
    budgetTotal: '10000000',
    confirmedCostTotal: '3400000',
    paidTotal: '1400000',
    outstandingTotal: '2000000',
    remainingBudget: '6600000',
    duePaymentSchedulesCount: 1,
    totalTasks: 8,
    completedTasks: 5,
    overdueTasks: 1,
    todayTasks: 2,
    guestCount: 124,
    confirmedGuests: 86,
    providerCount: 3,
    quoteRequestsCount: 2,
    receivedQuotes: 1,
    participantCount: 4,
    pendingInvites: 2,
    unreadNotificationsCount: 2,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: _permissions,
  );
}

DashboardSummary _freshPlanSummary() {
  return DashboardSummary(
    dataScope: 'LOCAL',
    accountBacked: false,
    planId: 'plan-local',
    title: 'عرسنا',
    status: 'PLANNING',
    progressPercentage: 0,
    weddingDate: DateTime(2026, 8, 31),
    daysRemaining: 57,
    city: 'صنعاء - همدان',
    totalTasks: 0,
    completedTasks: 0,
    overdueTasks: 0,
    todayTasks: 0,
    guestCount: 0,
    confirmedGuests: 0,
    providerCount: 0,
    quoteRequestsCount: 0,
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: _permissions,
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  DashboardSummary summary, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: PlanShellChrome(
          activeIndex: 0,
          onTabSelected: (_) {},
          body: AarastDashboardView(
            summary: summary,
            userName: 'العريس',
            bottomPadding: 132,
            now: DateTime(2026, 7, 4, 9),
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
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('real dashboard shell - active plan at 420px RTL', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      _activePlanSummary(),
      size: const Size(420, 1000),
    );
    expect(tester.takeException(), isNull);
    final hero = find.byKey(const ValueKey('aarast-dashboard-plan-moment'));
    // D8: the countdown hero is compact on a phone.
    expect(tester.getSize(hero).height, inInclusiveRange(96, 140));
    await expectLater(
      find.byType(PlanShellChrome),
      matchesGoldenFile('goldens/aarast_dashboard_active_420.png'),
    );
  });

  testWidgets('real dashboard shell - fresh plan at 320px RTL', (tester) async {
    await _pumpDashboard(
      tester,
      _freshPlanSummary(),
      size: const Size(320, 900),
    );
    expect(tester.takeException(), isNull);
    final hero = find.byKey(const ValueKey('aarast-dashboard-plan-moment'));
    // D8: the countdown hero is compact on a phone.
    expect(tester.getSize(hero).height, inInclusiveRange(96, 140));
    await expectLater(
      find.byType(PlanShellChrome),
      matchesGoldenFile('goldens/aarast_dashboard_fresh_320.png'),
    );
  });

  testWidgets('real dashboard shell uses the wide canvas', (tester) async {
    await _pumpDashboard(
      tester,
      _activePlanSummary(),
      size: const Size(1000, 900),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PlanShellChrome),
      matchesGoldenFile('goldens/aarast_dashboard_wide_1000.png'),
    );
  });
}
