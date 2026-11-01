// Captures today's real tasks screens for the groom before/after review.
//   flutter test test/prototype/now_tasks/now_tasks_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_bottom_sheet.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_checklist_item.dart';
import 'package:aarast_mobile/features/tasks/models/task_starter_catalog.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_starter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

const _plan = 'plan-mohammed-salma';

/// Server-shaped fake: no network, answers like `GET P/tasks` and
/// `GET P/tasks/summary` (owner, so private tasks are allowed).
class _Api extends TaskTimelineApi {
  _Api(super.client, this.tasks);
  final List<WeddingTask> tasks;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async =>
      List.of(tasks);

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async {
    final s = TaskSummary.fromTasks(weddingPlanId: weddingPlanId, tasks: tasks);
    return TaskSummary(
      weddingPlanId: weddingPlanId,
      total: s.total,
      completed: s.completed,
      pendingInProgress: s.pendingInProgress,
      overdue: s.overdue,
      dueToday: s.dueToday,
      highPriority: s.highPriority,
      assigneeSummary: s.assigneeSummary,
      byStatus: s.byStatus,
      byPriority: s.byPriority,
      canKeepPrivateTask: true,
    );
  }
}

/// Fixed days, so the shots do not change with the day they run: the app
/// reads the real clock, so a day before it is always late and a far day is
/// always «بعدين» (a «today» or «this week» task cannot be pinned).
DateTime _day(int offset) => offset < 0
    ? DateTime(2026, 10, 25).add(Duration(days: offset))
    : DateTime(2030).add(Duration(days: offset));

WeddingTask _t(
  String id,
  String title, {
  int? due,
  DateTime? at,
  String status = 'TODO',
  String priority = 'MEDIUM',
  String? category,
  String? who,
  String? phone,
  bool private = false,
  List<(String, bool)> steps = const [],
}) {
  final now = DateTime.now();
  return WeddingTask(
    id: id,
    weddingPlanId: _plan,
    title: title,
    status: status,
    priority: priority,
    createdAt: now,
    updatedAt: now,
    dueDate: at ?? (due == null ? null : _day(due)),
    taskCategory: category,
    responsibleName: who,
    responsiblePhone: phone,
    responsibleSource: who == null ? null : 'MANUAL',
    isPrivate: private,
    checklist: [
      for (var i = 0; i < steps.length; i++)
        TaskChecklistItem(
          id: '$id-c$i',
          taskId: id,
          title: steps[i].$1,
          isDone: steps[i].$2,
          sortOrder: i,
        ),
    ],
  );
}

final _activeTasks = <WeddingTask>[
  _t('t1', 'الاتفاق مع أهل العروسة على المهر والشرط', due: -40, status: 'DONE'),
  _t(
    't2',
    'حجز قاعة أو مخدرة الرجال',
    due: -20,
    status: 'DONE',
    category: 'VENUE',
  ),
  _t(
    't3',
    'تحديد موعد عقد القران',
    due: -7,
    priority: 'HIGH',
    steps: [
      ('الاتفاق مع الوالد على اليوم', true),
      ('كلّم الأمين الشرعي', false),
      ('بلّغ أهل العروسة', false),
    ],
  ),
  _t(
    't4',
    'حجز المصور',
    due: -3,
    category: 'PHOTOGRAPHY',
    who: 'صالح',
    phone: '+967771220914',
  ),
  _t('t5', 'شراء الشبكة والذهب', due: 0, priority: 'HIGH'),
  _t('t6', 'الاتفاق مع الفنان والفرقة', due: 4),
  _t(
    't7',
    'تجهيز أوراق عقد القران',
    due: 25,
    category: 'DOCUMENTS',
    steps: [
      ('بطاقتك الشخصية', true),
      ('شاهدين ومعهم بطاقاتهم', false),
      ('صور شخصية', false),
      ('بطاقة ولي العروسة', false),
    ],
  ),
  _t(
    't8',
    'الاتفاق على الوليمة والذبائح',
    due: 40,
    who: 'الوالد',
    phone: '+967733445566',
  ),
  _t('t9', 'ترتيب القات والمقيل', at: DateTime(2030, 3, 7)),
  _t('t10', 'ترتيب الزفة والسيارة', at: DateTime(2030, 3, 7), who: 'صالح'),
  _t('t11', 'توزيع الدعوات'),
  _t('t12', 'هدية العروسة', at: DateTime(2030, 3, 14), private: true),
];

