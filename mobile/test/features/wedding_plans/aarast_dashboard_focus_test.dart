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

  // D78 (RA-MO-147): a plan kept on the phone, which no server orders, walks
  // the chain here in D78's order: budget, first agreement, guests.
  test('a phone plan: urgent first, then each missing basic in D78 order', () {
    // A due payment outranks every basic.
    expect(
      resolveDashboardFocus(
        _summary(duePaymentSchedules: 1, hasBudget: false, onPhone: true),
      ).target,
      AarastDashboardFocusTarget.money,
    );
    expect(
      resolveDashboardFocus(_summary(hasBudget: false, onPhone: true)).title,
      contains('ميزانية'),
    );
    expect(
      resolveDashboardFocus(_summary(onPhone: true)).title,
      'سجّل أول اتفاق',
    );
    expect(
      resolveDashboardFocus(_summary(onPhone: true, agreed: '400000')).title,
      'أضف أول ضيف',
    );
  });

  // D78 (RA-MO-147): an account plan's chain is the server's. An empty list
  // means it found nothing missing for this reader; the phone used to add
  // «أضف أول بند» and «أضف أول مهمة» of its own.
  test('an account plan is asked no basic the server did not send', () {
    final focus = resolveDashboardFocus(
      _summary(hasBudget: false, budgetItems: 0),
    );
    expect(focus.title, 'ما فيه شي مستعجل');
    expect(focus.target, AarastDashboardFocusTarget.plan);
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
      _summary(hasBudget: false, providerCount: 0, onPhone: true),
    );
    // A phone plan's money opens where its budget is.
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
  int? budgetItems,

  /// A plan kept on the phone, no account behind it.
  bool onPhone = false,
  String? agreed,
}) {
  return DashboardSummary(
    accountBacked: !onPhone,
    dataScope: onPhone ? 'LOCAL' : 'ACCOUNT_BACKED',
    confirmedCostTotal: agreed,
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
