import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_focus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard focus keeps one deterministic priority at a time', () {
    expect(
      resolveDashboardFocus(
        _summary(duePaymentSchedules: 1, overdueTasks: 3, incompleteGuests: 4),
      ).target,
      AarastDashboardFocusTarget.money,
    );

    final guestFocus = resolveDashboardFocus(
      _summary(incompleteGuests: 2, providerCount: 0),
    );
    expect(guestFocus.target, AarastDashboardFocusTarget.guests);
    expect(guestFocus.title, contains('ناقص'));

    expect(
      resolveDashboardFocus(_summary(providerCount: 0)).target,
      AarastDashboardFocusTarget.providers,
    );
  });

  test('missing budget remains more important than discovering providers', () {
    final focus = resolveDashboardFocus(
      _summary(hasBudget: false, providerCount: 0),
    );
    expect(focus.target, AarastDashboardFocusTarget.money);
    expect(focus.title, contains('ميزانية'));
  });
}

DashboardSummary _summary({
  bool hasBudget = true,
  int duePaymentSchedules = 0,
  int overdueTasks = 0,
  int incompleteGuests = 0,
  int providerCount = 1,
}) {
  return DashboardSummary(
    planId: 'plan-focus',
    title: 'خطة الاختبار',
    status: 'PLANNING',
    progressPercentage: 20,
    budgetTotal: hasBudget ? '1000000' : null,
    totalTasks: 2,
    completedTasks: 0,
    overdueTasks: overdueTasks,
    todayTasks: 0,
    guestCount: incompleteGuests,
    confirmedGuests: 0,
    incompleteGuestsCount: incompleteGuests,
    providerCount: providerCount,
    quoteRequestsCount: 0,
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    duePaymentSchedulesCount: duePaymentSchedules,
    permissions: const DashboardPermissionSummary(
      isOwner: true,
      canViewMoney: true,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: true,
      canManageMembers: true,
      canManageMoney: true,
      canManagePlan: true,
    ),
  );
}
