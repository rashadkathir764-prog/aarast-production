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
              onOpenParticipants: () {},
              onOpenNotifications: () {},
              onOpenImportantItem: (_) {},
              onOpenNextStep: () {},
              onOpenTimeline: () {},
              onAddExpense: () {},
            ),
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: 0,
              onHome: () {},
              onMoney: () {},
              onProviders: () {},
              onGuests: () {},
            ),
          ),
        ),
      ),
    );

    // Use bounded pumps instead of pumpAndSettle because the dashboard uses
    // intentionally looping decorations (live countdown dot, breath CTA)
    // which would otherwise cause pumpAndSettle to hang.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('الأهم الآن'), findsOneWidget);
    expect(find.text('أقرب شيء يحتاج انتباهك في الخطة'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('الميزانية'),
      find.byType(ListView).first,
      const Offset(0, -320),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('الميزانية'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('نظرة سريعة'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('نظرة سريعة'), findsOneWidget);
    expect(find.text('إجراءات سريعة'), findsNothing);
    expect(find.text('مشاركة الخطة'), findsOneWidget);
    expect(find.text('آخر التحديثات'), findsOneWidget);
    expect(find.text('إجراء جديد'), findsNothing);
  });

  testWidgets('dashboard currency formatting keeps Yemeni suffix readable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RoyalHomeTodayCenter(
              summary: _moneySummary,
              userName: 'رشاد',
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenParticipants: () {},
              onOpenNotifications: () {},
              onOpenImportantItem: (_) {},
              onOpenNextStep: () {},
              onOpenTimeline: () {},
              onAddExpense: () {},
            ),
          ),
        ),
      ),
    );

    await tester.dragUntilVisible(
      find.text('الميزانية'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.textContaining('م ر.ي'), findsAtLeastNWidgets(1));
    expect(find.text('118.4م ر.ي'), findsOneWidget);
    expect(find.textContaining('م120'), findsNothing);
    expect(find.textContaining('م1.6'), findsNothing);
  });

  testWidgets('dashboard phone width has no floating CTA overflow mark', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
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
              onOpenParticipants: () {},
              onOpenNotifications: () {},
              onOpenImportantItem: (_) {},
              onOpenNextStep: () {},
              onOpenTimeline: () {},
              onAddExpense: () {},
            ),
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: 0,
              onHome: () {},
              onMoney: () {},
              onTasks: () {},
              onProviders: () {},
              onGuests: () {},
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('إجراء جديد'), findsNothing);
    expect(tester.takeException(), isNull);
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
                  label: 'إضافة دين/قسط',
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

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('إجراء جديد'), findsOneWidget);
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('إضافة مهمة'), findsOneWidget);
    expect(find.text('إضافة ضيف'), findsOneWidget);
    expect(find.text('إضافة دين/قسط'), findsOneWidget);
    expect(find.text('طلب عرض سعر'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('smart floating plus opens the approved action sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            floatingActionButton: RoyalSmartFloatingActionButton(
              onPressed: () {
                showRoyalHomeActionSheet(
                  tester.element(find.byType(Scaffold)),
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
                      label: 'إضافة دين/قسط',
                      onTap: () {},
                    ),
                    RoyalHomeAction(
                      icon: Icons.request_quote_outlined,
                      label: 'طلب عرض سعر',
                      onTap: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('royal-smart-fab')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('إجراء جديد'), findsOneWidget);
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('طلب عرض سعر'), findsOneWidget);
  });

  testWidgets('royal bottom nav hides new-action CTA when no action is bound', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: 0,
              onHome: () {},
              onMoney: () {},
              onTasks: () {},
              onProviders: () {},
              onGuests: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('إجراء جديد'), findsNothing);
  });
  testWidgets('royal bottom nav renders the five production tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: RoyalDashboardBottomNav(
              activeIndex: 2,
              onHome: () {},
              onMoney: () {},
              onTasks: () {},
              onGuests: () {},
              onProviders: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المال'), findsOneWidget);
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('الضيوف'), findsOneWidget);
    expect(find.text('الموردون'), findsOneWidget);
    expect(find.text('المزيد'), findsNothing);
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

final _moneySummary = DashboardSummary(
  planId: 'plan-money',
  title: 'زفاف صنعاء',
  status: 'PLANNING',
  progressPercentage: 20,
  budgetTotal: '120000000',
  spentTotal: '1600000',
  remainingBudget: '118400000',
  debtTotal: '5300000',
  dueInstallmentsCount: 0,
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
  permissions: const DashboardPermissionSummary(
    isOwner: true,
    canViewBudget: true,
    canViewExpenses: true,
    canViewDebts: true,
    canManageTasks: true,
    canManageFinancialRecords: true,
    canManagePlan: true,
  ),
);
