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

    // D72: finding providers is a suggestion now, never «خطوتك الجاية».
    expect(
      resolveDashboardFocus(_summary(providerCount: 0)).target,
      isNot(AarastDashboardFocusTarget.providers),
    );
  });

  test('D72: urgent first, then each missing basic in order', () {
    // A due payment outranks every basic.
    expect(
      resolveDashboardFocus(
        _summary(duePaymentSchedules: 1, hasBudget: false),
      ).target,
      AarastDashboardFocusTarget.money,
    );
    // Budget, then the mahr, then the first item.
    expect(
      resolveDashboardFocus(
        _summary(hasBudget: false),
        mahrMissing: true,
      ).title,
      contains('ميزانية'),
    );
    expect(
      resolveDashboardFocus(_summary(), mahrMissing: true).target,
      AarastDashboardFocusTarget.mahr,
    );
    expect(
      resolveDashboardFocus(_summary(budgetItems: 0)).title,
      'أضف أول بند',
    );
    // An unknown count (no money rights, or an older server) asks nothing.
    expect(resolveDashboardFocus(_summary()).title, isNot('أضف أول بند'));
  });

  test('the next step counts in Arabic and names its action', () {
    final two = resolveDashboardFocus(_summary(overdueTasks: 2));
    expect(two.title, 'مهمتين متأخرة');
    expect(two.actionLabel, 'رتّب المهام');

    final eleven = resolveDashboardFocus(_summary(overdueTasks: 11));
    expect(eleven.title, '11 مهمة متأخرة');

    final money = resolveDashboardFocus(_summary(duePaymentSchedules: 3));
    expect(money.reason, startsWith('عندك 3 مواعيد دفع'));
    expect(money.actionLabel, 'افتح المال');
    // No formal «لديك».
    expect(money.reason, isNot(contains('لديك')));
  });

  test('missing budget remains more important than discovering providers', () {
    final focus = resolveDashboardFocus(
      _summary(hasBudget: false, providerCount: 0),
    );
    // The step's button says «حدّد الميزانية», so it opens the budget (w19)
    // and not the money tab's root, which is what `money` means.
    expect(focus.target, AarastDashboardFocusTarget.budget);
    expect(focus.title, contains('ميزانية'));
  });
}

DashboardSummary _summary({
  bool hasBudget = true,
  int duePaymentSchedules = 0,
  int overdueTasks = 0,
  int incompleteGuests = 0,
  int providerCount = 1,
  int? budgetItems,
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
    budgetItemsCount: budgetItems,
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
