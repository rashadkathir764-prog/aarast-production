import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_starter_catalog.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// R4: a task about a money item or a payment leads to it, and says when the
// booking or the payment finished it.

void main() {
  test('the link and how the task closed survive reading and copying', () {
    final task = WeddingTask.fromJson({
      'id': 'task-1',
      'weddingPlanId': 'plan-1',
      'title': 'ادفع دفعة القاعة',
      'status': 'DONE',
      'priority': 'HIGH',
      'linkedCostId': 'cost-hall',
      'linkedScheduleId': 'schedule-2',
      'autoClosedAt': '2026-11-01T10:00:00.000Z',
    });

    expect(task.linkedCostId, 'cost-hall');
    expect(task.linkedScheduleId, 'schedule-2');
    expect(task.closedByLink, isTrue);
    expect(task.copyWith(title: 'x').linkedScheduleId, 'schedule-2');
    expect(task.copyWith(title: 'x').closedByLink, isTrue);
  });

  testWidgets('a task about an item names it and opens it', (tester) async {
    final opened = await _pump(tester, _task(item: 'item-photo'));

    expect(find.text('التصوير'), findsOneWidget);
    expect(find.text('تنتهي لحالها لما ينحجز البند'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-link')));
    await tester.pumpAndSettle();

    expect(opened, [AppRouter.moneyCategoryDetails('plan-1', 'item-photo')]);
  });

  testWidgets('a task about a payment opens its agreement', (tester) async {
    final opened = await _pump(
      tester,
      _task(cost: 'cost-hall', schedule: 'schedule-2'),
    );

    expect(find.text('الدفعة في المال'), findsOneWidget);
    expect(find.text('تنتهي لحالها لما تنسجّل الدفعة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-link')));
    await tester.pumpAndSettle();

    expect(opened, [AppRouter.moneyCostDetails('plan-1', 'cost-hall')]);
  });

  testWidgets('a task the booking finished says so', (tester) async {
    await _pump(
      tester,
      _task(
        item: 'item-photo',
        status: 'DONE',
        autoClosedAt: DateTime(2026, 11, 1),
      ),
    );

    expect(find.text('انتهت لما انحجز البند'), findsOneWidget);
  });

  testWidgets('a task without a link shows no link', (tester) async {
    await _pump(tester, _task());

    expect(find.byKey(const ValueKey('task-link')), findsNothing);
  });

  testWidgets('the menu links a task to one of the plan\'s items', (
    tester,
  ) async {
    final api = _TasksApi();
    await _pump(tester, _task(), api: api);

    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('task-menu-link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-link-none')), findsNothing);
    // The mahr is never booked, so nothing could close a task waiting on it.
    expect(find.text('المهر'), findsNothing);
    expect(find.text('دفعة القاعة · 14 يناير'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-link-item-item-photo')));
    await tester.pumpAndSettle();

    expect(api.updates, [
      {'linkedBudgetCategoryId': 'item-photo', 'linkedScheduleId': null},
    ]);
  });

  // RA-MO-200: an item already booked ends the task as it is linked, which
  // the page did with no word; and with nothing to link to, an empty box.
  testWidgets('linking to a booked item says the task is done', (tester) async {
    final api = _TasksApi(closesOnLink: true);
    await _pump(tester, _task(), api: api);

    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('task-menu-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-link-item-item-photo')));
    await tester.pumpAndSettle();

    expect(
      find.text('البند محجوز من قبل، فخلصت المهمة على طول'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with nothing in the money, the sheet says why', (tester) async {
    await _pump(tester, _task(), emptyMoney: true);

    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('task-menu-link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-link-nothing')), findsOneWidget);
  });

  testWidgets('a linked task can lose its link', (tester) async {
    final api = _TasksApi();
    await _pump(tester, _task(item: 'item-photo'), api: api);

    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('task-menu-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-link-none')));
    await tester.pumpAndSettle();

    expect(api.updates, [
      {'linkedBudgetCategoryId': null, 'linkedScheduleId': null},
    ]);
  });

  test('a starter task tells the server which template it came from', () async {
    final api = _TasksApi();
    final provider = TaskTimelineProvider(api);

    await provider.addStarterTasks(
      weddingPlanId: 'plan-1',
      templates: const [
        TaskStarterTemplate(
          key: 'task-shared-photo',
          title: 'حجز المصور',
          daysBefore: 120,
        ),
      ],
      weddingDate: DateTime(2027, 1, 21),
    );

    expect(api.starterKeys, ['task-shared-photo']);
  });
}

