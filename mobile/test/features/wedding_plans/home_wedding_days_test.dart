import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// The home on the wedding's week, its day and after it, read on Sana'a's day
// and clock whatever zone the phone is in (RA-MO-354), with the events after
// the day (RA-MO-352) and the way to the memories (RA-MO-356).

final _wedding = DateTime(2027, 1, 21);

PlanEventsView _events(List<Map<String, Object?>> items) =>
    PlanEventsView.fromJson({
      'weddingPlanId': 'plan-1',
      'canEdit': true,
      'items': items,
      'suggestions': const [],
    });

Future<void> _pump(
  WidgetTester tester, {
  required DateTime now,
  required PlanEventsView events,
  VoidCallback? onArchivePlan,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 2200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AarastDashboardView(
            summary: _summary(),
            userName: 'رشاد',
            bottomPadding: 24,
            now: now,
            events: events,
            onArchivePlan: onArchivePlan,
            onNotifications: () {},
            onProfile: () {},
            onOpenPlan: () {},
            onOpenMoney: () {},
            onOpenTasks: () {},
            onOpenProviders: () {},
            onOpenGuests: () {},
            onOpenSharing: () {},
            onOpenNextStep: () {},
            onOpenImportantItem: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Row)).first;

void main() {
  // 22:00 UTC on the 17th is 01:00 on the 18th in Sana'a: the phone (here
  // on UTC) still read the 17th, so the night past was «الليلة».
  testWidgets('the week\'s «الليلة» is Sana\'a\'s night', (tester) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 1, 17, 22),
      events: _events([
        {'id': 's', 'type': 'SAMRA', 'date': '2027-01-17'},
        {'id': 'm', 'type': 'MAQEEL', 'date': '2027-01-18'},
        {'id': 'w', 'type': 'WEDDING', 'date': '2027-01-21'},
      ]),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-week-program')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _rowOf('المقيل'), matching: find.text('الليلة')),
      findsOneWidget,
    );
    // The samra's night has passed: one tick, its own.
    expect(find.byIcon(LucideIcons.checkCircle), findsOneWidget);
  });

  // 13:00 UTC is 16:00 in Sana'a: the wedding (after the asr) is under
  // way, not the lunch the phone's own hour pointed at.
  testWidgets('the day\'s «الحين» is the hour in Sana\'a', (tester) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 1, 21, 13),
      events: _events([
        {'id': 'l', 'type': 'LUNCH', 'date': '2027-01-21', 'timeSlot': 'DHUHR'},
        {
          'id': 'w',
          'type': 'WEDDING',
          'date': '2027-01-21',
          'timeSlot': 'AFTER_ASR',
        },
      ]),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-day-program')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _rowOf('الزفاف'), matching: find.text('الحين')),
      findsOneWidget,
    );
  });

  // RA-MO-352 (Q-46): the events after the wedding's day showed nowhere.
  testWidgets('after the day, its own events are its programme', (
    tester,
  ) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 1, 22, 6),
      events: _events([
        {'id': 'w', 'type': 'WEDDING', 'date': '2027-01-21'},
        {
          'id': 'sb',
          'type': 'CUSTOM',
          'title': 'الصبحية',
          'date': '2027-01-22',
          'timeSlot': 'DUHA',
        },
        {'id': 'g', 'type': 'LUNCH', 'date': '2027-01-24'},
      ]),
    );

    final program = find.byKey(
      const ValueKey('aarast-dashboard-after-program'),
    );
    expect(program, findsOneWidget);
    expect(
      find.descendant(of: program, matching: find.text('الصبحية')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: program, matching: find.text('الغداء')),
      findsOneWidget,
    );
    // The wedding itself is not «after» it; a morning is not «الليلة».
    expect(
      find.descendant(of: program, matching: find.text('الزفاف')),
      findsNothing,
    );
    expect(
      find.descendant(of: _rowOf('الصبحية'), matching: find.text('اليوم')),
      findsOneWidget,
    );
  });

  testWidgets('once they have passed, the after programme goes', (
    tester,
  ) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 2, 10, 6),
      events: _events([
        {
          'id': 'sb',
          'type': 'CUSTOM',
          'title': 'الصبحية',
          'date': '2027-01-22',
        },
      ]),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-after-program')),
      findsNothing,
    );
  });

  // RA-MO-356: nothing after the wedding offered to put the plan away.
  testWidgets('after the day, the home offers «الذكريات»', (tester) async {
    var archived = 0;
    await _pump(
      tester,
      now: DateTime.utc(2027, 2, 10, 6),
      events: _events(const []),
      onArchivePlan: () => archived += 1,
    );

    final offer = find.byKey(const ValueKey('aarast-home-after-memories'));
    await tester.ensureVisible(offer);
    await tester.tap(offer);
    expect(archived, 1);
  });

  testWidgets('before the day, no «الذكريات»', (tester) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 1, 17, 9),
      events: _events(const []),
      onArchivePlan: () {},
    );

    expect(
      find.byKey(const ValueKey('aarast-home-after-memories')),
      findsNothing,
    );
  });

  // RA-MO-354: the copy said six days where the week is seven.
  testWidgets('the wedding week is the seven days before it', (tester) async {
    await _pump(
      tester,
      now: DateTime.utc(2027, 1, 1, 9),
      events: _events(const []),
    );

    await tester.tap(find.byKey(const ValueKey('aarast-dashboard-moment-tag')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('aarast-dashboard-moments-sheet')),
      findsOneWidget,
    );
    expect(find.text('الأيام السبعة قبل العرس'), findsOneWidget);
    expect(find.textContaining('الستة'), findsNothing);
  });
}

DashboardSummary _summary() {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'عرس رشاد',
    status: 'PLANNING',
    progressPercentage: 45,
    weddingDate: _wedding,
    daysRemaining: null,
    city: 'صنعاء',
    budgetTotal: '1000000',
    confirmedCostTotal: '250000',
    paidTotal: '100000',
    outstandingTotal: '150000',
    remainingBudget: '750000',
    totalTasks: 3,
    completedTasks: 1,
    overdueTasks: 0,
    todayTasks: 0,
    guestCount: 25,
    venueSecured: true,
    confirmedGuests: 10,
    providerCount: 1,
    quoteRequestsCount: 1,
    participantCount: 4,
    pendingInvites: 2,
    currentUserRole: 'OWNER',
    unreadNotificationsCount: 0,
    importantItems: const [],
    nextPaymentScheduleDue: null,
    planProviders: const [],
    importantNotifications: const [],
    permissions: const DashboardPermissionSummary(
      isOwner: true,
      canViewMoney: true,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: true,
      canManageMembers: true,
      canManageMoney: true,
      canManagePlan: true,
      role: 'OWNER',
    ),
  );
}
