import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/premium/premium_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium dashboard shows real plan participants card at 320px', (
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
            body: PremiumDashboardView(
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
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 450));
    await tester.ensureVisible(find.text('المشاركون في الخطة'));

    expect(find.text('المشاركون في الخطة'), findsOneWidget);
    expect(find.text('المشاركون'), findsOneWidget);
    expect(find.text('دعوات معلقة'), findsOneWidget);
    expect(find.text('دورك'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('مالك الخطة'), findsOneWidget);
    expect(find.text('إدارة المشاركين'), findsOneWidget);

    await tester.tap(find.text('المشاركون في الخطة'));
    expect(sharingOpens, 1);
    expect(tester.takeException(), isNull);
  });
}

DashboardSummary _summary() {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'خطة الزفاف',
    status: 'PLANNING',
    progressPercentage: 45,
    weddingDate: DateTime(2026, 12, 20),
    daysRemaining: 166,
    city: 'صنعاء',
    budgetTotal: '1000000',
    spentTotal: '250000',
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
      canViewBudget: true,
      canViewExpenses: true,
      canViewFinancialRecords: true,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: true,
      canManageMembers: true,
      canManageFinancialRecords: true,
      canManagePlan: true,
      role: 'OWNER',
    ),
  );
}
