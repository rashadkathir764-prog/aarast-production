import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_checklist_item.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_checklist_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a task parses its ordered checklist from the API', () {
    final task = WeddingTask.fromJson({
      'id': 'task-1',
      'weddingPlanId': 'plan-1',
      'title': 'حجز القاعة',
      'checklist': [
        {
          'id': 'a',
          'taskId': 'task-1',
          'title': 'الاتصال',
          'isDone': true,
          'sortOrder': 0,
        },
        {
          'id': 'b',
          'taskId': 'task-1',
          'title': 'العربون',
          'isDone': false,
          'sortOrder': 1,
        },
      ],
    });

    expect(task.checklist.map((item) => item.id), ['a', 'b']);
    expect(task.checklistDoneCount, 1);
  });

  group('TaskTimelineProvider checklist', () {
    late _ChecklistApi api;
    late TaskTimelineProvider provider;

    setUp(() async {
      api = _ChecklistApi();
      provider = TaskTimelineProvider(api);
      await provider.load('plan-1');
    });

    WeddingTask shown() =>
        provider.tasks.singleWhere((task) => task.id == 'task-1');

    test('add, complete, rename and remove show the saved steps', () async {
      expect(await provider.addChecklistItem(shown(), 'الاتصال'), isTrue);
      expect(await provider.addChecklistItem(shown(), 'العربون'), isTrue);
      final first = shown().checklist.first;

      expect(
        await provider.updateChecklistItem(shown(), first, isDone: true),
        isTrue,
      );
      expect(
        await provider.updateChecklistItem(
          shown(),
          first,
          title: 'الاتصال بالقاعة',
        ),
        isTrue,
      );
      expect(shown().checklist.first.isDone, isTrue);
      expect(shown().checklist.first.title, 'الاتصال بالقاعة');

      expect(
        await provider.removeChecklistItem(shown(), shown().checklist.last),
        isTrue,
      );
      expect(shown().checklist.map((item) => item.title), ['الاتصال بالقاعة']);
      expect(provider.checklistErrorMessage, isNull);
    });

    test('a rejected change keeps the steps and says why', () async {
      await provider.addChecklistItem(shown(), 'الاتصال');
      api.reject = true;

      final ok = await provider.updateChecklistItem(
        shown(),
        shown().checklist.single,
        isDone: true,
      );

      expect(ok, isFalse);
      expect(shown().checklist.single.isDone, isFalse);
      expect(provider.checklistErrorMessage, 'لا تملك صلاحية إدارة المهام.');
      expect(provider.isSavingChecklist, isFalse);
    });
  });

  testWidgets('the section adds, completes, renames and removes steps', (
    tester,
  ) async {
    final added = <String>[];
    final toggled = <String>[];
    final renamed = <String>[];
    final removed = <String>[];
    const item = TaskChecklistItem(
      id: 'a',
      taskId: 'task-1',
      title: 'الاتصال',
      isDone: false,
      sortOrder: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TaskChecklistSection(
                items: const [item],
                saving: false,
                onAdd: (title) async {
                  added.add(title);
                  return true;
                },
                onToggle: (item, isDone) => toggled.add('${item.id}:$isDone'),
                onRename: (item, title) => renamed.add('${item.id}:$title'),
                onRemove: (item) => removed.add(item.id),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('خطوات صغيرة'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task-checklist-new-item')),
      'دفع العربون',
    );
    await tester.tap(find.byKey(const ValueKey('task-checklist-add')));
    await tester.pumpAndSettle();
    expect(added, ['دفع العربون']);
    expect(find.text('دفع العربون'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    expect(toggled, ['a:true']);

    await tester.tap(find.text('الاتصال'));
    await tester.pumpAndSettle();
    // The rename opens as a journey sheet, not a Material dialog.
    expect(find.byKey(const ValueKey('journey-sheet-handle')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('task-checklist-rename-field')),
      'الاتصال بالقاعة',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(renamed, ['a:الاتصال بالقاعة']);

    await tester.tap(find.byTooltip('شيل الخطوة الاتصال'));
    expect(removed, ['a']);
  });
}

class _ChecklistApi extends TaskTimelineApi {
  _ChecklistApi() : super(ApiClient(tokenProvider: () async => null));

  bool reject = false;
  int _sequence = 0;

  /// What the server has saved, so a PATCH applies to the stored item like
  /// the real endpoint does, not to the possibly stale item the app sent.
  final Map<String, TaskChecklistItem> _stored = {};

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [
    WeddingTask(
      id: 'task-1',
      weddingPlanId: 'plan-1',
      title: 'حجز القاعة',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  void _gate() {
    if (reject) {
      throw const ApiException('لا تملك صلاحية إدارة المهام.', statusCode: 403);
    }
  }

  @override
  Future<TaskChecklistItem> createChecklistItem(
    WeddingTask task,
    String title,
  ) async {
    _gate();
    _sequence += 1;
    final item = TaskChecklistItem(
      id: 'item-$_sequence',
      taskId: task.id,
      title: title,
      isDone: false,
      sortOrder: task.checklist.length,
    );
    return _stored[item.id] = item;
  }

  @override
  Future<TaskChecklistItem> updateChecklistItem(
    WeddingTask task,
    TaskChecklistItem item, {
    String? title,
    bool? isDone,
  }) async {
    _gate();
    final saved = _stored[item.id]!;
    return _stored[item.id] = TaskChecklistItem(
      id: saved.id,
      taskId: saved.taskId,
      title: title ?? saved.title,
      isDone: isDone ?? saved.isDone,
      sortOrder: saved.sortOrder,
    );
  }

  @override
  Future<void> deleteChecklistItem(
    WeddingTask task,
    TaskChecklistItem item,
  ) async {
    _gate();
  }
}
