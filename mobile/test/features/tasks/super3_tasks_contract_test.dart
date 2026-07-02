import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localPlanId = 'guest-plan-super3';

void main() {
  const localPlanId = _localPlanId;

  test('task summary model parses accepted backend aliases', () {
    final summary = TaskSummary.fromJson({
      'weddingPlanId': 'plan-1',
      'totalTasks': 6,
      'completedTasks': 2,
      'pendingInProgress': 3,
      'overdueTasks': 1,
      'todayTasks': 2,
      'highPriority': 2,
      'assignedToMe': 1,
      'assigneeSummary': {
        'assignedToMe': 1,
        'assignedCount': 3,
        'unassignedCount': 3,
      },
      'byStatus': {'TODO': 2, 'IN_PROGRESS': 1, 'DONE': 2, 'CANCELLED': 1},
      'byPriority': {'LOW': 1, 'MEDIUM': 3, 'HIGH': 1, 'URGENT': 1},
    });

    expect(summary.total, 6);
    expect(summary.completed, 2);
    expect(summary.pendingInProgress, 3);
    expect(summary.overdue, 1);
    expect(summary.dueToday, 2);
    expect(summary.highPriority, 2);
    expect(summary.assigneeSummary.assignedCount, 3);
    expect(summary.byPriority['URGENT'], 1);
  });

  test('local task summary updates total completed overdue and progress', () {
    final now = DateTime(2026, 6, 28, 10);
    final summary = TaskSummary.fromTasks(
      weddingPlanId: localPlanId,
      now: now,
      tasks: [
        _task(
          id: 'overdue',
          title: 'تأكيد القاعة',
          dueDate: now.subtract(const Duration(days: 1)),
          priority: 'HIGH',
        ),
        _task(id: 'today', title: 'اتصال بالمصور', dueDate: now),
        _task(id: 'done', title: 'اختيار الملابس', status: 'DONE'),
      ],
    );

    expect(summary.total, 3);
    expect(summary.completed, 1);
    expect(summary.pendingInProgress, 2);
    expect(summary.overdue, 1);
    expect(summary.dueToday, 1);
    expect(summary.highPriority, 1);
    expect(summary.completionPercent, 33);
  });

  test(
    'manual and contact responsible fields do not count as participants',
    () {
      final manual = _task(
        id: 'manual',
        title: 'متابعة القاعة',
        responsibleName: 'محمد',
        responsiblePhone: '+967777123456',
        responsibleSource: 'manual',
      );
      final contact = _task(
        id: 'contact',
        title: 'اتصال بالمصور',
        responsibleName: 'سالم',
        responsiblePhone: '+967777654321',
        responsibleSource: 'deviceContact',
      );
      final participant = _task(
        id: 'participant',
        title: 'مراجعة الضيوف',
        assigneeUserId: 'user-participant',
        assigneeName: 'ليلى',
      );

      final summary = TaskSummary.fromTasks(
        weddingPlanId: localPlanId,
        tasks: [manual, contact, participant],
      );

      expect(manual.responsibleLabel, 'محمد');
      expect(contact.responsibleLabel, 'سالم');
      expect(manual.hasResponsibleParticipant, isFalse);
      expect(contact.hasResponsibleParticipant, isFalse);
      expect(participant.hasResponsibleParticipant, isTrue);
      expect(summary.assigneeSummary.assignedCount, 1);
    },
  );

  testWidgets('local task appears in Super 3 Tasks screen without login', (
    tester,
  ) async {
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'تأكيد القاعة',
      dueDate: DateTime.now(),
      taskCategory: 'VENUE',
      priority: 'HIGH',
      responsibleName: 'محمد',
      responsiblePhone: '777123456',
    );

    await _pumpTasksScreen(tester, harness);

    expect(find.text('المهام'), findsWidgets);
    expect(
      find.text(
        'تابع تجهيزات زفافك خطوة بخطوة، وركّز على المهام المؤكدة فقط بدون اقتراحات وهمية.',
      ),
      findsWidgets,
    );
    expect(find.text('تأكيد القاعة'), findsWidgets);
    expect(find.text('إنجاز المهام'), findsOneWidget);
    expect(find.text('حساب محفوظ'), findsNothing);
    expect(find.text('تخطيط محلي'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('المسؤول: محمد'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('المسؤول: محمد'), findsOneWidget);
    expect(find.text('+967 777 123 456'), findsOneWidget);
    expect(find.text('مشارك في الخطة'), findsNothing);
    expect(find.text('القاعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'task cards label real participants without contact chip clutter',
    (tester) async {
      final harness = await _createHarness();
      await harness.api.createTask(
        weddingPlanId: localPlanId,
        title: 'متابعة المصور',
        responsibleName: 'سالم',
        responsiblePhone: '+967777654321',
        responsibleSource: 'deviceContact',
      );
      await harness.api.createTask(
        weddingPlanId: localPlanId,
        title: 'مراجعة الضيوف',
        assigneeUserId: 'user-participant',
        assigneeName: 'ليلى',
        assigneePhone: '+967777123456',
        assigneeRole: 'HELPER',
      );

      await _pumpTasksScreen(tester, harness);

      expect(find.text('المسؤول: سالم'), findsOneWidget);
      expect(find.text('المسؤول: ليلى'), findsOneWidget);
      expect(find.text('+967 777 654 321'), findsOneWidget);
      expect(find.text('مشارك في الخطة'), findsOneWidget);
      expect(find.textContaining('غير معروف'), findsNothing);
      expect(find.text('مساهم'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overdue task appears in Important Now and overdue filter', (
    tester,
  ) async {
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'مراجعة عقد القاعة',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      taskCategory: 'VENUE',
      priority: 'HIGH',
    );
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'مهمة لاحقة',
      dueDate: DateTime.now().add(const Duration(days: 10)),
    );

    await _pumpTasksScreen(tester, harness);

    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('أهم ما يحتاج تنفيذ اليوم'), findsOneWidget);
    expect(find.text('مراجعة عقد القاعة'), findsWidgets);
    expect(find.text('متأخرة وتحتاج متابعة'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('task-filter-overdue')),
    );
    await tester.tap(find.byKey(const ValueKey('task-filter-overdue')));
    await tester.pumpAndSettle();

    expect(find.text('المهام المتأخرة'), findsOneWidget);
    expect(find.text('مراجعة عقد القاعة'), findsWidgets);
    expect(find.text('مهمة لاحقة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed task updates Super 3 progress', (tester) async {
    final harness = await _createHarness();
    final provider = TaskTimelineProvider(harness.api);
    await provider.createTask(weddingPlanId: localPlanId, title: 'حجز القاعة');
    await provider.markTaskDone(localPlanId, provider.tasks.single);

    expect(provider.summary.total, 1);
    expect(provider.summary.completed, 1);
    expect(provider.summary.completionPercent, 100);

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        const MaterialApp(home: TaskTimelineScreen(weddingPlanId: localPlanId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مكتملة'), findsWidgets);
    expect(find.text('100%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Task works without login for local plan', (tester) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    final provider = TaskTimelineProvider(harness.api);

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        MaterialApp.router(
          routerConfig: _router(
            start: const CreateTaskScreen(weddingPlanId: localPlanId),
          ),
        ),
      ),
    );

    await tester.enterText(
      _textFormFieldWithLabel('عنوان المهمة'),
      'تأكيد قائمة المدعوين',
    );
    expect(find.text('المسؤول عن المهمة'), findsOneWidget);
    expect(find.text('أنا'), findsWidgets);
    await tester.enterText(_textFormFieldWithLabel('اسم المسؤول'), 'محمد');
    await tester.enterText(_textFormFieldWithLabel('رقم المسؤول'), '777123456');
    await tester.pumpAndSettle();
    final submit = find.text('حفظ المهمة');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(provider.tasks, hasLength(1));
    expect(provider.tasks.single.title, 'تأكيد قائمة المدعوين');
    expect(provider.tasks.single.responsibleName, 'محمد');
    expect(provider.tasks.single.responsiblePhone, '+967777123456');
    expect(provider.tasks.single.assigneeUserId, isNull);
    expect(find.text('tasks-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Task selects an existing participant as responsible', (
    tester,
  ) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    final provider = TaskTimelineProvider(harness.api);
    final sharingProvider = _FakeSharingProvider(harness, [
      _member(weddingPlanId: 'account-plan', userId: 'user-1', name: 'ليلى'),
    ]);

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        MaterialApp.router(
          routerConfig: _router(
            start: const CreateTaskScreen(weddingPlanId: 'account-plan'),
          ),
        ),
        sharingProvider: sharingProvider,
      ),
    );

    expect(find.text('المسؤول عن المهمة'), findsOneWidget);
    expect(find.text('مشارك من الخطة'), findsOneWidget);
    await tester.tap(find.text('اختر مشاركاً موجوداً'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ليلى').last);
    await tester.pumpAndSettle();

    expect(find.text('ليلى'), findsWidgets);
    expect(find.text('مشارك في الخطة'), findsOneWidget);
    expect(sharingProvider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invite responsible action is gated and not automatic', (
    tester,
  ) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    final provider = TaskTimelineProvider(harness.api);
    final sharingProvider = _FakeSharingProvider(harness, const []);

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        MaterialApp.router(
          routerConfig: _router(
            start: const CreateTaskScreen(weddingPlanId: localPlanId),
          ),
        ),
        sharingProvider: sharingProvider,
      ),
    );

    await tester.enterText(_textFormFieldWithLabel('اسم المسؤول'), 'سالم');
    await tester.enterText(_textFormFieldWithLabel('رقم المسؤول'), '777654321');
    await tester.pumpAndSettle();

    final invite = find.text('دعوته كمشارك في الخطة');
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pumpAndSettle();

    expect(find.text('هذه الخطوة تحتاج حساباً'), findsOneWidget);
    expect(sharingProvider.invites, isEmpty);
    expect(provider.tasks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks screen avoids fake suggestions and future links', (
    tester,
  ) async {
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'تأكيد القاعة',
    );

    await _pumpTasksScreen(tester, harness);

    expect(find.textContaining('أضف موقع الزفاف'), findsNothing);
    expect(find.textContaining('حدد الميزانية'), findsNothing);
    expect(find.textContaining('إنشاء مهمة متابعة'), findsNothing);
    expect(find.textContaining('طلب عرض سعر'), findsNothing);
    expect(find.textContaining('انضم كمزود'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super 3 Tasks screen has no overflow at 320px', (tester) async {
    _setPhoneView(tester, width: 320);
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'مهمة طويلة لاختبار عرض الهاتف الصغير بدون أي تجاوز مرئي',
      dueDate: DateTime.now(),
      taskCategory: 'DOCUMENTS',
      priority: 'HIGH',
    );

    await _pumpTasksScreen(tester, harness, setView: false);

    expect(find.text('إنجاز المهام'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WeddingTask _task({
  required String id,
  required String title,
  String status = 'TODO',
  String priority = 'MEDIUM',
  DateTime? dueDate,
  String? assigneeUserId,
  String? assigneeName,
  String? responsibleName,
  String? responsiblePhone,
  String? responsibleSource,
}) {
  return WeddingTask(
    id: id,
    weddingPlanId: 'guest-plan-super3',
    title: title,
    status: status,
    priority: priority,
    dueDate: dueDate,
    assigneeUserId: assigneeUserId,
    assigneeName: assigneeName,
    responsibleName: responsibleName,
    responsiblePhone: responsiblePhone,
    responsibleSource: responsibleSource,
    createdAt: DateTime(2026, 6, 28),
    updatedAt: DateTime(2026, 6, 28),
  );
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
    api: TaskTimelineApi(apiClient, offline: offline),
  );
}

Future<void> _pumpTasksScreen(
  WidgetTester tester,
  _Harness harness, {
  bool setView = true,
}) async {
  if (setView) _setPhoneView(tester);
  await tester.pumpWidget(
    _providers(
      harness,
      TaskTimelineProvider(harness.api),
      const MaterialApp(home: TaskTimelineScreen(weddingPlanId: _localPlanId)),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Widget _providers(
  _Harness harness,
  TaskTimelineProvider provider,
  Widget child, {
  SharingProvider? sharingProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthStorage>.value(value: harness.authStorage),
      ChangeNotifierProvider<OfflineSyncService>.value(value: harness.offline),
      ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
      ChangeNotifierProvider<SharingProvider>(
        create: (_) =>
            sharingProvider ?? _FakeSharingProvider(harness, const []),
      ),
    ],
    child: child,
  );
}

void _setPhoneView(WidgetTester tester, {double width = 390}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);
}

GoRouter _router({required Widget start}) {
  return GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => start),
      GoRoute(
        path: '/wedding-plans/:id/tasks',
        builder: (context, state) => const Scaffold(body: Text('tasks-target')),
      ),
    ],
  );
}

Finder _textFormFieldWithLabel(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(TextFormField))
      .first;
}

SharedMember _member({
  required String weddingPlanId,
  required String userId,
  required String name,
  String role = 'HELPER',
}) {
  return SharedMember(
    id: 'member-$userId',
    weddingPlanId: weddingPlanId,
    userId: userId,
    user: SharedMemberUser(id: userId, name: name, phone: '+967777123456'),
    role: role,
    canViewBudget: false,
    canViewExpenses: false,
    canViewDebts: false,
    canManageTasks: true,
    canManageFinancialRecords: false,
    createdAt: DateTime(2026, 6, 28),
    updatedAt: DateTime(2026, 6, 28),
  );
}

class _FakeSharingProvider extends SharingProvider {
  _FakeSharingProvider(_Harness harness, this._fakeMembers)
    : super(SharingApi(harness.apiClient, offline: harness.offline));

  final List<SharedMember> _fakeMembers;
  final List<PlanInvite> _fakeInvites = const [];

  @override
  List<SharedMember> get members => _fakeMembers;

  @override
  List<PlanInvite> get invites => _fakeInvites;

  @override
  Future<void> loadMembers(String weddingPlanId) async {}
}

class _Harness {
  const _Harness({
    required this.authStorage,
    required this.apiClient,
    required this.offline,
    required this.api,
  });

  final AuthStorage authStorage;
  final ApiClient apiClient;
  final OfflineSyncService offline;
  final TaskTimelineApi api;
}
