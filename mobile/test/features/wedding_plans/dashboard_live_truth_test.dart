import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/premium/aarast_money_glance_card.dart';
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
        'canViewBudget': true,
        'canViewExpenses': true,
        'canViewFinancialRecords': true,
        'canManageTasks': true,
        'canManageGuests': true,
        'canManageProviders': true,
        'canManageMembers': true,
        'canManageFinancialRecords': true,
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

  testWidgets('money glance includes commitments and uses the plan currency', (
    tester,
  ) async {
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
      'guestCount': 0,
      'confirmedGuests': 0,
      'providerCount': 0,
      'quoteRequestsCount': 0,
      'unreadNotificationsCount': 0,
      'nextBestActions': const [],
      'moneySummary': {
        'totalBudget': '1000000',
        'totalSpent': '0',
        'remainingBudget': '100000',
        'totalCommitments': '900000',
      },
      'permissions': {
        'isOwner': true,
        'canViewBudget': true,
        'canViewExpenses': true,
        'canViewFinancialRecords': true,
        'canManageTasks': true,
        'canManageFinancialRecords': true,
        'canManagePlan': true,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AarastMoneyGlanceCard(summary: summary, onOpenMoney: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المؤكد'), findsOneWidget);
    expect(find.textContaining('مستخدم 90%'), findsOneWidget);
    final moneyFigures = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .where((text) => text.contains('ر.س'));
    expect(moneyFigures, hasLength(3));
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
        'canViewBudget': true,
        'canViewExpenses': true,
        'canViewFinancialRecords': true,
        'canManageTasks': true,
        'canManageFinancialRecords': true,
        'canManagePlan': true,
      },
    });

    expect(summary.importantItems, isEmpty);
    expect(summary.planProviders, isEmpty);
    expect(summary.importantNotifications, isEmpty);
  });

  test('dashboard parses Super 1 backend contract fields', () {
    final summary = DashboardSummary.fromJson({
      'dataScope': 'ACCOUNT_BACKED',
      'accountBacked': true,
      'planId': 'plan-1',
      'title': 'Ø®Ø·Ø©',
      'status': 'PLANNING',
      'progressPercentage': 0,
      'moneySummary': {
        'totalBudget': '1000000',
        'totalSpent': '250000',
        'remainingBudget': '750000',
        'totalDebts': '300000',
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
      'nextInstallmentDue': {
        'id': 'installment-1',
        'financialCommitmentId': 'commitment-1',
        'amount': '50000',
        'status': 'PENDING',
      },
      'financialWarnings': [
        {
          'type': 'INSTALLMENT_DUE_SOON',
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
        'canViewBudget': true,
        'canViewExpenses': true,
        'canViewFinancialRecords': true,
        'canManageTasks': true,
        'canManageFinancialRecords': true,
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
    expect(summary.nextInstallmentDue?.amount, '50000');
    expect(summary.financialWarnings, hasLength(1));
    expect(summary.participantCount, 2);
    expect(summary.pendingInvites, 1);
    expect(summary.unreadNotificationsCount, 2);
  });
}
