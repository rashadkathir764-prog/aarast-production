import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/utils/auth_action_guard.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/add_shared_member_screen.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const localPlanId = 'guest-plan-qa';
  const localMessage = AuthActionGuard.localPlanningSaveMessage;
  const cloudMessage = AuthActionGuard.protectedActionMessage;

  testWidgets('guest/local can add guest without login', (tester) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final guestsProvider = GuestsProvider(
      GuestsApi(harness.apiClient, offline: harness.offline),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<GuestsProvider>.value(value: guestsProvider),
        ],
        child: const MaterialApp(
          home: GuestListScreen(weddingPlanId: localPlanId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_textFieldWithLabel('اسم الضيف'), 'محمد علي');
    await tester.enterText(
      _textFieldWithLabel('رقم الجوال (اختياري)'),
      '777123456',
    );
    final sheetSubmit = find.widgetWithText(FilledButton, 'إضافة ضيف').last;
    await tester.ensureVisible(sheetSubmit);
    await tester.pumpAndSettle();
    await tester.tap(sheetSubmit);
    await tester.pumpAndSettle();

    expect(guestsProvider.guests, hasLength(1));
    expect(guestsProvider.guests.single.name, 'محمد علي');
    expect(guestsProvider.guests.single.phone, '+967777123456');
    expect(guestsProvider.noticeMessage, localMessage);
    expect(find.text('محمد علي'), findsOneWidget);
    expect(find.text(cloudMessage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest/local can add task without login', (tester) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final taskProvider = TaskTimelineProvider(
      TaskTimelineApi(harness.apiClient, offline: harness.offline),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<TaskTimelineProvider>.value(
            value: taskProvider,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: _router(
            start: CreateTaskScreen(weddingPlanId: localPlanId),
            targetPath: '/wedding-plans/:id/tasks',
            targetText: 'tasks-target',
          ),
        ),
      ),
    );

    await tester.enterText(
      _textFormFieldWithLabel('عنوان المهمة'),
      'حجز القاعة',
    );
    final submit = find.text('حفظ المهمة');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(taskProvider.tasks, hasLength(1));
    expect(taskProvider.tasks.single.title, 'حجز القاعة');
    expect(taskProvider.noticeMessage, localMessage);
    expect(find.text(cloudMessage), findsNothing);
    expect(find.text('tasks-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guest/local planning lists reload saved data from local storage',
    (tester) async {
      _setTallView(tester);
      final harness = await _createHarness();
      final guestsApi = GuestsApi(harness.apiClient, offline: harness.offline);
      final taskApi = TaskTimelineApi(
        harness.apiClient,
        offline: harness.offline,
      );
      final financeApi = FinanceApi(
        harness.apiClient,
        offline: harness.offline,
      );
      final budget = await financeApi.replaceMoneyBudget(
        planId: localPlanId,
        totalBudget: '2500000',
        currency: 'YER',
        categories: const [
          (id: null, name: 'الصالة', allocatedAmount: '2500000'),
        ],
      );
      final category = budget.categories.single;

      await guestsApi.createGuest(
        weddingPlanId: localPlanId,
        name: 'محمد علي',
        phone: '777123456',
        side: 'OTHER',
        status: 'INVITED',
        seatsCount: 1,
      );
      await taskApi.createTask(weddingPlanId: localPlanId, title: 'حجز القاعة');
      await financeApi.createCost(
        planId: localPlanId,
        title: 'دفعة القاعة',
        totalAmount: '500000',
        initialPaymentAmount: '500000',
        budgetCategoryId: category.id,
      );

      await _pumpLocalScreen(
        tester,
        harness,
        const GuestListScreen(weddingPlanId: localPlanId),
      );
      expect(find.text('محمد علي'), findsOneWidget);
      expect(find.text(cloudMessage), findsNothing);

      await _pumpLocalScreen(
        tester,
        harness,
        const TaskTimelineScreen(weddingPlanId: localPlanId),
      );
      expect(find.text('حجز القاعة'), findsOneWidget);
      expect(find.text(cloudMessage), findsNothing);

      await _pumpLocalScreen(
        tester,
        harness,
        const MoneyOverviewScreen(weddingPlanId: localPlanId),
      );
      await tester.scrollUntilVisible(
        find.text('دفعة القاعة').first,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('دفعة القاعة'), findsWidgets);
      expect(find.text(cloudMessage), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  test(
    'guest/local can add a cost with an initial payment without login',
    () async {
      final harness = await _createHarness();
      final financeProvider = FinanceProvider(
        FinanceApi(harness.apiClient, offline: harness.offline),
      );
      await financeProvider.loadMoney(localPlanId);
      expect(
        await financeProvider.saveBudget(
          planId: localPlanId,
          totalBudget: '500000',
          currency: 'YER',
          categories: const [
            (id: null, name: 'تكاليف عامة', allocatedAmount: '500000'),
          ],
        ),
        isTrue,
      );
      final category = financeProvider.categories.single;

      final cost = await financeProvider.createCost(
        planId: localPlanId,
        budgetCategoryId: category.id,
        title: 'دفعة القاعة',
        totalAmount: '500000',
        initialPaymentAmount: '500000',
      );

      expect(cost, isNotNull);
      expect(financeProvider.costs, hasLength(1));
      expect(financeProvider.costs.single.title, 'دفعة القاعة');
      expect(moneyValue(financeProvider.costs.single.paidAmount), 500000);
      expect(moneyValue(financeProvider.costs.single.remainingAmount), 0);
      expect(financeProvider.costs.single.budgetCategoryId, category.id);
      expect(financeProvider.noticeMessage, localMessage);
    },
  );

  test(
    'creating a cost does not create a payment schedule implicitly',
    () async {
      final harness = await _createHarness();
      final financeProvider = FinanceProvider(
        FinanceApi(harness.apiClient, offline: harness.offline),
      );
      await financeProvider.loadMoney(localPlanId);
      expect(
        await financeProvider.saveBudget(
          planId: localPlanId,
          totalBudget: '800000',
          currency: 'YER',
          categories: const [
            (id: null, name: 'الصالة', allocatedAmount: '800000'),
          ],
        ),
        isTrue,
      );
      final hallCategory = financeProvider.categories.single;

      final cost = await financeProvider.createCost(
        planId: localPlanId,
        budgetCategoryId: hallCategory.id,
        title: 'حجز صالة الأفراح',
        totalAmount: '800000',
      );

      expect(cost, isNotNull);
      expect(moneyValue(financeProvider.costs.single.paidAmount), 0);
      expect(moneyValue(financeProvider.costs.single.remainingAmount), 800000);
      expect(financeProvider.payments, isEmpty);
      expect(financeProvider.dueSchedules, isEmpty);
    },
  );

  testWidgets('protected share invite shows login gate for local plan', (
    tester,
  ) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final sharingProvider = SharingProvider(SharingApi(harness.apiClient));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<SharingProvider>.value(value: sharingProvider),
        ],
        child: const MaterialApp(
          home: AddSharedMemberScreen(weddingPlanId: localPlanId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateTitle), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateBody), findsOneWidget);
    expect(find.text(cloudMessage), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(sharingProvider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<_Harness> _createHarness() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  return _Harness(
    authStorage: authStorage,
    apiClient: apiClient,
    offline: offline,
  );
}

Future<void> _pumpLocalScreen(
  WidgetTester tester,
  _Harness harness,
  Widget screen,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: harness.authStorage),
        ChangeNotifierProvider<OfflineSyncService>.value(
          value: harness.offline,
        ),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(
            GuestsApi(harness.apiClient, offline: harness.offline),
          ),
        ),
        ChangeNotifierProvider<TaskTimelineProvider>(
          create: (_) => TaskTimelineProvider(
            TaskTimelineApi(harness.apiClient, offline: harness.offline),
          ),
        ),
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(
            FinanceApi(harness.apiClient, offline: harness.offline),
          ),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1600);
  addTearDown(tester.view.reset);
}

GoRouter _router({
  required Widget start,
  required String targetPath,
  required String targetText,
}) {
  return GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => start),
      GoRoute(
        path: targetPath,
        builder: (context, state) => Scaffold(body: Text(targetText)),
      ),
    ],
  );
}

Finder _textFormFieldWithLabel(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(TextFormField))
      .first;
}

Finder _textFieldWithLabel(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(TextField))
      .first;
}

class _Harness {
  const _Harness({
    required this.authStorage,
    required this.apiClient,
    required this.offline,
  });

  final AuthStorage authStorage;
  final ApiClient apiClient;
  final OfflineSyncService offline;
}
