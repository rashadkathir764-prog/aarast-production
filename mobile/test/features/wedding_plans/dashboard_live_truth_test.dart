import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard parses compact live-truth sections and next actions', () {
    final summary = DashboardSummary.fromJson({
      'planId': 'plan-1',
      'title': 'خطة الزفاف',
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
        'canViewDebts': true,
        'canManageTasks': true,
        'canManageGuests': true,
        'canManageProviders': true,
        'canManageMembers': true,
        'canManageFinancialRecords': true,
        'canManagePlan': true,
      },
    });

    expect(summary.pendingGuests, 15);
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
        'canViewDebts': true,
        'canManageTasks': true,
        'canManageFinancialRecords': true,
        'canManagePlan': true,
      },
    });

    expect(summary.importantItems, isEmpty);
    expect(summary.planProviders, isEmpty);
    expect(summary.importantNotifications, isEmpty);
  });
}
