import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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

  test('account task API sends manual responsibility to the backend', () async {
    final harness = await _createHarness();
    final adapter = _TaskCreateAdapter();
    harness.apiClient.dio.httpClientAdapter = adapter;

    await harness.api.createTask(
      weddingPlanId: 'account-plan',
      title: 'تأكيد القاعة',
      responsibleName: 'محمد',
      responsibleSource: 'manual',
    );

    final payload = Map<String, dynamic>.from(
      adapter.requests.single.data as Map,
    );
    expect(payload['responsibleName'], 'محمد');
    expect(payload['responsiblePhone'], isNull);
    expect(payload['responsibleSource'], 'manual');
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

    // d01: the header, this week's section, and when · who on the row.
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('باقي 1 هذا الأسبوع'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-group-week')), findsOneWidget);
    expect(find.text('تأكيد القاعة'), findsOneWidget);
    expect(find.text('اليوم · محمد'), findsOneWidget);
    expect(find.text('حساب محفوظ'), findsNothing);
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

      expect(find.text('بدون موعد · سالم'), findsOneWidget);
      expect(find.text('بدون موعد · ليلى'), findsOneWidget);
      expect(find.textContaining('+967'), findsNothing);
      expect(find.textContaining('غير معروف'), findsNothing);

      // One chip per responsible person narrows the list to them.
      final salem = find.byKey(const ValueKey('task-person-سالم'));
      await tester.ensureVisible(salem);
      await tester.pumpAndSettle();
      await tester.tap(salem);
      await tester.pumpAndSettle();
      expect(find.text('متابعة المصور'), findsOneWidget);
      expect(find.text('مراجعة الضيوف'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overdue task leads the grouped timeline and overdue filter', (
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

    expect(find.text('باقي مهمتين، منها واحدة متأخرة'), findsOneWidget);
    final overdue = find.byKey(const ValueKey('task-group-overdue'));
    final month = find.byKey(const ValueKey('task-group-month'));
    expect(overdue, findsOneWidget);
    expect(month, findsOneWidget);
    expect(
      tester.getTopLeft(overdue).dy,
      lessThan(tester.getTopLeft(month).dy),
    );
    expect(find.textContaining('كان موعدها'), findsOneWidget);
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

    expect(find.text('خلصت كل المهام'), findsOneWidget);
    expect(find.text('1 من 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tasks-toggle-done')));
    await tester.pumpAndSettle();
    expect(find.text('حجز القاعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a task moves it to «خلصت» (d01)', (tester) async {
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'حجز القاعة',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    );

    await _pumpTasksScreen(tester, harness);
    final task = find.text('حجز القاعة');
    expect(task, findsOneWidget);
    // The circle at the start of the row finishes it.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('task-toggle-'),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('خلصت كل المهام'), findsOneWidget);
    expect(find.text('1 من 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the time view lists tasks by month (w24)', (tester) async {
    final harness = await _createHarness();
    final now = DateTime.now();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'اختر المصور',
      dueDate: now,
    );
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'أرسل الدعوات',
      dueDate: DateTime(now.year, now.month + 2, 10),
    );
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'فكّر في الهدايا',
    );

    await _pumpTasksScreen(tester, harness);
    await tester.tap(find.text('الوقت'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('task-month-${now.year}-${now.month}')),
      findsOneWidget,
    );
    expect(find.textContaining('· الآن'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-month-undated')), findsOneWidget);
    expect(find.text('أرسل الدعوات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task details show when, who and the contact (d04)', (
    tester,
  ) async {
    _setPhoneView(tester);
    final harness = await _createHarness();
    await harness.api.createTask(
      weddingPlanId: localPlanId,
      title: 'تذوّق الضيافة',
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
      responsibleName: 'صالح',
      responsiblePhone: '+967777654321',
    );
    final provider = TaskTimelineProvider(harness.api);
    await provider.load(localPlanId);
    final task = provider.tasks.single;

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        MaterialApp(
          home: TaskDetailsScreen(weddingPlanId: localPlanId, taskId: task.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تذوّق الضيافة'), findsOneWidget);
    expect(find.text('متأخرة 3 أيام'), findsOneWidget);
    expect(find.text('لصالح'), findsOneWidget);
    expect(find.textContaining('كان '), findsOneWidget);
    expect(find.byKey(const ValueKey('task-contact')), findsOneWidget);
    expect(find.text('خطوات صغيرة'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-detail-postpone')), findsOneWidget);

    // x16: «ما نحتاجها» cancels it and offers to reopen.
    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-menu-cancel')));
    await tester.pumpAndSettle();
    expect(provider.tasks.single.status, 'CANCELLED');
    expect(find.text('ملغية'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-detail-reopen')), findsOneWidget);
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
    await tester.pumpAndSettle();

    // d02: what, when and «لمين؟», «أنا» chosen until changed.
    expect(find.text('لمين؟'), findsOneWidget);
    expect(find.text('أنا'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'تأكيد قائمة المدعوين',
    );
    await _chooseOtherPerson(tester, name: 'محمد', phone: '777123456');
    await _saveTask(tester);

    expect(provider.tasks, hasLength(1));
    expect(provider.tasks.single.title, 'تأكيد قائمة المدعوين');
    expect(provider.tasks.single.responsibleName, 'محمد');
    expect(provider.tasks.single.responsiblePhone, '+967777123456');
    expect(provider.tasks.single.assigneeUserId, isNull);
    expect(provider.tasks.single.dueDate, isNotNull);
    expect(find.text('tasks-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new task form opens without another action\'s error', (
    tester,
  ) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    // A swipe that failed before «+» was tapped left its reason behind.
    final provider = _StaleErrorTaskProvider(harness.api);

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
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحديث المهمة.'), findsNothing);
    expect(find.byKey(const ValueKey('task-save-error')), findsNothing);
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
    await tester.pumpAndSettle();

    final layla = find.byKey(const ValueKey('task-who-member:user-1'));
    expect(layla, findsOneWidget);
    await tester.tap(layla);
    await tester.pumpAndSettle();

    expect(tester.widget<JourneyChip>(layla).selected, isTrue);
    expect(sharingProvider.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account task saves a manual responsible without a phone', (
    tester,
  ) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    await _saveAccountSession(harness);
    final provider = _CapturingTaskProvider(harness.api);

    await tester.pumpWidget(
      _providers(
        harness,
        provider,
        MaterialApp.router(
          routerConfig: _router(
            start: const CreateTaskScreen(weddingPlanId: 'account-plan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'تأكيد القاعة',
    );
    await _chooseOtherPerson(tester, name: 'محمد');
    await _saveTask(tester);

    expect(provider.createCalls, 1);
    expect(provider.responsibleName, 'محمد');
    expect(provider.responsiblePhone, isNull);
    expect(provider.assigneeUserId, isNull);
  });

  testWidgets('account task maps انا to the authenticated plan member', (
    tester,
  ) async {
    _setPhoneView(tester, width: 390);
    final harness = await _createHarness();
    final user = await _saveAccountSession(harness);
    final provider = _CapturingTaskProvider(harness.api);
    final auth = _FakeAuthController(
      AuthRepository(harness.apiClient, harness.authStorage),
      user,
    );
    final sharing = _FakeSharingProvider(harness, [
      _member(
        weddingPlanId: 'account-plan',
        userId: user.id,
        name: user.name,
        role: 'OWNER',
        isOwner: true,
      ),
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
        sharingProvider: sharing,
        authController: auth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'تأكيد القاعة',
    );
    // Typing «انا» as someone else still means the owner.
    await _chooseOtherPerson(tester, name: 'انا');
    await _saveTask(tester);

    expect(provider.createCalls, 1);
    expect(provider.assigneeUserId, user.id);
    expect(provider.responsibleName, isNull);
    expect(provider.responsiblePhone, isNull);
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
    await tester.pumpAndSettle();

    await _chooseOtherPerson(tester, name: 'سالم', phone: '777654321');
    final invite = find.byKey(const ValueKey('task-invite-responsible'));
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

    expect(find.text('المهام'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      AarastV3Color.canvas,
    );
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

/// «شخص ثاني» with a name and, when given, a number.
Future<void> _chooseOtherPerson(
  WidgetTester tester, {
  required String name,
  String? phone,
}) async {
  final other = find.byKey(const ValueKey('task-who-other'));
  await tester.ensureVisible(other);
  await tester.tap(other);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('task-other-name')), name);
  if (phone != null) {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-other-phone')),
        matching: find.byType(EditableText),
      ),
      phone,
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _saveTask(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('task-save')));
  await tester.pumpAndSettle();
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
  AuthController? authController,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthStorage>.value(value: harness.authStorage),
      ChangeNotifierProvider<OfflineSyncService>.value(value: harness.offline),
      ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
      if (authController != null)
        ChangeNotifierProvider<AuthController>.value(value: authController),
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

SharedMember _member({
  required String weddingPlanId,
  required String userId,
  required String name,
  String role = 'HELPER',
  bool isOwner = false,
}) {
  return SharedMember(
    id: 'member-$userId',
    weddingPlanId: weddingPlanId,
    userId: userId,
    user: SharedMemberUser(id: userId, name: name, phone: '+967777123456'),
    role: role,
    canViewMoney: false,
    canManageTasks: true,
    canManageMoney: false,
    isOwner: isOwner,
    createdAt: DateTime(2026, 6, 28),
    updatedAt: DateTime(2026, 6, 28),
  );
}

Future<SafeUser> _saveAccountSession(_Harness harness) async {
  const user = SafeUser(
    id: 'user-1',
    name: 'رشاد',
    phone: '+967777123456',
    role: 'USER',
    status: 'ACTIVE',
  );
  await harness.authStorage.saveSession(
    accessToken: 'account-token',
    user: user,
  );
  return user;
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(super.repository, this.fakeUser);

  final SafeUser fakeUser;

  @override
  SafeUser? get user => fakeUser;
}

class _StaleErrorTaskProvider extends TaskTimelineProvider {
  _StaleErrorTaskProvider(super.api);

  @override
  String? get errorMessage => 'تعذر تحديث المهمة.';
}

class _CapturingTaskProvider extends TaskTimelineProvider {
  _CapturingTaskProvider(super.api);

  int createCalls = 0;
  String? assigneeUserId;
  String? responsibleName;
  String? responsiblePhone;

  @override
  Future<bool> createTask({
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
  }) async {
    createCalls += 1;
    this.assigneeUserId = assigneeUserId;
    this.responsibleName = responsibleName;
    this.responsiblePhone = responsiblePhone;
    return true;
  }
}

class _TaskCreateAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'task-1',
        'weddingPlanId': 'account-plan',
        'title': 'تأكيد القاعة',
        'description': null,
        'dueDate': null,
        'taskCategory': null,
        'reminderAt': null,
        'status': 'TODO',
        'priority': 'MEDIUM',
        'assigneeUserId': null,
        'responsibleName': 'محمد',
        'responsiblePhone': null,
        'responsibleSource': 'manual',
        'createdAt': '2026-07-11T00:00:00.000Z',
        'updatedAt': '2026-07-11T00:00:00.000Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
  Future<void> loadMembers(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {}
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
