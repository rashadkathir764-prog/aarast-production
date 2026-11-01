import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_checklist_item.dart';
import 'package:aarast_mobile/features/tasks/models/task_starter_catalog.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_starter_sheet.dart';
import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A failed action says why where it happened, and is not shown as a page
// that could not be refreshed. A failed read is the only "old copy" notice.

void main() {
  test('a failed action is not a failed read', () async {
    final api = _Api()..failUpdate = true;
    final provider = TaskTimelineProvider(api);
    await provider.load('plan-1');

    final ok = await provider.updateTaskStatus('plan-1', api.task, 'DONE');

    expect(ok, isFalse);
    expect(provider.errorMessage, 'المهمة ما تقبل هذا');
    expect(provider.loadErrorMessage, isNull);
  });

  test(
    'a save that went through but could not refresh is an old copy',
    () async {
      final api = _Api();
      final provider = TaskTimelineProvider(api);
      await provider.load('plan-1');
      api.failRead = true;

      final ok = await provider.updateTaskStatus('plan-1', api.task, 'DONE');

      expect(ok, isTrue);
      expect(provider.errorMessage, isNull);
      expect(provider.loadErrorMessage, isNotNull);

      // The next good read clears it.
      api.failRead = false;
      await provider.load('plan-1');
      expect(provider.loadErrorMessage, isNull);
    },
  );

  testWidgets('a failed delete says so and stays on the task', (tester) async {
    final api = _Api()..failDelete = true;
    final provider = TaskTimelineProvider(api);
    await provider.load('plan-1');
    await _pumpDetails(tester, provider);

    await tester.tap(find.byKey(const ValueKey('task-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-menu-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ما قدرنا نحذفها الحين'), findsOneWidget);
    expect(find.text('احجز القاعة'), findsWidgets);
    // An action is not a page that failed to refresh.
    expect(find.text('ما قدرنا نحدّثها، وهذي آخر نسخة'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a step that fails to save says so under the steps', (
    tester,
  ) async {
    final api = _Api()..failChecklist = true;
    final provider = TaskTimelineProvider(api);
    await provider.load('plan-1');
    await _pumpDetails(tester, provider);

    final item = find.byKey(const ValueKey('task-checklist-item-step-1'));
    await tester.ensureVisible(item);
    await tester.tap(
      find.descendant(of: item, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();

    expect(find.text('الخطوة ما انحفظت'), findsOneWidget);
  });

  testWidgets('suggested tasks that fail to add keep the sheet with why', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskStarterSheet(
            groups: const [
              TaskStarterGroup(
                key: 'g',
                title: 'مهام',
                subtitle: 'الأساسيات',
                templates: [
                  TaskStarterTemplate(
                    key: 'r',
                    title: 'احجز القاعة',
                    daysBefore: 30,
                    recommended: true,
                  ),
                ],
              ),
            ],
            existingTitles: const {},
            hasWeddingDate: false,
            onSubmit: (_) async => 'ما وصلنا للخادم',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('task-starter-submit')));
    await tester.pumpAndSettle();

    expect(find.text('ما وصلنا للخادم'), findsOneWidget);
    expect(find.byKey(const Key('task-starter-submit')), findsOneWidget);
  });

  testWidgets('a suggested task shows the day it will be saved with', (
    tester,
  ) async {
    // 100 days left and a 300-day task chosen: the set is compressed, so a
    // 30-day task lands 10 days before the wedding, not 30.
    final today = DateUtils.dateOnly(DateTime.now());
    final wedding = today.add(const Duration(days: 100));
    const templates = [
      TaskStarterTemplate(
        key: 'long',
        title: 'حدد موعد العرس',
        daysBefore: 300,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'short',
        title: 'احجز المصور',
        daysBefore: 30,
        recommended: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskStarterSheet(
            groups: const [
              TaskStarterGroup(
                key: 'g',
                title: 'مهام',
                subtitle: 'الأساسيات',
                templates: templates,
              ),
            ],
            existingTitles: const {},
            hasWeddingDate: true,
            weddingDate: wedding,
            onSubmit: (_) async => null,
          ),
        ),
      ),
    );

    final saved = taskStarterDueDate(
      wedding,
      30,
      today,
      longestDaysBefore: 300,
    )!;
    expect(saved, wedding.subtract(const Duration(days: 10)));
    expect(find.textContaining(formatArabicDayMonth(saved)), findsOneWidget);
    final uncompressed = wedding.subtract(const Duration(days: 30));
    expect(
      find.textContaining(formatArabicDayMonth(uncompressed)),
      findsNothing,
    );
  });
}

Future<void> _pumpDetails(
  WidgetTester tester,
  TaskTimelineProvider provider,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<TaskTimelineProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const TaskDetailsScreen(
          weddingPlanId: 'plan-1',
          taskId: 'task-1',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Api extends TaskTimelineApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  bool failUpdate = false;
  bool failDelete = false;
  bool failChecklist = false;
  bool failRead = false;

  WeddingTask task = WeddingTask(
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'احجز القاعة',
    status: 'TODO',
    priority: 'MEDIUM',
    checklist: const [
      TaskChecklistItem(
        id: 'step-1',
        taskId: 'task-1',
        title: 'اتصل بالقاعة',
        isDone: false,
        sortOrder: 0,
      ),
    ],
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );

  void _read() {
    if (failRead) {
      throw const ApiException('ما وصلنا', statusCode: 503);
    }
  }

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    _read();
    return [task];
  }

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async {
    _read();
    return Timeline.empty();
  }

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async {
    _read();
    return TaskSummary.empty(weddingPlanId);
  }

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    if (failUpdate) {
      throw const ApiException('المهمة ما تقبل هذا', statusCode: 400);
    }
    task = task.copyWith(status: data['status'] as String? ?? task.status);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    if (failDelete) {
      throw const ApiException('ما قدرنا نحذفها الحين', statusCode: 409);
    }
  }

  @override
  Future<TaskChecklistItem> updateChecklistItem(
    WeddingTask task,
    TaskChecklistItem item, {
    String? title,
    bool? isDone,
  }) async {
    if (failChecklist) {
      throw const ApiException('الخطوة ما انحفظت', statusCode: 400);
    }
    return item;
  }
}
