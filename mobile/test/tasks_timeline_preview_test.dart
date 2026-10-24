// Visual preview for the redesigned tasks tab (TaskTimelineScreen):
// interactive hero filter chips + grouped timeline rail + collapsed done.
//
// Pumps the REAL screen (no widget replicas) over the local-plan JSON
// database, mirroring the super3 contract harness.
//
// Regenerate with:
//   flutter test test/tasks_timeline_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';

const _planId = 'guest-plan-preview';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('tasks — grouped timeline root (420)', (tester) async {
    tester.view.physicalSize = const Size(420, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    await offline.refreshStatus();
    final api = TaskTimelineApi(apiClient, offline: offline);
    final provider = TaskTimelineProvider(api);

    // Fixed dates: the screen reads today's clock, so a golden that leans on
    // «اليوم» or «هذا الأسبوع» would age by the day. A past date is always
    // late and a 2030 date is always «بعدين».
    final late = DateTime(2026, 6, 4);
    final later = DateTime(2030, 3, 4);
    await provider.createTask(
      weddingPlanId: _planId,
      title: 'تأكيد حجز الصالة',
      dueDate: late,
      taskCategory: 'VENUE',
      priority: 'HIGH',
      responsibleName: 'أحمد',
    );
    await provider.createTask(
      weddingPlanId: _planId,
      title: 'اختيار المصور والاتفاق على الباقة',
      dueDate: later,
      taskCategory: 'PHOTOGRAPHY',
    );
    await provider.createTask(
      weddingPlanId: _planId,
      title: 'طباعة بطاقات الدعوة',
      dueDate: later.add(const Duration(days: 3)),
      taskCategory: 'DOCUMENTS',
    );
    await provider.createTask(
      weddingPlanId: _planId,
      title: 'تأكيد قائمة الأغاني مع الفرقة',
      taskCategory: 'GENERAL',
    );
    await provider.createTask(
      weddingPlanId: _planId,
      title: 'شراء بدلة العريس',
      dueDate: DateTime(2026, 5, 20),
      taskCategory: 'ATTIRE',
    );
    final doneTask = provider.tasks.firstWhere(
      (task) => task.title == 'شراء بدلة العريس',
    );
    await provider.markTaskDone(_planId, doneTask);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: TaskTimelineScreen(weddingPlanId: _planId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(TaskTimelineScreen),
      matchesGoldenFile('goldens/tasks_timeline.png'),
    );
  });
}
