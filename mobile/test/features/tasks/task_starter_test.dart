import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/catalogs/catalogs_api.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_starter_catalog.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_starter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Suggested tasks for a new plan (V1 checklist 4.9).

void main() {
  test('each persona sees its own, the shared and the family tasks', () {
    List<String> keys(TaskStarterPersona persona) => [
      for (final group in taskStarterGroupsFor(null, persona)) group.key,
    ];
    expect(keys(TaskStarterPersona.groom), [
      'shared-tasks',
      'groom-tasks',
      'family-tasks',
    ]);
    expect(keys(TaskStarterPersona.bride), [
      'shared-tasks',
      'bride-tasks',
      'family-tasks',
    ]);
    expect(keys(TaskStarterPersona.neutral), hasLength(4));
  });

  // Field test Q05: a wedding 126 days away got every task needing more
  // lead time than that due today, and all of them filed as "other".
  test('a short engagement spreads the tasks instead of piling them today', () {
    final today = DateTime(2026, 10, 15);
    final wedding = DateTime(2027, 2, 18); // 126 days away
    DateTime? due(int days) => taskStarterDueDate(
      wedding,
      days,
      today,
      longestDaysBefore: 300,
    );

    expect(due(300), today);
    expect(due(180), DateTime(2026, 12, 4)); // 180 * 126 / 300 = 76 days
    expect(due(30), DateTime(2027, 2, 5)); // 30 * 126 / 300 = 13 days
    expect(due(180)!.isBefore(due(30)!), isTrue);
    // Enough time left: the catalog offsets are kept as they are.
    expect(
      taskStarterDueDate(wedding, 30, today, longestDaysBefore: 120),
      DateTime(2027, 1, 19),
    );
  });

  test('built-in suggested tasks carry their task category', () {
    final templates = {
      for (final group in taskStarterGroupsFor(null, TaskStarterPersona.groom))
        for (final item in group.templates) item.key: item,
    };
    expect(templates['task-groom-venue']?.taskCategory, 'VENUE');
    expect(templates['task-shared-photo']?.taskCategory, 'PHOTOGRAPHY');
    expect(templates['task-shared-date']?.taskCategory, isNull);
  });

  // Field test Q06: "set the wedding date" was offered to a plan with a date.
  test('a plan with a wedding date is not offered to set it', () {
    final groups = taskStarterGroupsFor(null, TaskStarterPersona.groom);
    final keys = {
      for (final group in taskStarterGroupsForPlan(
        groups,
        hasWeddingDate: true,
      ))
        for (final item in group.templates) item.key,
    };
    expect(keys, isNot(contains(taskStarterWeddingDateKey)));
    expect(keys, contains('task-shared-budget'));

    final undated = {
      for (final group in taskStarterGroupsForPlan(
        groups,
        hasWeddingDate: false,
      ))
        for (final item in group.templates) item.key,
    };
    expect(undated, contains(taskStarterWeddingDateKey));
  });

  // Field test Q01: a groom's guest plan was offered the bride's tasks because
  // only the plans provider was consulted, and it does not hold a guest plan.
  test('the persona comes from the first source that describes the plan', () {
    expect(
      taskStarterPersonaFor('guest-1', [
        (planId: null, persona: null),
        (planId: 'other', persona: 'BRIDE'),
        (planId: 'guest-1', persona: 'groom'),
      ]),
      TaskStarterPersona.groom,
    );
    expect(
      taskStarterPersonaFor('plan-1', [
        (planId: 'plan-1', persona: 'groom'),
        (planId: 'plan-1', persona: 'BRIDE'),
      ]),
      TaskStarterPersona.groom,
    );
    expect(
      taskStarterPersonaFor('plan-1', [
        (planId: 'plan-1', persona: null),
        (planId: 'plan-1', persona: 'bride'),
      ]),
      TaskStarterPersona.bride,
    );
    expect(
      taskStarterPersonaFor('plan-1', [(planId: 'other', persona: 'groom')]),
      TaskStarterPersona.neutral,
    );
  });

  test('the managed catalog wins and carries the due offset', () {
    final managed = ManagedReferenceCatalog.fromJson({
      'key': taskStarterCatalogKey,
      'nameAr': 'قوالب المهام',
      'version': 2,
      'items': [
        _item(
          'task-bride-dress',
          'اختيار الفستان',
          'bride-tasks',
          20,
          groom: false,
          bride: true,
          daysBefore: '150',
          recommended: true,
        ),
        _item(
          'task-groom-mahr',
          'المهر والشرط',
          'groom-tasks',
          10,
          groom: true,
          bride: false,
          daysBefore: '270',
        ),
        _item(
          'task-shared-new',
          'مهمة أضافها الأدمن',
          'shared-tasks',
          5,
          groom: true,
          bride: true,
        ),
      ],
    });

    final bride = taskStarterGroupsFor(managed, TaskStarterPersona.bride);
    expect(bride.map((group) => group.key), ['shared-tasks', 'bride-tasks']);
    final dress = bride.last.templates.single;
    expect(dress.title, 'اختيار الفستان');
    expect(dress.daysBefore, 150);
    expect(dress.recommended, isTrue);
    expect(bride.first.templates.single.daysBefore, isNull);
  });

  test('due dates count back from the wedding and never land in the past', () {
    final today = DateTime(2026, 10, 11);
    final wedding = DateTime(2027, 3, 1);
    expect(taskStarterDueDate(wedding, 30, today), DateTime(2027, 1, 30));
    expect(taskStarterDueDate(wedding, 300, today), today);
    expect(taskStarterDueDate(null, 30, today), isNull);
    expect(taskStarterDueDate(wedding, null, today), isNull);
  });

  test('adding suggested tasks skips what the plan already has', () async {
    final api = _StarterApi();
    final provider = TaskTimelineProvider(api);
    await provider.load('plan-1');

    final added = await provider.addStarterTasks(
      weddingPlanId: 'plan-1',
      templates: const [
        TaskStarterTemplate(key: 'a', title: 'حجز  القاعة ', daysBefore: 180),
        TaskStarterTemplate(key: 'b', title: 'شراء الشبكة', daysBefore: 30),
      ],
      weddingDate: DateTime(2027, 3, 1),
      today: DateTime(2026, 10, 11),
    );

    expect(added, 1);
    expect(api.created.single.title, 'شراء الشبكة');
    expect(api.created.single.dueDate, DateTime(2027, 1, 30));
    expect(provider.errorMessage, isNull);
  });

  test('a partial failure keeps what was saved and says how much', () async {
    final api = _StarterApi()..failAfter = 1;
    final provider = TaskTimelineProvider(api);
    await provider.load('plan-1');

    final added = await provider.addStarterTasks(
      weddingPlanId: 'plan-1',
      templates: const [
        TaskStarterTemplate(key: 'a', title: 'مهمة أولى', daysBefore: null),
        TaskStarterTemplate(key: 'b', title: 'مهمة ثانية', daysBefore: null),
        TaskStarterTemplate(key: 'c', title: 'مهمة ثالثة', daysBefore: null),
      ],
      weddingDate: null,
    );

    expect(added, 1);
    expect(
      provider.errorMessage,
      'أُضيفت 1 من 3 مهام، وتعذر حفظ الباقي: انقطع الاتصال.',
    );
  });

  testWidgets('the sheet preselects recommended tasks and marks added ones', (
    tester,
  ) async {
    List<TaskStarterTemplate>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskStarterSheet(
            groups: const [
              TaskStarterGroup(
                key: 'shared-tasks',
                title: 'مهام مشتركة',
                subtitle: 'الأساسيات',
                templates: [
                  TaskStarterTemplate(
                    key: 'r',
                    title: 'تحديد موعد العرس',
                    daysBefore: 300,
                    recommended: true,
                  ),
                  TaskStarterTemplate(
                    key: 'o',
                    title: 'حجز المصور',
                    daysBefore: 120,
                  ),
                  TaskStarterTemplate(
                    key: 'x',
                    title: 'إعداد قائمة المعازيم',
                    daysBefore: 90,
                    recommended: true,
                  ),
                ],
              ),
            ],
            existingTitles: {taskStarterTitleKey('إعداد قائمة المعازيم')},
            hasWeddingDate: true,
            onSubmit: (templates) async {
              submitted = templates;
              return false;
            },
          ),
        ),
      ),
    );

    expect(find.text('في خطتك'), findsOneWidget);
    expect(find.text('إضافة 1 إلى خطتي'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-starter-o')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('task-starter-submit')));
    await tester.pump();

    expect(submitted?.map((item) => item.key), ['r', 'o']);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _item(
  String key,
  String name,
  String group,
  int sortOrder, {
  required bool groom,
  required bool bride,
  String? daysBefore,
  bool recommended = false,
}) => {
  'key': key,
  'nameAr': name,
  'groupKey': group,
  'groupNameAr': group,
  'sortOrder': sortOrder,
  'showForGroom': groom,
  'showForBride': bride,
  'showForCustomer': true,
  'isRecommended': recommended,
  'metadata': {'daysBefore': ?daysBefore},
};

class _StarterApi extends TaskTimelineApi {
  _StarterApi() : super(ApiClient(tokenProvider: () async => null));

  final List<WeddingTask> created = [];
  int? failAfter;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [
    WeddingTask(
      id: 'task-existing',
      weddingPlanId: 'plan-1',
      title: 'حجز القاعة',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    ),
    ...created,
  ];

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

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
  }) async {
    if (failAfter != null && created.length >= failAfter!) {
      throw const ApiException('انقطع الاتصال.');
    }
    final task = WeddingTask(
      id: 'task-${created.length}',
      weddingPlanId: weddingPlanId,
      title: title,
      status: status,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.utc(2026, 10, 11),
      updatedAt: DateTime.utc(2026, 10, 11),
    );
    created.add(task);
    return task;
  }
}
