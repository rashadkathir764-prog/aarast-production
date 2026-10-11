import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_day/widgets/wedding_day_mode_view.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F06: the wedding-day view is readable with plan view access only, so its
// actions and quick destinations must follow the viewer's capabilities.
void main() {
  testWidgets('a view-only contributor sees tasks but cannot act on them', (
    tester,
  ) async {
    var completed = 0;
    await _pump(
      tester,
      permissions: const DashboardPermissionSummary(
        isOwner: false,
        canViewMoney: false,
        canManageTasks: false,
        canManageMoney: false,
        canManagePlan: false,
      ),
      onComplete: (_) => completed += 1,
    );

    expect(find.text('تأكيد وصول القاعة'), findsWidgets);
    expect(find.byTooltip('إنجاز تأكيد وصول القاعة'), findsNothing);
    expect(find.text('كل المهام'), findsNothing);
    expect(find.text('الضيوف'), findsNothing);
    expect(find.text('المزوّدون'), findsNothing);
    expect(completed, 0);
  });

  testWidgets('a contributor sees only the destinations they can manage', (
    tester,
  ) async {
    await _pump(
      tester,
      permissions: const DashboardPermissionSummary(
        isOwner: false,
        canViewMoney: false,
        canManageTasks: true,
        canManageMoney: false,
        canManagePlan: false,
      ),
      onComplete: (_) {},
    );

    expect(find.byTooltip('إنجاز تأكيد وصول القاعة'), findsOneWidget);
    expect(find.text('كل المهام'), findsOneWidget);
    expect(find.text('الضيوف'), findsNothing);
    expect(find.text('المزوّدون'), findsNothing);
  });

  testWidgets('the owner keeps every action and destination', (tester) async {
    var completed = 0;
    await _pump(
      tester,
      permissions: const DashboardPermissionSummary(
        isOwner: true,
        canViewMoney: true,
        canManageTasks: false,
        canManageMoney: true,
        canManagePlan: true,
      ),
      onComplete: (_) => completed += 1,
    );

    await tester.tap(find.byTooltip('إنجاز تأكيد وصول القاعة'));
    expect(completed, 1);
    expect(find.text('كل المهام'), findsOneWidget);
    expect(find.text('الضيوف'), findsOneWidget);
    expect(find.text('المزوّدون'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required DashboardPermissionSummary permissions,
  required ValueChanged<WeddingTask> onComplete,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2000);
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 8, 9, 10);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: WeddingDayModeView(
            summary: DashboardSummary(
              planId: 'plan-wedding-day',
              title: 'عرس ريان وسارة',
              status: 'PLANNING',
              progressPercentage: 50,
              weddingDate: DateTime(2026, 8, 9, 20),
              daysRemaining: 0,
              totalTasks: 1,
              completedTasks: 0,
              overdueTasks: 0,
              todayTasks: 1,
              guestCount: 0,
              confirmedGuests: 0,
              providerCount: 0,
              quoteRequestsCount: 0,
              unreadNotificationsCount: 0,
              importantItems: const [],
              planProviders: const [],
              importantNotifications: const [],
              permissions: permissions,
            ),
            tasks: [
              WeddingTask(
                id: 'task-today',
                weddingPlanId: 'plan-wedding-day',
                title: 'تأكيد وصول القاعة',
                dueDate: DateTime(2026, 8, 9, 12),
                status: 'TODO',
                priority: 'URGENT',
                createdAt: DateTime(2026, 8, 1),
                updatedAt: DateTime(2026, 8, 1),
              ),
            ],
            now: now,
            onRefresh: () async {},
            onCompleteTask: onComplete,
            onCopyPhone: (_) {},
            onOpenTasks: () {},
            onOpenGuests: () {},
            onOpenProviders: () {},
            onOpenProvider: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
