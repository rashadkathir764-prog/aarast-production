import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_checklist_item.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:aarast_mobile/features/tasks/utils/task_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// y14: a fireworks task gets the night box with the fireworks and the
/// safety note; every other task keeps the d04 look.
void main() {
  testWidgets('a fireworks task shows the hero, the steps and the note', (
    tester,
  ) async {
    await _pump(tester, _task('الألعاب النارية'));

    expect(find.text('الألعاب النارية'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-fireworks-hero')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('task-fireworks-hero')),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.text('خطوات صغيرة'), findsOneWidget);
    expect(find.text('اتفق مع المحل على الكمية'), findsOneWidget);
    expect(
      find.text(
        'واحد بس يشعّلها، والأطفال بعيد. انتبهوا للعيون والأيدي، '
        'فرحتك ما تستاهل إصابة.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('task-detail-done')), findsOneWidget);
    // Tasks have no money link: no item row and no amount.
    expect(find.text('البند'), findsNothing);
    expect(find.textContaining('ألف'), findsNothing);
    expect(find.textContaining('ر.ي'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('any other task keeps its look without the hero or the note', (
    tester,
  ) async {
    await _pump(tester, _task('احجز القاعة'));

    expect(find.text('احجز القاعة'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-fireworks-hero')), findsNothing);
    expect(find.byKey(const ValueKey('task-fireworks-safety')), findsNothing);
    expect(find.text('خطوات صغيرة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('fireworks tasks are known by their title, however it is spelt', () {
    for (final title in const [
      'الألعاب النارية',
      'ألعاب نارية',
      'اشتري العاب ناريه للزفة',
      'الألعاب الناريّة',
    ]) {
      expect(isFireworksTask(_task(title)), isTrue, reason: title);
    }
    for (final title in const ['احجز القاعة', 'ألعاب للأطفال', 'الزينة']) {
      expect(isFireworksTask(_task(title)), isFalse, reason: title);
    }
  });
}

WeddingTask _task(String title) => WeddingTask(
  id: 'task-1',
  weddingPlanId: 'plan-1',
  title: title,
  status: 'TODO',
  priority: 'MEDIUM',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  dueDate: DateTime.now().add(const Duration(days: 30)),
  responsibleName: 'صالح',
  checklist: const [
    TaskChecklistItem(
      id: 'step-1',
      taskId: 'task-1',
      title: 'اتفق مع المحل على الكمية',
      isDone: true,
      sortOrder: 0,
    ),
    TaskChecklistItem(
      id: 'step-2',
      taskId: 'task-1',
      title: 'حدد مكان بعيد عن الضيوف والسيارات',
      isDone: false,
      sortOrder: 1,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, WeddingTask task) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<TaskTimelineProvider>.value(
      value: _Tasks([task]),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: TaskDetailsScreen(weddingPlanId: 'plan-1', taskId: task.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Tasks extends TaskTimelineProvider {
  _Tasks(this._list)
    : super(TaskTimelineApi(ApiClient(tokenProvider: () async => null)));

  final List<WeddingTask> _list;

  @override
  List<WeddingTask> get tasks => _list;

  @override
  Future<void> load(String weddingPlanId) async {}
}
