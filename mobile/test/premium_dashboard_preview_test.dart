// Visual preview harness for the NEW premium dashboard (phase/mobile-premium-screens-v1).
// Renders PremiumDashboardView with mock data at phone width and writes golden
// PNGs so the redesign can be inspected pixel-by-pixel without a backend.
//
// Regenerate the images with:
//   flutter test test/premium_dashboard_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/premium/premium_dashboard_view.dart';

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

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('Amiri', ['assets/fonts/Amiri-Bold.ttf']);
  // خط أيقونات Lucide حتى تُعاين الأيقونات فعليًا في الـ goldens.
  // الخطوط القادمة من حزمة تُسجَّل بصيغة packages/<pkg>/<family>.
  await load('packages/lucide_icons/Lucide',
      ['packages/lucide_icons/assets/lucide.ttf']);
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
            onNotifications: () {},
            onProfile: () {},
            onOpenPlan: () {},
            onOpenMoney: () {},
            onOpenTasks: () {},
            onOpenProviders: () {},
            onOpenGuests: () {},
            onOpenNextStep: () {},
            onOpenImportantItem: (_) {},
            onAddExpense: () {},
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
  setUpAll(_loadFonts);

  testWidgets('premium dashboard — active plan (420)', (tester) async {
    await _pumpDashboard(tester, _activePlanSummary(),
        size: const Size(420, 1400));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_dashboard_active.png'),
    );
  });

  testWidgets('premium dashboard — fresh plan setup journey (420)',
      (tester) async {
    await _pumpDashboard(tester, _freshPlanSummary(),
        size: const Size(420, 1500));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_dashboard_fresh.png'),
    );
  });
}