Future<TaskTimelineProvider> _provider(List<WeddingTask> tasks) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  final p = TaskTimelineProvider(
    _Api(ApiClient(tokenProvider: storage.readAccessToken), tasks),
  );
  await p.load(_plan);
  return p;
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home,
  TaskTimelineProvider provider, {
  double h = 844,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<TaskTimelineProvider>.value(
      value: provider,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Keep the real view size: a bare MediaQueryData has size zero, which
        // collapses widths that read MediaQuery.sizeOf.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: SafeArea(child: home)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('t01 tasks empty', (tester) async {
    await _shot(
      tester,
      't01_tasks_empty',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(const []),
      h: 900,
    );
  });

  testWidgets('t02 tasks active', (tester) async {
    await _shot(
      tester,
      't02_tasks_active',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(_activeTasks),
      h: 1900,
    );
  });

  testWidgets('t03 tasks done shown', (tester) async {
    await _shot(
      tester,
      't03_tasks_done_open',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(_activeTasks),
      h: 2100,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('tasks-toggle-done')));
        await tester.pumpAndSettle();
      },
    );
  });

  // The «متأخرة» chip is gone: lateness is its own group, and the list can be
  // narrowed to one person or read by month («الوقت»).
  testWidgets('t04 one person', (tester) async {
    await _shot(
      tester,
      't04_person',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(_activeTasks),
      h: 900,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('task-person-صالح')));
        await tester.pumpAndSettle();
      },
    );
  });

  // R10: «للوالد», never «لالوالد», on the filter and on the task.
  testWidgets('a definite name joins «ل» the Arabic way', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    final task = _t('father', 'كلّم الخياط', who: 'الوالد', due: 5);
    final provider = await _provider([task]);

    Widget screen(Widget child) =>
        ChangeNotifierProvider<TaskTimelineProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: SafeArea(child: child)),
          ),
        );

    await tester.pumpWidget(
      screen(const TaskTimelineScreen(weddingPlanId: _plan)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('للوالد'), findsOneWidget);
    expect(find.text('لالوالد'), findsNothing);

    await tester.pumpWidget(
      screen(
        TaskDetailsScreen(
          weddingPlanId: _plan,
          taskId: task.id,
          initialTask: task,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('للوالد'), findsOneWidget);
  });

  testWidgets('t04 by month', (tester) async {
    await _shot(
      tester,
      't04_months',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(_activeTasks),
      h: 1500,
      act: () async {
        await tester.tap(find.text('الوقت'));
        await tester.pumpAndSettle();
      },
    );
  });

  // d04: a task opens on its own screen; its menu (x16) holds the actions.
  testWidgets('t05 task details and menu', (tester) async {
    final task = _activeTasks.firstWhere((t) => t.id == 't4');
    await _shot(
      tester,
      't05_task_menu',
      TaskDetailsScreen(
        weddingPlanId: _plan,
        taskId: task.id,
        initialTask: task,
      ),
      await _provider(_activeTasks),
      h: 900,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('task-menu')));
        // The route's animation starts on its first frame.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('t06 delete confirm', (tester) async {
    final task = _activeTasks.firstWhere((t) => t.id == 't4');
    await _shot(
      tester,
      't06_delete_confirm',
      TaskDetailsScreen(
        weddingPlanId: _plan,
        taskId: task.id,
        initialTask: task,
      ),
      await _provider(_activeTasks),
      h: 900,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('task-menu')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const ValueKey('task-menu-delete')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('t07 create task', (tester) async {
    await _shot(
      tester,
      't07_create_task',
      const CreateTaskScreen(weddingPlanId: _plan),
      await _provider(_activeTasks),
      h: 1300,
    );
  });

  testWidgets('t08 edit task with checklist', (tester) async {
    final task = _activeTasks.firstWhere((t) => t.id == 't3');
    await _shot(
      tester,
      't08_edit_task',
      CreateTaskScreen(
        weddingPlanId: _plan,
        taskId: task.id,
        initialTask: task,
      ),
      await _provider(_activeTasks),
      h: 1600,
    );
  });

  testWidgets('t09 edit private task', (tester) async {
    final task = _activeTasks.firstWhere((t) => t.id == 't12');
    await _shot(
      tester,
      't09_edit_private',
      CreateTaskScreen(
        weddingPlanId: _plan,
        taskId: task.id,
        initialTask: task,
      ),
      await _provider(_activeTasks),
      h: 1400,
    );
  });

  testWidgets('t10 starter sheet', (tester) async {
    // The real sheet, opened the way the tasks tab opens it (a modal sheet
    // over the empty tasks list) with the built-in groom groups, which mirror
    // the server catalog `tasks.starter`; the plan has a wedding date.
    final groups = taskStarterGroupsForPlan(
      taskStarterGroupsFor(null, TaskStarterPersona.groom),
      hasWeddingDate: true,
    );
    await _shot(
      tester,
      't10_starter',
      const TaskTimelineScreen(weddingPlanId: _plan),
      await _provider(const []),
      h: 1900,
      act: () async {
        final context = tester.element(find.byType(TaskTimelineScreen));
        showAarastBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => TaskStarterSheet(
            groups: groups,
            existingTitles: const {},
            hasWeddingDate: true,
            onSubmit: (_) async => null,
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  });
}
