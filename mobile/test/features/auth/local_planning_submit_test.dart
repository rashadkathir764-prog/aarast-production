import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/utils/auth_action_guard.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/debts/providers/debt_installment_provider.dart';
import 'package:aarast_mobile/features/debts/screens/create_debt_screen.dart';
import 'package:aarast_mobile/features/debts/screens/debt_installment_screen.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_expense_screen.dart';
import 'package:aarast_mobile/features/finance/screens/create_expense_screen.dart';
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
      final financeApi = BudgetExpenseApi(
        harness.apiClient,
        offline: harness.offline,
      );
      final debtApi = DebtInstallmentApi(
        harness.apiClient,
        offline: harness.offline,
      );
      final category = await financeApi.createBudgetCategory(
        weddingPlanId: localPlanId,
        name: 'الصالة',
        targetAmount: '2500000',
      );

      await guestsApi.createGuest(
        weddingPlanId: localPlanId,
        name: 'محمد علي',
        phone: '777123456',
        side: 'OTHER',
        status: 'INVITED',
        seatsCount: 1,
      );
      await taskApi.createTask(weddingPlanId: localPlanId, title: 'حجز القاعة');
      await financeApi.createExpense(
        weddingPlanId: localPlanId,
        title: 'دفعة القاعة',
        amount: '500000',
        budgetCategoryId: category.id,
      );
      await debtApi.createDebt(
        weddingPlanId: localPlanId,
        creditorName: 'القاعة',
        title: 'باقي القاعة',
        totalAmount: '2000000',
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
        const BudgetExpenseScreen(weddingPlanId: localPlanId),
      );
      await tester.scrollUntilVisible(
        find.text('دفعة القاعة'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('دفعة القاعة'), findsOneWidget);
      expect(find.text(cloudMessage), findsNothing);

      await _pumpLocalScreen(
        tester,
        harness,
        const DebtInstallmentScreen(weddingPlanId: localPlanId),
      );
      expect(find.text('باقي القاعة'), findsOneWidget);
      expect(find.text(cloudMessage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guest/local can add expense without login', (tester) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final financeProvider = FinanceProvider(
      BudgetExpenseApi(harness.apiClient, offline: harness.offline),
    );
    await financeProvider.createBudgetCategory(
      weddingPlanId: localPlanId,
      name: 'مصروفات عامة',
      targetAmount: '500000',
    );
    final category = financeProvider.budgetCategories.single;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
        ],
        child: MaterialApp.router(
          routerConfig: _router(
            start: CreateExpenseScreen(
              weddingPlanId: localPlanId,
              initialBudgetCategoryId: category.id,
            ),
            targetPath: '/wedding-plans/:id/finance',
            targetText: 'finance-target',
          ),
        ),
      ),
    );

    await tester.enterText(
      _textFormFieldWithLabel('عنوان المصروف المدفوع'),
      'دفعة القاعة',
    );
    await tester.enterText(_textFormFieldWithLabel('المبلغ المدفوع'), '500000');
    final submit = find.text('حفظ المصروف');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(financeProvider.expenses, hasLength(1));
    expect(financeProvider.expenses.single.title, 'دفعة القاعة');
    expect(financeProvider.expenses.single.amount, '500000');
    expect(financeProvider.expenses.single.budgetCategoryId, category.id);
    expect(financeProvider.noticeMessage, localMessage);
    expect(find.text(cloudMessage), findsNothing);
    expect(find.text('finance-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hall category records paid expense without remaining reminder', (
    tester,
  ) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final financeProvider = FinanceProvider(
      BudgetExpenseApi(harness.apiClient, offline: harness.offline),
    );
    final debtProvider = DebtInstallmentProvider(
      DebtInstallmentApi(harness.apiClient, offline: harness.offline),
    );
    await financeProvider.createBudgetCategory(
      weddingPlanId: localPlanId,
      name: 'الصالة',
      targetAmount: '800000',
    );
    final hallCategory = financeProvider.budgetCategories.single;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
          ChangeNotifierProvider<DebtInstallmentProvider>.value(
            value: debtProvider,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: _router(
            start: CreateExpenseScreen(
              weddingPlanId: localPlanId,
              initialBudgetCategoryId: hallCategory.id,
            ),
            targetPath: '/wedding-plans/:id/finance',
            targetText: 'finance-target',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اسم الصالة'), findsNothing);
    expect(find.text('مبلغ هذه الدفعة'), findsNothing);
    expect(find.text('ذكرني بدفع الباقي'), findsNothing);
    expect(
      find.text('يُحفظ هذا السجل كمصروف مدفوع فعلاً فقط.'),
      findsOneWidget,
    );

    await tester.enterText(
      _textFormFieldWithLabel('عنوان المصروف المدفوع'),
      'دفعة صالة الأفراح',
    );
    await tester.enterText(_textFormFieldWithLabel('المبلغ المدفوع'), '200000');
    final submit = find.text('حفظ المصروف');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(financeProvider.expenses, hasLength(1));
    expect(financeProvider.expenses.single.title, 'دفعة صالة الأفراح');
    expect(financeProvider.expenses.single.amount, '200000');
    expect(financeProvider.expenses.single.budgetCategoryId, hallCategory.id);
    expect(debtProvider.debts, isEmpty);
    expect(debtProvider.installments, isEmpty);
    expect(find.text(cloudMessage), findsNothing);
    expect(find.text('finance-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest/local can add debt without login when local mode exists', (
    tester,
  ) async {
    _setTallView(tester);
    final harness = await _createHarness();
    final debtProvider = DebtInstallmentProvider(
      DebtInstallmentApi(harness.apiClient, offline: harness.offline),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<DebtInstallmentProvider>.value(
            value: debtProvider,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: _router(
            start: CreateDebtScreen(weddingPlanId: localPlanId),
            targetPath: '/wedding-plans/:id/debts',
            targetText: 'debts-target',
          ),
        ),
      ),
    );

    await tester.enterText(
      _textFormFieldWithLabel('لمن باقي المبلغ؟'),
      'القاعة',
    );
    await tester.enterText(
      _textFormFieldWithLabel('عنوان المبلغ'),
      'باقي القاعة',
    );
    await tester.enterText(_textFormFieldWithLabel('إجمالي المبلغ'), '2000000');
    final submit = find.text('حفظ المبلغ');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(debtProvider.debts, hasLength(1));
    expect(debtProvider.debts.single.title, 'باقي القاعة');
    expect(debtProvider.debts.single.totalAmount, '2000000');
    expect(debtProvider.noticeMessage, localMessage);
    expect(find.text(cloudMessage), findsNothing);
    expect(find.text('debts-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
            BudgetExpenseApi(harness.apiClient, offline: harness.offline),
          ),
        ),
        ChangeNotifierProvider<DebtInstallmentProvider>(
          create: (_) => DebtInstallmentProvider(
            DebtInstallmentApi(harness.apiClient, offline: harness.offline),
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
