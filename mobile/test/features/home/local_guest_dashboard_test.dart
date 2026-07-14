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

    final royalSummary = summary.toDashboardSummary();
    expect(royalSummary.title, 'خطة زفاف صنعاء');
    expect(royalSummary.city, 'صنعاء - السبعين');
    expect(royalSummary.location?['fullLabel'], 'صنعاء - السبعين - حدة');
    expect(royalSummary.budgetTotal, '1000000');
    expect(royalSummary.remainingBudget, '1000000');
    expect(royalSummary.totalTasks, 0);
    expect(royalSummary.guestCount, 0);
    expect(royalSummary.providerCount, 0);
    expect(royalSummary.currentUserRole, 'GUEST');
    expect(royalSummary.permissions.role, 'GUEST_LOCAL');
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
      final royalSummary = summary!.toDashboardSummary();

      expect(summary.guestCount, 2);
      expect(summary.incompleteGuestCount, 1);
      expect(summary.taskCount, 1);
      expect(summary.confirmedCostTotal, '2500000');
      expect(summary.paidTotal, '500000');
      expect(summary.outstandingTotal, '2000000');
      expect(summary.duePaymentSchedulesCount, 1);
      expect(royalSummary.remainingBudget, '-1500000');
      expect(royalSummary.incompleteGuestsCount, 1);
      expect(royalSummary.unreadNotificationsCount, 0);
      expect(royalSummary.importantNotifications, isEmpty);
      expect(
        royalSummary.importantItems.map((item) => item.type),
        contains('PAYMENT_SCHEDULE_DUE'),
      );
      expect(
        royalSummary.recentActivity.map((item) => item.type),
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

      expect(find.text(summary.seed.title), findsOneWidget);
      // الترويسة الفخمة ترحّب بدور المستخدم ضمن تحية شخصية
      // («‹تحية›، العريس») بدل شعار العلامة المفرد في الودجت القديم.
      expect(find.textContaining('العريس'), findsOneWidget);
      expect(find.text('وضع تجربة التصميم'), findsNothing);

      final syncAction = find.byKey(const Key('royal-local-sync-action'));
      await tester.dragUntilVisible(
        syncAction,
        find.byKey(const Key('royal-home-guest-plan-test')),
        const Offset(0, -500),
      );

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(syncAction, findsOneWidget);
      await tester.tap(syncAction, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      expect(
        find.text(
          'المزامنة والمشاركة تحتاجان حساباً لحفظ الصلاحيات والبيانات بأمان.',
        ),
        findsOneWidget,
      );
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    },
  );

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

    await tester.tap(find.text(summary.seed.title), warnIfMissed: false);
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

    // Tap the bottom nav "المال" instead of swiping the carousel
    await tester.tap(find.text('المال'), warnIfMissed: false);
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

    expect(find.text('المهام'), findsWidgets);
    await tester.tap(find.text('المهام').first, warnIfMissed: false);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('tasks-opened'), findsOneWidget);
  });

  testWidgets('guest smart plus opens guests without a login blocker', (
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

    await tester.tap(find.byKey(const ValueKey('royal-smart-fab')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('إضافة ضيف'), findsOneWidget);
    await tester.tap(find.text('إضافة ضيف'), warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('guests-opened'), findsOneWidget);
  });

  testWidgets('guest smart plus quote request remains account-gated', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('royal-smart-fab')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    await tester.tap(find.text('طلب عرض سعر'), warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('تسجيل الدخول'), findsOneWidget);
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
