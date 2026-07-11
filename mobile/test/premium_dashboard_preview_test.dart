// Visual preview harness for the NEW premium dashboard (phase/mobile-premium-screens-v1).
// Renders PremiumDashboardView with mock data at phone width and writes golden
// PNGs so the redesign can be inspected pixel-by-pixel without a backend.
//
// Regenerate the images with:
//   flutter test test/premium_dashboard_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/premium/premium_dashboard_view.dart';
import 'support/preview_fonts.dart';

const _permissions = DashboardPermissionSummary(
  isOwner: true,
  canViewBudget: true,
  canViewExpenses: true,
  canViewDebts: true,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: true,
  canManageMembers: true,
  canManageFinancialRecords: true,
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
    city: 'صنعاء همدان',
    budgetTotal: '10,000,000',
    spentTotal: '3,400,000',
    remainingBudget: '6,600,000',
    dueInstallmentsCount: 1,
    totalTasks: 8,
    completedTasks: 5,
    overdueTasks: 1,
    todayTasks: 2,
    guestCount: 124,
    confirmedGuests: 86,
    providerCount: 3,
    quoteRequestsCount: 2,
    receivedQuotes: 1,
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
    city: 'صنعاء همدان',
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
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: PremiumDashboardView(
            summary: summary,
            userName: 'العريس',
            bottomPadding: 36,
            now: DateTime(2026, 7, 4, 9), // تحية ثابتة: صباح الخير

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
  // ندفع الزمن بما يكفي لاكتمال حركات الدخول والعدّادات والحلقة.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('premium dashboard — active plan (420)', (tester) async {
    await _pumpDashboard(
      tester,
      _activePlanSummary(),
      size: const Size(420, 1400),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_dashboard_active.png'),
    );
  });

  testWidgets('premium dashboard — fresh plan setup journey (420)', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      _freshPlanSummary(),
      size: const Size(420, 1500),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_dashboard_fresh.png'),
    );
  });
}
