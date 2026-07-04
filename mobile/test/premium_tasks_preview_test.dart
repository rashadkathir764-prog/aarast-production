// Visual preview for the NEW premium task widgets
// (phase/mobile-premium-screens-v1): TasksProgressHero + SmartTaskCard.
//
// Regenerate with:
//   flutter test test/premium_tasks_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/widgets/premium/smart_task_card.dart';
import 'package:aarast_mobile/features/tasks/widgets/premium/tasks_progress_hero.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('packages/lucide_icons/Lucide',
      ['packages/lucide_icons/assets/lucide.ttf']);
}

final _now = DateTime(2026, 7, 4);

WeddingTask _task({
  required String title,
  required String status,
  required String priority,
  String? category,
  DateTime? due,
  String? responsible,
}) {
  return WeddingTask(
    id: title,
    weddingPlanId: 'p1',
    title: title,
    status: status,
    priority: priority,
    taskCategory: category,
    dueDate: due,
    responsibleName: responsible,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pump(WidgetTester tester, Widget child,
    {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('tasks — active list (420)', (tester) async {
    const summary = TaskSummary(
      weddingPlanId: 'p1',
      total: 8,
      completed: 3,
      pendingInProgress: 5,
      overdue: 1,
      dueToday: 2,
      highPriority: 2,
    );
    final tasks = [
      _task(
        title: 'تأكيد حجز الصالة',
        status: 'TODO',
        priority: 'HIGH',
        category: 'VENUE',
        due: DateTime(2026, 7, 1),
        responsible: 'أحمد',
      ),
      _task(
        title: 'اختيار المصور والاتفاق على الباقة',
        status: 'TODO',
        priority: 'MEDIUM',
        category: 'PHOTOGRAPHY',
        due: DateTime(2026, 7, 4),
      ),
      _task(
        title: 'شراء ملابس العريس',
        status: 'DONE',
        priority: 'LOW',
        category: 'ATTIRE',
        due: DateTime(2026, 6, 20),
      ),
    ];
    await _pump(
      tester,
      Column(
        children: [
          const TasksProgressHero(summary: summary),
          const SizedBox(height: 14),
          for (final t in tasks) ...[
            SmartTaskCard(
              task: t,
              isBusy: false,
              onEdit: () {},
              onDelete: () {},
              onMarkDone: t.isDone ? null : () {},
              onReopen: t.isDone ? () {} : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
      size: const Size(420, 1200),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_tasks_active.png'),
    );
  });

  testWidgets('tasks — fresh plan hero (420)', (tester) async {
    const summary = TaskSummary(
      weddingPlanId: 'p1',
      total: 0,
      completed: 0,
      pendingInProgress: 0,
      overdue: 0,
      dueToday: 0,
      highPriority: 0,
    );
    await _pump(
      tester,
      const TasksProgressHero(summary: summary, isLocalPlan: true),
      size: const Size(420, 400),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_tasks_fresh.png'),
    );
  });
}
