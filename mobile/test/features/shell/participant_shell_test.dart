import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/shell/screens/participant_locked_screen.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add_sheet.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/participant_tasks_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/participant_home_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

const _planId = 'shared-plan';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'x06: the participant opens on their own home inside the five tabs',
    (tester) async {
      final logSink = _CollectingLogSink();
      AppLogger.installGlobal(
        AppLogger(
          redactor: LogRedactor(installationSalt: 'participant-shell-test'),
          sinks: [logSink],
        ),
      );
      addTearDown(AppLogger.clearGlobal);
      final harness = await _Harness.create(
        tasks: [
          _task('t1', 'رتّب الغداء مع أبو علي', days: 2, mine: true),
          _task('t2', 'ذكّر آل الحمدي اللي ما ردّوا', days: 5),
          _task('t3', 'رتّب سيارات الزفة', days: 20),
        ],
      );
      await harness.pump(tester);

      expect(find.byType(ParticipantHomeScreen), findsOneWidget);
      expect(find.byType(AarastPlanNavigationBar), findsOneWidget);
      expect(find.byType(WeddingPlanDashboardScreen), findsNothing);
      // No floating «+» on a participant's tabs (the design draws none).
      expect(find.byType(PlanQuickAddButton), findsNothing);

      expect(find.text('أهلًا صالح'), findsOneWidget);
      expect(find.text('عرس محمد ·'), findsOneWidget);
      expect(find.text('أنت مساعد'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('يوم على العرس'), findsOneWidget);
      // The next step is the nearest open task, finished from here.
      expect(find.textContaining('الخطوة الجاية'), findsOneWidget);
      expect(find.text('رتّب الغداء مع أبو علي'), findsOneWidget);
      expect(find.text('هذي المهمة عليك'), findsOneWidget);
      expect(find.text('مهامك'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('ذكّر آل الحمدي اللي ما ردّوا'), findsOneWidget);
      // Privacy: nothing of the money, only that it is hidden.
      expect(find.text('المال مخفي عنك.'), findsOneWidget);
      expect(find.textContaining('ر.ي'), findsNothing);
      expect(find.textContaining('اطلب من'), findsNothing);
      expect(tester.takeException(), isNull);

      expect(
        logSink.events.where(
          (event) =>
              event.name == 'dashboard_built' &&
              event.category == AppLogCategory.contributor,
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        logSink.events.where(
          (event) =>
              event.name == 'dashboard_disposed' &&
              event.category == AppLogCategory.contributor,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets('x06: «خلصت» finishes the next task', (tester) async {
    final harness = await _Harness.create(
      tasks: [_task('t1', 'رتّب الغداء مع أبو علي', days: 2)],
    );
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('participant-next-done')));
    await tester.pumpAndSettle();

    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);
  });

  testWidgets(
    'q07, q08: money and providers without the right show a calm lock',
    (tester) async {
      final harness = await _Harness.create();
      await harness.pump(tester);

      await _openTab(tester, 'المال');
      expect(find.byType(ParticipantLockedScreen), findsOneWidget);
      expect(find.text('المال خاص بالعريس'), findsOneWidget);
      expect(
        find.text('ما عندك صلاحية تشوف المال في هذي الخطة.'),
        findsOneWidget,
      );
      expect(find.text('عرس محمد · أنت مساعد'), findsOneWidget);
      // Asking for the right waits for q13.
      expect(find.text('اطلب من محمد'), findsNothing);
      expect(harness.wedding.moneyRequests, 0);

      await _openTab(tester, 'المزودين');
      expect(find.text('المزودين عند العريس'), findsOneWidget);
      expect(find.text('الطلبات والعروض خاصة بالعريس.'), findsOneWidget);
      expect(find.text('اطلب صلاحية'), findsNothing);
      expect(find.textContaining('مواعيدهم في البرنامج'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('q05: the tasks tab lists only the participant\'s tasks', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tasks: [
        _task('t1', 'رتّب الغداء مع أبو علي', days: 2),
        _task('t4', 'استلم البدلة', days: -1, done: true),
      ],
    );
    await harness.pump(tester);
    await _openTab(tester, 'المهام');

    expect(find.byType(ParticipantTasksScreen), findsOneWidget);
    expect(find.text('عرس محمد · معك 2'), findsOneWidget);
    expect(find.text('لك'), findsOneWidget);
    expect(find.text('استلم البدلة'), findsOneWidget);
    // «كل مهام الخطة» needs the plan's other tasks, which a participant
    // cannot read.
    expect(find.text('كل مهام الخطة'), findsNothing);
    expect(
      find.text('تشوف هنا المهام اللي عليك أو اللي أضفتها.'),
      findsOneWidget,
    );
    // C27: a participant with the tasks right adds tasks.
    expect(find.byKey(const Key('participant-tasks-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('participant-task-toggle-t1')));
    await tester.pumpAndSettle();
    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a participant without the tasks right sees the tasks locked', (
    tester,
  ) async {
    final harness = await _Harness.create(canManageTasks: false);
    await harness.pump(tester);
    await _openTab(tester, 'المهام');

    expect(find.text('المهام عند العريس'), findsOneWidget);
    expect(find.byType(ParticipantTasksScreen), findsNothing);
    expect(harness.tasksApi.listCalls, 0);
  });

  testWidgets('q17: a bride\'s plan speaks in her colour to a woman', (
    tester,
  ) async {
    final harness = await _Harness.create(
      persona: AccountContextPersona.bride,
      title: 'عرس سلمى',
      userName: 'نورة',
    );
    await harness.pump(tester);

    expect(find.text('أهلًا نورة'), findsOneWidget);
    expect(find.text('أنتِ مساعدة'), findsOneWidget);
    expect(
      find.text(
        'الخطة بألوان صاحبتها. لو عندك خطة أنتِ، تبدّلين لها من «حسابي».',
      ),
      findsOneWidget,
    );
    final hero = tester.widget<JourneyBox>(
      find.byKey(const ValueKey('participant-count-hero')),
    );
    expect(hero.color, AarastV3Color.rose);

    await _openTab(tester, 'المال');
    expect(find.text('المال خاص بالعروسة'), findsOneWidget);
    expect(find.text('عرس سلمى · أنتِ مساعدة'), findsOneWidget);
  });

  testWidgets('q18: on the day the home is the wedding and today\'s tasks', (
    tester,
  ) async {
    final harness = await _Harness.create(
      daysRemaining: 0,
      tasks: [
        _task('t1', 'استلام الغداء من أبو علي', days: 0),
        _task('t2', 'رتّب سيارات الزفة', days: 3),
      ],
    );
    await harness.pump(tester);

    expect(find.byKey(const ValueKey('participant-day-hero')), findsOneWidget);
    final hero = find.byKey(const ValueKey('participant-day-hero'));
    expect(
      find.descendant(of: hero, matching: find.text('اليوم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('يوم العرس')),
      findsOneWidget,
    );
    expect(find.text('عليك اليوم'), findsOneWidget);
    expect(find.text('استلام الغداء من أبو علي'), findsOneWidget);
    // Only today's tasks; the programme waits for the wedding's events.
    expect(find.text('رتّب سيارات الزفة'), findsNothing);
    expect(find.text('برنامج اليوم'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('participant-today-done-t1')));
    await tester.pumpAndSettle();
    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);
  });

  testWidgets(
    'q12: a right the owner opened is told once, from the kept path',
    (tester) async {
      final harness = await _Harness.create(keptCanViewMoney: false);
      // The server now gives the money.
      harness.contexts.replaceGateway(canViewMoney: true);
      await harness.controller.refresh();
      expect(harness.controller.permissionChange, isNotNull);

      await harness.pump(tester);

      expect(find.text('العريس فتح لك المال'), findsOneWidget);
      expect(
        find.text('تقدر الآن تشوف المال. المصادر والسلف تبقى خاصة فيه.'),
        findsOneWidget,
      );
      // Taken by the home: it is told once.
      expect(harness.controller.permissionChange, isNull);
      // The custody step and the removal note are not shown.
      expect(find.textContaining('العهدة'), findsNothing);
      expect(find.textContaining('شالك'), findsNothing);
    },
  );

  testWidgets('q12: the same rights tell nothing', (tester) async {
    final harness = await _Harness.create();
    await harness.controller.refresh();
    await harness.pump(tester);

    expect(harness.controller.permissionChange, isNull);
    expect(
      find.byKey(const ValueKey('participant-rights-changed')),
      findsNothing,
    );
  });

  testWidgets('the participant home fits 320px at 1.3 text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await _Harness.create(
      tasks: [
        _task('t1', 'رتّب الغداء مع أبو علي في بيت الوالد', days: 2),
        _task('t2', 'ذكّر آل الحمدي', days: 5),
      ],
    );
    await harness.pump(tester, textScale: 1.3, tall: false);
    expect(tester.takeException(), isNull);
    await _openTab(tester, 'المال');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AarastPlanNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

WeddingTask _task(
  String id,
  String title, {
  required int days,
  bool mine = false,
  bool done = false,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  return WeddingTask(
    id: id,
    weddingPlanId: _planId,
    title: title,
    status: done ? 'DONE' : 'TODO',
    priority: 'MEDIUM',
    dueDate: today.add(Duration(days: days)),
    assigneeUserId: mine ? 'saleh' : null,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );
}

class _Harness {
  _Harness({
    required this.controller,
    required this.contexts,
    required this.auth,
    required this.wedding,
    required this.dashboard,
    required this.tasksApi,
    required this.tasks,
  });

  final AccountContextController controller;
  final _Gateway contexts;
  final AuthController auth;
  final _WeddingPlansApi wedding;
  final DashboardSummaryProvider dashboard;
  final _TasksApi tasksApi;
  final TaskTimelineProvider tasks;

  static Future<_Harness> create({
    AccountContextPersona persona = AccountContextPersona.groom,
    String title = 'عرس محمد',
    String userName = 'صالح الحمدي',
    int daysRemaining = 96,
    bool canManageTasks = true,
    bool keptCanViewMoney = false,
    List<WeddingTask> tasks = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final user = SafeUser(
      id: 'saleh',
      name: userName,
      phone: '+967771554220',
      role: 'USER',
      status: 'ACTIVE',
    );
    await storage.saveSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: user,
    );
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'controlled participant shell test failure',
          ),
        ),
      ),
    );
    final gateway = _Gateway(
      persona: persona,
      title: title,
      canManageTasks: canManageTasks,
      canViewMoney: keptCanViewMoney,
    );
    final controller = AccountContextController(
      contextsApi: gateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    await controller.refresh();
    expect(await controller.select('plan:$_planId:contributor'), isTrue);
    final repository = _AuthRepository(apiClient, storage, user);
    final auth = AuthController(repository);
    await auth.restoreSession();
    final wedding = _WeddingPlansApi(
      apiClient,
      _summary(
        title: title,
        daysRemaining: daysRemaining,
        canManageTasks: canManageTasks,
      ),
    );
    final tasksApi = _TasksApi(apiClient, tasks);
    return _Harness(
      controller: controller,
      contexts: gateway,
      auth: auth,
      wedding: wedding,
      dashboard: DashboardSummaryProvider(weddingPlansApi: wedding),
      tasksApi: tasksApi,
      tasks: TaskTimelineProvider(tasksApi),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool tall = true,
  }) async {
    if (tall) {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountContextController>.value(
            value: controller,
          ),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
          ChangeNotifierProvider<TaskTimelineProvider>.value(value: tasks),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

DashboardSummary _summary({
  required String title,
  required int daysRemaining,
  required bool canManageTasks,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  return DashboardSummary(
    planId: _planId,
    title: title,
    status: 'PLANNING',
    progressPercentage: 35,
    weddingDate: today.add(Duration(days: daysRemaining)),
    daysRemaining: daysRemaining,
    currency: 'YER',
    totalTasks: 3,
    completedTasks: 0,
    overdueTasks: 0,
    todayTasks: 0,
    guestCount: 0,
    confirmedGuests: 0,
    providerCount: 0,
    quoteRequestsCount: 0,
    participantCount: 3,
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: DashboardPermissionSummary(
      isOwner: false,
      role: 'HELPER',
      canViewMoney: false,
      canManageTasks: canManageTasks,
      canManageGuests: true,
      canManageProviders: false,
      canManageMembers: false,
      canManageMoney: false,
      canManagePlan: false,
    ),
  );
}

class _Gateway implements AccountContextsGateway {
  _Gateway({
    required this.persona,
    required this.title,
    required this.canManageTasks,
    required this.canViewMoney,
  });

  final AccountContextPersona persona;
  final String title;
  bool canManageTasks;
  bool canViewMoney;

  void replaceGateway({required bool canViewMoney}) {
    this.canViewMoney = canViewMoney;
  }

  AccountContext get _context {
    final json = accountContextJson(
      role: AccountContextRole.contributor,
      planId: _planId,
      displayName: title,
      persona: persona,
    );
    final permissions = Map<String, dynamic>.from(json['permissions'] as Map)
      ..['canManageTasks'] = canManageTasks
      ..['canViewMoney'] = canViewMoney;
    return AccountContext.fromJson({...json, 'permissions': permissions});
  }

  @override
  Future<List<AccountContext>> listContexts() async => [_context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => _context;
}

class _WeddingPlansApi extends WeddingPlansApi {
  _WeddingPlansApi(super.apiClient, this.summary);

  final DashboardSummary summary;
  int moneyRequests = 0;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async => summary;
}

class _TasksApi extends TaskTimelineApi {
  _TasksApi(super.apiClient, List<WeddingTask> tasks) : _tasks = [...tasks];

  final List<WeddingTask> _tasks;
  final List<Map<String, dynamic>> updates = [];
  int listCalls = 0;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    listCalls += 1;
    return _tasks;
  }

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    final index = _tasks.indexWhere((task) => task.id == id);
    final updated = WeddingTask(
      id: id,
      weddingPlanId: _planId,
      title: _tasks[index].title,
      status: data['status']?.toString() ?? _tasks[index].status,
      priority: 'MEDIUM',
      dueDate: _tasks[index].dueDate,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
    );
    _tasks[index] = updated;
    return updated;
  }
}

class _AuthRepository extends AuthRepository {
  _AuthRepository(super.apiClient, super.authStorage, this.user);

  final SafeUser user;

  @override
  SafeUser? readCachedUser() => user;

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  Future<SafeUser> me() async => user;
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}
