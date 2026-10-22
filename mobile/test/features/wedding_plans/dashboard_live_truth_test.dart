import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard parses compact live-truth sections and next actions', () {
    final summary = DashboardSummary.fromJson({
      'planId': 'plan-1',
      'title': 'خطة الزفاف',
      'currency': 'SAR',
      'status': 'PLANNING',
      'progressPercentage': 40,
      'totalTasks': 10,
      'completedTasks': 4,
      'overdueTasks': 2,
      'todayTasks': 1,
      'guestCount': 50,
      'confirmedGuests': 30,
      'pendingGuests': 15,
      'declinedGuests': 5,
      'providerCount': 1,
      'quoteRequestsCount': 3,
      'pendingQuoteRequests': 1,
      'receivedQuotes': 1,
      'acceptedProviders': 1,
      'nextProviderAction': 'REVIEW_RECEIVED_QUOTES',
      'participantCount': 3,
      'pendingInvites': 2,
      'unreadNotificationsCount': 4,
      'highPriorityNotificationsCount': 2,
      'nextBestActions': [
        {
          'id': 'task-1',
          'type': 'TASK_OVERDUE',
          'title': 'مهمة متأخرة',
          'subtitle': 'اختيار القاعة',
          'icon': 'calendar',
          'tone': 'danger',
          'priority': 'URGENT',
          'actionLabel': 'فتح',
          'routeTarget': '/wedding-plans/plan-1/tasks',
          'entityId': 'task-1',
          'data': {'taskId': 'task-1'},
        },
      ],
      'planProviders': const [],
      'importantNotifications': const [],
      'permissions': {
        'isOwner': true,
        'canViewMoney': true,
        'canManageTasks': true,
        'canManageGuests': true,
        'canManageProviders': true,
        'canManageMembers': true,
        'canManageMoney': true,
        'canManagePlan': true,
      },
    });

    expect(summary.pendingGuests, 15);
    expect(summary.currency, 'SAR');
    expect(summary.receivedQuotes, 1);
    expect(summary.acceptedProviders, 1);
    expect(summary.participantCount, 3);
    expect(summary.pendingInvites, 2);
    expect(summary.highPriorityNotificationsCount, 2);
    expect(summary.importantItems, hasLength(1));
    expect(summary.importantItems.first.priority, 'URGENT');
    expect(
      summary.importantItems.first.routeTarget,
      '/wedding-plans/plan-1/tasks',
    );
  });

  testWidgets('smart money card stays truthful and private at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final summary = DashboardSummary.fromJson({
      'planId': 'plan-1',
      'title': 'خطة',
      'currency': 'SAR',
      'status': 'PLANNING',
      'progressPercentage': 0,
      'totalTasks': 0,
      'completedTasks': 0,
      'overdueTasks': 0,
      'todayTasks': 0,
      // A running plan: its first steps are done (b01).
      'guestCount': 40,
      'venueSecured': true,
      'confirmedGuests': 0,
      'providerCount': 0,
      'quoteRequestsCount': 0,
      'unreadNotificationsCount': 0,
      'nextBestActions': const [],
      'moneySummary': {
        'totalBudget': '1000000',
        'confirmedCost': '900000',
        'paid': '400000',
        'outstanding': '500000',
        'remainingBudget': '100000',
      },
      'permissions': {
        'isOwner': true,
        'canViewMoney': true,
        'canManageTasks': true,
        'canManageMoney': true,
        'canManagePlan': true,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AarastDashboardView(
            summary: summary,
            userName: 'العريس',
            bottomPadding: 24,
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
    );
    await tester.pumpAndSettle();

    expect(find.text('المال'), findsOneWidget);
    expect(find.text('المتاح من الميزانية'), findsOneWidget);
    expect(find.text('التكاليف'), findsOneWidget);
    expect(find.text('المدفوع'), findsOneWidget);
    expect(find.text('غير المدفوع'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-money-privacy-toggle')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('dashboard-money-privacy-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsNWidgets(4));
    expect(find.text('من ميزانية ••••'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('aarast-dashboard-money-card')),
          )
          .label,
      contains('المبالغ مخفية مؤقتًا'),
    );
  });

  test('dashboard compact response does not require full entity lists', () {
    final summary = DashboardSummary.fromJson({
      'planId': 'plan-1',
      'title': 'خطة',
      'status': 'PLANNING',
      'progressPercentage': 0,
      'totalTasks': 0,
      'completedTasks': 0,
      'overdueTasks': 0,
      'todayTasks': 0,
      'guestCount': 0,
      'confirmedGuests': 0,
      'providerCount': 0,
      'quoteRequestsCount': 0,
      'unreadNotificationsCount': 0,
      'nextBestActions': const [],
      'permissions': {
        'isOwner': true,
        'canViewMoney': true,
        'canManageTasks': true,
        'canManageMoney': true,
        'canManagePlan': true,
      },
    });

    expect(summary.importantItems, isEmpty);
    expect(summary.planProviders, isEmpty);
    expect(summary.importantNotifications, isEmpty);
  });

  test('dashboard parses the unified money backend contract', () {
    final summary = DashboardSummary.fromJson({
      'dataScope': 'ACCOUNT_BACKED',
      'accountBacked': true,
      'planId': 'plan-1',
      'title': 'Ø®Ø·Ø©',
      'status': 'PLANNING',
      'progressPercentage': 0,
      'moneySummary': {
        'totalBudget': '1000000',
        'confirmedCost': '250000',
        'paid': '100000',
        'outstanding': '150000',
        'remainingBudget': '750000',
        'overBudget': false,
      },
      'taskSummary': {'total': 4, 'completed': 1, 'overdue': 2, 'dueToday': 1},
      'guestSummary': {
        'total': 10,
        'confirmed': 5,
        'pending': 4,
        'declined': 1,
        'incompleteGuestsCount': 3,
      },
      'providerCount': 1,
      'quoteRequestsCount': 2,
      'acceptedProvidersCount': 1,
      'quoteStatusBreakdown': {
        'pending': 1,
        'offered': 1,
        'accepted': 1,
        'rejectedClosed': 0,
      },
      'nextPaymentScheduleDue': {
        'id': 'schedule-1',
        'weddingCostId': 'cost-1',
        'title': 'القاعة',
        'amount': '50000',
        'dueDate': '2026-08-01T00:00:00.000Z',
        'status': 'PENDING',
      },
      'financialWarnings': [
        {
          'type': 'PAYMENT_SCHEDULE_DUE_SOON',
          'severity': 'WARNING',
          'message': 'ØªÙ†Ø¨ÙŠÙ‡ Ù…Ø§Ù„ÙŠ',
          'count': 1,
          'amount': '50000',
        },
      ],
      'participantSummary': {
        'count': 2,
        'pendingInvites': 1,
        'currentUserRole': 'OWNER',
      },
      'notificationSummary': {'unread': 2, 'highPriority': 1},
      'permissions': {
        'isOwner': true,
        'canViewMoney': true,
        'canManageTasks': true,
        'canManageMoney': true,
        'canManagePlan': true,
      },
    });

    expect(summary.dataScope, 'ACCOUNT_BACKED');
    expect(summary.accountBacked, isTrue);
    expect(summary.totalBudgetForDisplay, '1000000');
    expect(summary.totalTasks, 4);
    expect(summary.completedTasks, 1);
    expect(summary.incompleteGuestsCount, 3);
    expect(summary.quoteStatusBreakdown['offered'], 1);
    expect(summary.acceptedProviders, 1);
    expect(summary.confirmedCostForDisplay, '250000');
    expect(summary.paidForDisplay, '100000');
    expect(summary.outstandingForDisplay, '150000');
    expect(summary.nextPaymentScheduleDue?.amount, '50000');
    expect(summary.nextPaymentScheduleDue?.weddingCostId, 'cost-1');
    expect(summary.financialWarnings, hasLength(1));
    expect(summary.participantCount, 2);
    expect(summary.pendingInvites, 1);
    expect(summary.unreadNotificationsCount, 2);
  });
}
