import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows the real plan team at 320px RTL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    var sharingOpens = 0;

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
              now: DateTime(2026, 7, 7, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () => sharingOpens += 1,
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    );

    final sharing = find.byKey(const ValueKey('aarast-dashboard-sharing'));
    await tester.ensureVisible(sharing);
    await tester.pumpAndSettle();

    expect(find.text('فريق الخطة'), findsOneWidget);
    // RA-MO-148: the server's count is the members and the owner
    // (`participantMembersCount + 1`); the row counts the people the owner
    // brought in. It used to read «4 مشاركين» for three.
    expect(find.text('3 مشاركين · دعوتين تنتظر الرد'), findsOneWidget);

    await tester.tap(sharing);
    await tester.pump();
    expect(sharingOpens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an owner alone is not counted as a participant', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _summary(participantCount: 1, pendingInvites: 0),
              userName: 'رشاد',
              bottomPadding: 24,
              now: DateTime(2026, 7, 7, 9),
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('aarast-dashboard-sharing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('لسا ما أضفت أحد'), findsOneWidget);
    expect(find.text('مشارك واحد'), findsNothing);
  });

  testWidgets(
    'the home keeps the next step, money and the three counts under the hero',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 900);
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
                now: DateTime(2026, 7, 7, 9),
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

      final hero = find.byKey(const ValueKey('aarast-dashboard-plan-moment'));
      expect(hero, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'aarast-dashboard-next-step-',
              ),
        ),
        findsOneWidget,
      );
      for (final tile in ['tasks', 'guests', 'providers']) {
        final found = find.byKey(ValueKey('aarast-dashboard-tile-$tile'));
        expect(found, findsOneWidget);
        expect(
          tester.getTopLeft(found).dy,
          greaterThan(tester.getBottomLeft(hero).dy),
        );
      }
      expect(
        find.byKey(const ValueKey('aarast-dashboard-money-card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Q-20: on the wedding day a payment and tasks due today show, '
      'one line each, and open', (tester) async {
    final day = DateTime(2026, 7, 7);
    final taps = await _pumpWeddingDays(
      tester,
      now: DateTime(2026, 7, 7, 13),
      summary: _summary(
        weddingDate: day,
        todayTasks: 2,
        nextPayment: DashboardNextPaymentSchedule(
          id: 's1',
          weddingCostId: 'c1',
          title: 'قاعة سبأ',
          amount: '500000',
          status: 'PENDING',
          dueDate: day,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('aarast-home-today')), findsOneWidget);
    expect(find.text('دفعة اليوم'), findsOneWidget);
    expect(find.textContaining('قاعة سبأ'), findsOneWidget);
    expect(find.text('مهام اليوم'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('aarast-home-today-payment')));
    await tester.tap(find.byKey(const ValueKey('aarast-home-today-tasks')));
    expect(taps.payments(), 1);
    expect(taps.tasks(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Q-20: nothing due today, no line; a payment of another day '
      'is not today\'s', (tester) async {
    final day = DateTime(2026, 7, 7);
    await _pumpWeddingDays(
      tester,
      now: DateTime(2026, 7, 7, 13),
      summary: _summary(
        weddingDate: day,
        nextPayment: DashboardNextPaymentSchedule(
          id: 's1',
          weddingCostId: 'c1',
          title: 'قاعة سبأ',
          amount: '500000',
          status: 'PENDING',
          dueDate: DateTime(2026, 7, 20),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('aarast-home-today')), findsNothing);
  });

  testWidgets('the wedding day home is the day\'s programme (b05, D65)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1400);
    addTearDown(tester.view.reset);
    var opens = 0;
    final events = PlanEventsView(
      weddingPlanId: 'plan-1',
      canEdit: true,
      suggestions: const [],
      items: [
        PlanEvent(
          id: 'lunch',
          type: PlanEventType.lunch,
          date: DateTime(2026, 7, 7),
          slot: PlanEventSlot.dhuhr,
          placeLabel: 'بيت الوالد',
        ),
        PlanEvent(
          id: 'wedding',
          type: PlanEventType.wedding,
          date: DateTime(2026, 7, 7),
          slot: PlanEventSlot.afterAsr,
          placeLabel: 'قاعة سبأ',
        ),
        PlanEvent(
          id: 'samra',
          type: PlanEventType.samra,
          date: DateTime(2026, 7, 5),
          slot: PlanEventSlot.afterIsha,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _summary(weddingDate: DateTime(2026, 7, 7)),
              userName: 'رشاد',
              bottomPadding: 24,
              now: DateTime(2026, 7, 7, 13),
              events: events,
              onOpenEvents: () => opens += 1,
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

    expect(find.text('مبروك يا عريس'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('aarast-dashboard-day-hero')),
      findsOneWidget,
    );
    expect(find.text('برنامج اليوم'), findsOneWidget);
    // Only the day's events, by their time; the lunch has started.
    expect(find.text('الغداء'), findsOneWidget);
    expect(find.text('الزفاف'), findsOneWidget);
    expect(find.text('السمرة'), findsNothing);
    expect(find.text('الآن'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });
}

// D112 (Q-20), the owner's word: the wedding's week and day hide the money
// and the tasks, and a payment or a task whose day is today still shows, in
// one line each.
Future<({int Function() payments, int Function() tasks})> _pumpWeddingDays(
  WidgetTester tester, {
  required DateTime now,
  required DashboardSummary summary,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.reset);
  var payments = 0;
  var tasks = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AarastDashboardView(
            summary: summary,
            userName: 'رشاد',
            bottomPadding: 24,
            now: now,
            onNotifications: () {},
            onProfile: () {},
            onOpenPlan: () {},
            onOpenMoney: () {},
            onOpenTasks: () => tasks += 1,
            onOpenProviders: () {},
            onOpenGuests: () {},
            onOpenSharing: () {},
            onOpenNextStep: () {},
            onOpenImportantItem: (_) {},
            onOpenPayment: (_) => payments += 1,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (payments: () => payments, tasks: () => tasks);
}

DashboardSummary _summary({
  DateTime? weddingDate,
  int participantCount = 4,
  int pendingInvites = 2,
  int todayTasks = 0,
  DashboardNextPaymentSchedule? nextPayment,
}) {
  return DashboardSummary(
    planId: 'plan-1',
    title: 'خطة الزفاف',
    status: 'PLANNING',
    progressPercentage: 45,
    weddingDate: weddingDate ?? DateTime(2026, 12, 20),
    daysRemaining: 166,
    city: 'صنعاء',
    budgetTotal: '1000000',
    confirmedCostTotal: '250000',
    paidTotal: '100000',
    outstandingTotal: '150000',
    remainingBudget: '750000',
    totalTasks: 3,
    completedTasks: 1,
    overdueTasks: 0,
    todayTasks: todayTasks,
    nextPaymentScheduleDue: nextPayment,
    guestCount: 25,
    // A running plan: its first steps are done (b01).
    venueSecured: true,
    confirmedGuests: 10,
    providerCount: 1,
    quoteRequestsCount: 1,
    participantCount: participantCount,
    pendingInvites: pendingInvites,
    currentUserRole: 'OWNER',
    unreadNotificationsCount: 0,
    importantItems: const [],
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
