import 'package:aarast_mobile/core/experience_v3/aarast_journey_sheet.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:aarast_mobile/features/home/screens/local_guest_dashboard_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local dashboard source derives honest guest summary', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    await storage.saveDraft(_guestPlan());

    final summary = await LocalGuestDashboardSummarySource(
      storage,
    ).loadSummary();

    expect(summary, isNotNull);
    expect(summary!.plan.guestPlanId, 'guest-plan-test');
    expect(summary.taskCount, 0);
    expect(summary.guestCount, 0);
    expect(summary.providerCount, 0);
    expect(summary.progressPercent, 0);
    expect(summary.seed.selectedCategories, ['hall', 'photo']);

    final dashboardSummary = summary.toDashboardSummary();
    expect(dashboardSummary.title, 'خطة زفاف صنعاء');
    expect(dashboardSummary.city, 'صنعاء - السبعين');
    expect(dashboardSummary.location?['fullLabel'], 'صنعاء - السبعين - حدة');
    expect(dashboardSummary.budgetTotal, '1000000');
    expect(dashboardSummary.remainingBudget, '1000000');
    expect(dashboardSummary.totalTasks, 0);
    expect(dashboardSummary.guestCount, 0);
    expect(dashboardSummary.providerCount, 0);
    expect(dashboardSummary.currentUserRole, 'GUEST');
    expect(dashboardSummary.permissions.role, 'GUEST_LOCAL');
  });

  test(
    'local dashboard source reflects saved planning data after reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final storage = GuestOnboardingStorage(preferences);
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final offline = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      const planId = 'guest-plan-test';
      await storage.saveDraft(_guestPlan());

      await GuestsApi(apiClient, offline: offline).createGuest(
        weddingPlanId: planId,
        name: 'محمد علي',
        phone: '777123456',
        side: 'OTHER',
        status: 'INVITED',
        seatsCount: 1,
      );
      await GuestsApi(apiClient, offline: offline).createGuest(
        weddingPlanId: planId,
        name: 'guest-without-phone',
        side: 'OTHER',
        status: 'INVITED',
        seatsCount: 1,
      );
      await TaskTimelineApi(
        apiClient,
        offline: offline,
      ).createTask(weddingPlanId: planId, title: 'حجز القاعة');
      final now = DateTime.now();
      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {
          'id': 'cost-hall',
          'planId': planId,
          'weddingPlanId': planId,
          'budgetCategoryId': 'category-hall',
          'title': 'القاعة',
          'totalAmount': '2500000',
          'paidAmount': '500000',
          'status': 'PARTIALLY_PAID',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-hall',
          'planId': planId,
          'weddingPlanId': planId,
          'costId': 'cost-hall',
          'amount': '2000000',
          'dueDate': now.add(const Duration(days: 7)).toIso8601String(),
          'status': 'PENDING',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );

      final summary = await LocalGuestDashboardSummarySource(
        storage,
        database: database,
      ).loadSummary();
      final dashboardSummary = summary!.toDashboardSummary();

      expect(summary.guestCount, 2);
      expect(summary.incompleteGuestCount, 1);
      expect(summary.taskCount, 1);
      expect(summary.confirmedCostTotal, '2500000');
      expect(summary.paidTotal, '500000');
      expect(summary.outstandingTotal, '2000000');
      expect(summary.duePaymentSchedulesCount, 1);
      expect(dashboardSummary.remainingBudget, '-1500000');
      expect(dashboardSummary.incompleteGuestsCount, 1);
      expect(dashboardSummary.unreadNotificationsCount, 0);
      expect(dashboardSummary.importantNotifications, isEmpty);
      expect(
        dashboardSummary.importantItems.map((item) => item.type),
        contains('PAYMENT_SCHEDULE_DUE'),
      );
      expect(
        dashboardSummary.recentActivity.map((item) => item.type),
        containsAll(['LOCAL_GUEST', 'LOCAL_TASK', 'LOCAL_MONEY_COST']),
      );
    },
  );

  testWidgets(
    'dashboard opens local guest plan and shows lightweight protected sync message',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());

      await tester.pumpWidget(
        Provider<AuthStorage>.value(
          value: authStorage,
          child: MaterialApp(home: LocalGuestDashboardScreen(summary: summary)),
        ),
      );

      expect(find.textContaining(summary.seed.title), findsAtLeastNWidgets(1));
      // الترويسة ترحّب بدور المستخدم وتعرض أولوية الخطة دون أرقام وهمية.
      // The home greets by name, never by role; this title holds no name.
      expect(find.text('أهلًا فيك'), findsOneWidget);
      expect(find.textContaining('العريس'), findsNothing);
      expect(find.text('وضع تجربة التصميم'), findsNothing);

      final syncAction = find.byKey(const Key('aarast-local-sync-action'));
      await tester.dragUntilVisible(
        syncAction,
        find.byKey(const ValueKey('aarast-home-guest-plan-test')),
        const Offset(0, -500),
      );

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(syncAction, findsOneWidget);
      // RA-MO-27: the pill is touched in a 48 band.
      expect(tester.getSize(syncAction).height, greaterThanOrEqualTo(48));
      await tester.tap(syncAction, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      expect(
        find.text('الحفظ والمشاركة يبغين حساب، عشان نحفظ خطتك ومين يشوف ايش.'),
        findsOneWidget,
      );
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    },
  );

  // RA-MO-22: D22 and C12 make the home after the wedding the debt. A plan
  // kept on the phone used to drop it (its debt was assumed the server's),
  // leaving the greeting and the box alone.
  testWidgets('a phone-only plan after its wedding shows what it still owes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final plan = _guestPlan().copyWith(
      weddingDate: DateTime.now().subtract(const Duration(days: 10)),
    );
    const metrics = LocalDashboardMetrics(
      taskCount: 0,
      completedTaskCount: 0,
      overdueTaskCount: 0,
      todayTaskCount: 0,
      guestCount: 0,
      confirmedGuestCount: 0,
      pendingGuestCount: 0,
      declinedGuestCount: 0,
      incompleteGuestCount: 0,
      confirmedCostTotal: 4200000,
      paidTotal: 2300000,
      outstandingTotal: 1900000,
      duePaymentSchedulesCount: 0,
      overduePaymentSchedulesCount: 0,
      dueSoonPaymentSchedulesCount: 0,
      nextPaymentScheduleDue: null,
      importantItems: [],
      recentActivity: [],
    );
    final summary = LocalGuestDashboardSummary.fromPlan(plan, metrics: metrics);

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp(home: LocalGuestDashboardScreen(summary: summary)),
      ),
    );
    await tester.pump();

    expect(find.text('بعد العرس'), findsOneWidget);
    expect(find.text('1.9'), findsOneWidget);
    expect(find.text('مليون باقي عليك'), findsOneWidget);
    expect(find.text('سددت 2.3 مليون ر.ي من 4.2 مليون ر.ي'), findsOneWidget);
    // No bookings without an account, so no providers to rate.
    expect(find.text('قيّم'), findsNothing);
  });

  testWidgets('guest plan hero opens plan center with local summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LocalGuestDashboardScreen(summary: summary),
        ),
        GoRoute(
          path: '/wedding-plans/:id/plan-center',
          builder: (context, state) {
            final extra = state.extra;
            final localSummary = extra is Map
                ? extra['summary'] as DashboardSummary?
                : null;
            return Scaffold(
              body: Text('plan-center:${localSummary?.title ?? 'missing'}'),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('aarast-dashboard-plan-moment')),
      warnIfMissed: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('plan-center:${summary.seed.title}'), findsOneWidget);
  });

  testWidgets('guest opens money and tasks without a login gate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LocalGuestDashboardScreen(summary: summary),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money',
          builder: (context, state) =>
              const Scaffold(body: Text('money-opened')),
        ),
        GoRoute(
          path: '/wedding-plans/:id/tasks',
          builder: (context, state) =>
              const Scaffold(body: Text('tasks-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final moneyNav = find.descendant(
      of: find.byType(AarastPlanNavigationBar),
      matching: find.text('المال'),
    );
    await tester.tap(moneyNav, warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('money-opened'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('money-opened'), findsOneWidget);

    router.go('/');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    final tasksNav = find.descendant(
      of: find.byType(AarastPlanNavigationBar),
      matching: find.text('المهام'),
    );
    await tester.tap(tasksNav, warnIfMissed: false);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('tasks-opened'), findsOneWidget);
  });

  testWidgets('a tab replaces the home: one tab bar, not two', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LocalGuestDashboardScreen(summary: summary),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money',
          builder: (context, state) =>
              const Scaffold(body: Text('money-opened')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AarastPlanNavigationBar),
        matching: find.text('المال'),
      ),
      warnIfMissed: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('money-opened'), findsOneWidget);
    // Pushed, the home and its tab bar stayed underneath the tab's own.
    expect(
      find.byType(LocalGuestDashboardScreen, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('guest opens guests from the tab without a login blocker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LocalGuestDashboardScreen(summary: summary),
        ),
        GoRoute(
          path: '/wedding-plans/:id/guests',
          builder: (context, state) =>
              const Scaffold(body: Text('guests-opened')),
        ),
        GoRoute(
          path: '/wedding-plans/:id/guests/add',
          builder: (context, state) =>
              const Scaffold(body: Text('guests-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final guestsNav = find.descendant(
      of: find.byType(AarastPlanNavigationBar),
      matching: find.text('الضيوف'),
    );
    await tester.tap(guestsNav, warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('guests-opened'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('guest «+» opens the guest form without a login blocker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LocalGuestDashboardScreen(summary: summary),
        ),
        GoRoute(
          path: '/wedding-plans/:id/guests/add',
          builder: (context, state) =>
              const Scaffold(body: Text('guest-add-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // D33: the plan kept on the phone has the «+» on its home.
    await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.byType(JourneySheetBody), findsOneWidget);
    // The guest owns the plan, so its money choice is offered.
    expect(find.text('إضافة اتفاق'), findsOneWidget);
    await tester.tap(find.text('إضافة ضيف'), warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('guest-add-opened'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('guest «+» quote request remains account-gated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());

    await tester.pumpWidget(
      Provider<AuthStorage>.value(
        value: authStorage,
        child: MaterialApp(home: LocalGuestDashboardScreen(summary: summary)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('aarast-quick-action')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    await tester.tap(find.text('طلب عرض سعر'), warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  // RA-MO-20 (D11): a plan kept on the phone counts its days from today in
  // Sana'a too, as the server counts an account plan's.
  test('a phone plan counts its days from today in Sana\'a', () {
    final plan = _guestPlan().copyWith(weddingDate: DateTime(2026, 11, 7));
    // 22:00 UTC on the 6th is 01:00 on the 7th in Sana'a.
    final summary = LocalGuestDashboardSummary.fromPlan(
      plan,
      now: DateTime.utc(2026, 11, 6, 22),
    );
    expect(summary.daysRemaining, 0);
    // RA-TS-03 (39c2fc0): the day after is a day past, not «اليوم عرسك»:
    // the count is not clamped at zero.
    final after = LocalGuestDashboardSummary.fromPlan(
      plan,
      now: DateTime.utc(2026, 11, 8, 9),
    );
    expect(after.daysRemaining, -1);
  });
}

GuestOnboardingDraft _guestPlan() {
  return GuestOnboardingDraft(
    guestPlanId: 'guest-plan-test',
    planName: 'خطة زفاف صنعاء',
    createdAt: DateTime.utc(2026, 6, 19),
    isGuestPlan: true,
    needsSync: true,
    selectedPath: GuestOnboardingPath.weddingUser,
    persona: GuestPersona.groom,
    governorate: 'صنعاء',
    city: 'صنعاء',
    district: 'السبعين',
    neighborhood: 'حدة',
    street: null,
    addressNote: null,
    weddingDate: DateTime.now().add(const Duration(days: 90)),
    weddingDateUnknown: false,
    priorities: const ['budget', 'tasks'],
    currency: 'YER',
    estimatedBudget: '1000000',
    selectedCategoryKeys: const ['hall', 'photo'],
  );
}
