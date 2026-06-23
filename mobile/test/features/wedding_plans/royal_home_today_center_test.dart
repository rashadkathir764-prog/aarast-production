import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/royal_home_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/royal_home_today_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('royal home today center renders the approved section contract', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RoyalHomeTodayCenter(
              summary: _summary,
              userName: 'رشاد',
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenNotifications: () {},
              onOpenImportantItem: (_) {},
              onOpenNextStep: () {},
            ),
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: 0,
              onHome: () {},
              onMoney: () {},
              onTasks: () {},
              onProviders: () {},
              onMore: () {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('الأهم اليوم'), findsOneWidget);
    expect(find.text('الخطوة التالية المقترحة'), findsOneWidget);
    expect(find.text('المال'), findsWidgets);
    expect(find.text('المهام'), findsWidgets);
    expect(find.text('الموردون'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('الضيوف'), findsWidgets);
    expect(find.text('إشعارات'), findsWidgets);
    expect(find.text('إجراء جديد'), findsOneWidget);
  });

  testWidgets('royal action sheet exposes the approved quick actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RoyalHomeActionSheet(
              onClose: () {},
              actions: [
                RoyalHomeAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'إضافة مصروف',
                  onTap: () {},
                ),
                RoyalHomeAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'إضافة مهمة',
                  onTap: () {},
                ),
                RoyalHomeAction(
                  icon: Icons.group_add_outlined,
                  label: 'إضافة ضيف',
                  onTap: () {},
                ),
                RoyalHomeAction(
                  icon: Icons.attach_money_rounded,
                  label: 'إضافة دين',
                  onTap: () {},
                ),
                RoyalHomeAction(
                  icon: Icons.request_quote_outlined,
                  label: 'طلب عرض سعر',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('إجراء جديد'), findsOneWidget);
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('إضافة مهمة'), findsOneWidget);
    expect(find.text('إضافة ضيف'), findsOneWidget);
    expect(find.text('إضافة دين'), findsOneWidget);
    expect(find.text('طلب عرض سعر'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}

final _summary = DashboardSummary(
  planId: 'plan-1',
  title: 'زفاف صنعاء',
  status: 'PLANNING',
  city: 'صنعاء - حدة',
  weddingDate: DateTime.utc(2026, 12, 21),
  daysRemaining: 184,
  progressPercentage: 42,
  budgetTotal: '80000',
  spentTotal: '32400',
  remainingBudget: '47600',
  debtTotal: '12000',
  unpaidDebtTotal: '12000',
  dueInstallmentsCount: 1,
  totalTasks: 7,
  completedTasks: 1,
  overdueTasks: 1,
  todayTasks: 1,
  guestCount: 246,
  confirmedGuests: 138,
  providerCount: 4,
  quoteRequestsCount: 3,
  unreadNotificationsCount: 2,
  importantItems: [
    DashboardImportantItem(
      id: 'installment-1',
      type: 'INSTALLMENT_DUE',
      title: 'قسط القاعة مستحق بعد يومين',
      subtitle: 'مستحق قريباً',
      icon: 'wallet',
      tone: 'warning',
      actionLabel: 'عرض',
      amount: '4000',
      data: const {},
    ),
    DashboardImportantItem(
      id: 'quote-1',
      type: 'QUOTE_RECEIVED',
      title: 'عرض سعر من قاعة الياسمين',
      subtitle: 'عرض جديد',
      icon: 'provider',
      tone: 'success',
      actionLabel: 'مراجعة',
      data: const {},
    ),
    DashboardImportantItem(
      id: 'task-1',
      type: 'TASK_OVERDUE',
      title: 'مهمة اختيار المصور متأخرة',
      subtitle: 'متأخر',
      icon: 'calendar',
      tone: 'danger',
      actionLabel: 'فتح',
      data: const {},
    ),
  ],
  planProviders: [
    DashboardProviderPreview(
      id: 'link-1',
      providerId: 'provider-1',
      businessName: 'قاعة الياسمين',
      ratingAverage: '4.8',
      ratingCount: 12,
      status: 'ACTIVE',
    ),
    DashboardProviderPreview(
      id: 'link-2',
      providerId: 'provider-2',
      businessName: 'استديو النور',
      ratingAverage: '4.6',
      ratingCount: 8,
      status: 'ACTIVE',
    ),
  ],
  importantNotifications: [
    DashboardNotificationPreview(
      id: 'notification-1',
      type: 'QUOTE_RECEIVED',
      title: 'عرض قاعة الياسمين',
      body: 'وصل عرض جديد',
      createdAt: DateTime.utc(2026, 6, 20),
    ),
  ],
  permissions: DashboardPermissionSummary(
    isOwner: true,
    canViewBudget: true,
    canViewExpenses: true,
    canViewDebts: true,
    canManageTasks: true,
    canManageFinancialRecords: true,
    canManagePlan: true,
  ),
);
