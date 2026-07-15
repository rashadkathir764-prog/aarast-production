import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/contributor_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('contributor workspace only renders permission-backed cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: ContributorWorkspaceView(
          summary: _summary(
            permissions: const DashboardPermissionSummary(
              isOwner: false,
              role: 'VIEWER',
              canViewMoney: false,
              canManageTasks: false,
              canManageGuests: false,
              canManageProviders: false,
              canManageMembers: false,
              canManageMoney: false,
              canManagePlan: false,
            ),
          ),
          onOpenTasks: () {},
          onOpenNotifications: () {},
          onShowPermissions: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contributor-tasks-card')), findsOneWidget);
    expect(find.byKey(const Key('contributor-money-card')), findsNothing);
    expect(find.byKey(const Key('contributor-guests-card')), findsNothing);
    expect(find.byKey(const Key('contributor-providers-card')), findsNothing);
    expect(find.byKey(const Key('contributor-members-card')), findsNothing);
    expect(find.text('أنت مساهم للمتابعة'), findsOneWidget);
    await tester.drag(
      find.byKey(const PageStorageKey('contributor-workspace-list')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('contributor-permissions-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'contributor workspace shows cards and actions from permissions',
    (tester) async {
      var tasksOpened = 0;
      var costsCreated = 0;

      await tester.pumpWidget(
        _TestApp(
          child: ContributorWorkspaceView(
            summary: _summary(
              permissions: const DashboardPermissionSummary(
                isOwner: false,
                role: 'MANAGER',
                canViewMoney: true,
                canManageTasks: true,
                canManageGuests: true,
                canManageProviders: true,
                canManageMembers: true,
                canManageMoney: true,
                canManagePlan: false,
              ),
            ),
            onOpenTasks: () => tasksOpened += 1,
            onOpenNotifications: () {},
            onShowPermissions: () {},
            onOpenMoney: () {},
            onOpenGuests: () {},
            onOpenProviders: () {},
            onOpenMembers: () {},
            onCreateTask: () {},
            onAddGuest: () {},
            onAddCost: () => costsCreated += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('contributor-money-card')), findsOneWidget);
      expect(find.byKey(const Key('contributor-guests-card')), findsOneWidget);
      expect(
        find.byKey(const Key('contributor-providers-card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('contributor-members-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('contributor-tasks-card')));
      expect(tasksOpened, 1);

      final addCostButton = find.widgetWithText(TextButton, 'إضافة تكلفة');
      await tester.ensureVisible(addCostButton);
      await tester.pumpAndSettle();
      await tester.tap(addCostButton);
      expect(costsCreated, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('contributor workspace stays overflow-free at 320 and 1.3 text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _TestApp(
          child: ContributorWorkspaceView(
            summary: _summary(
              permissions: const DashboardPermissionSummary(
                isOwner: false,
                role: 'MANAGER',
                canViewMoney: true,
                canManageTasks: true,
                canManageGuests: true,
                canManageProviders: true,
                canManageMembers: false,
                canManageMoney: false,
                canManagePlan: false,
              ),
            ),
            onOpenTasks: () {},
            onOpenNotifications: () {},
            onShowPermissions: () {},
            onOpenMoney: () {},
            onOpenGuests: () {},
            onOpenProviders: () {},
            onCreateTask: () {},
            onAddGuest: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contributor-plan-hero')), findsOneWidget);
    expect(find.byKey(const Key('contributor-tasks-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: SafeArea(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );
  }
}

DashboardSummary _summary({required DashboardPermissionSummary permissions}) {
  return DashboardSummary(
    planId: 'plan-shared',
    title: 'عرس رشاد وسارة',
    status: 'PLANNING',
    progressPercentage: 48,
    weddingDate: DateTime(2026, 9, 28),
    daysRemaining: 75,
    city: 'صنعاء',
    currency: 'SAR',
    budgetTotal: '25000',
    confirmedCostTotal: '3435',
    paidTotal: '1000',
    outstandingTotal: '2435',
    remainingBudget: '21565',
    totalTasks: 7,
    completedTasks: 2,
    overdueTasks: 1,
    todayTasks: 2,
    guestCount: 120,
    confirmedGuests: 40,
    providerCount: 6,
    quoteRequestsCount: 3,
    receivedQuotes: 2,
    participantCount: 3,
    unreadNotificationsCount: 2,
    importantItems: const [],
    recentActivity: const [],
    planProviders: const [],
    importantNotifications: [
      DashboardNotificationPreview(
        id: 'notification-1',
        type: 'TASK_UPDATED',
        title: 'تم تحديث مهمة تجهيز القاعة',
        body: 'تغيّر الموعد وأضيفت ملاحظة جديدة.',
        createdAt: DateTime(2026, 7, 15, 12),
      ),
    ],
    permissions: permissions,
  );
}