WeddingTask _task({
  String? item,
  String? cost,
  String? schedule,
  String status = 'TODO',
  DateTime? autoClosedAt,
}) => WeddingTask(
  id: 'task-1',
  weddingPlanId: 'plan-1',
  title: 'اختر المصور',
  status: status,
  priority: 'HIGH',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  linkedBudgetCategoryId: item,
  linkedCostId: cost,
  linkedScheduleId: schedule,
  autoClosedAt: autoClosedAt,
);

Future<List<String>> _pump(
  WidgetTester tester,
  WeddingTask task, {
  _TasksApi? api,
  bool emptyMoney = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.reset);
  final finance = FinanceProvider(_Finance(empty: emptyMoney));
  await finance.loadMoney('plan-1');
  final opened = <String>[];
  final tasksApi = api ?? _TasksApi();
  final shown = [task];
  tasksApi.shown = shown;
  final router = GoRouter(
    initialLocation: '/task',
    routes: [
      GoRoute(
        path: '/task',
        builder: (_, _) =>
            TaskDetailsScreen(weddingPlanId: 'plan-1', taskId: task.id),
      ),
    ],
    errorBuilder: (context, state) {
      opened.add(state.uri.toString());
      return const SizedBox.shrink();
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskTimelineProvider>.value(
          value: _Tasks(shown, tasksApi),
        ),
        ChangeNotifierProvider<FinanceProvider>.value(value: finance),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

class _TasksApi extends TaskTimelineApi {
  _TasksApi({this.closesOnLink = false})
    : super(ApiClient(tokenProvider: () async => null));

  /// The item is booked already: the server ends the task as it links it.
  final bool closesOnLink;

  /// The list the screen reads, rewritten as the server answers.
  List<WeddingTask>? shown;

  final updates = <Map<String, dynamic>>[];
  final starterKeys = <String?>[];

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    final saved = closesOnLink ? _task(status: 'DONE') : _task();
    shown?[0] = saved;
    return saved;
  }

  @override
  Future<WeddingTask> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
    String status = 'TODO',
    String priority = 'MEDIUM',
    bool isPrivate = false,
    String? starterKey,
  }) async {
    starterKeys.add(starterKey);
    return _task();
  }
}

class _Tasks extends TaskTimelineProvider {
  _Tasks(this._list, super.api);

  final List<WeddingTask> _list;

  @override
  List<WeddingTask> get tasks => _list;

  @override
  Future<void> load(String weddingPlanId) async {}
}

class _Finance extends FinanceApi {
  _Finance({this.empty = false})
    : super(ApiClient(tokenProvider: () async => null));

  /// A plan with no money items or payments yet.
  final bool empty;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => empty
      ? const MoneySummary(planId: 'plan-1', categories: [])
      : const MoneySummary(
          planId: 'plan-1',
          categories: [
            MoneyCategorySummary(categoryId: 'item-photo', name: 'التصوير'),
            MoneyCategorySummary(
              categoryId: 'item-mahr',
              name: 'المهر',
              isMahr: true,
            ),
          ],
        );

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
    String? payer,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async => [
    if (!empty)
      PaymentSchedule(
        id: 'schedule-2',
        costId: 'cost-hall',
        amount: '500000',
        dueDate: DateTime(2027, 1, 14),
        status: 'PENDING',
        note: 'دفعة القاعة',
      ),
  ];
}
