// Full-screen visual preview for the "add task" (إضافة مهمة) form after the
// mobile-design-polish compaction pass — slim hero, side-by-side category/date,
// tightened vertical rhythm — exactly as a guest planner sees it.
//
// Regenerate with:
//   flutter test test/create_task_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';

import 'support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('add task — compacted form (390)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(prefs);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(prefs);
    await database.initialize();
    final offline = OfflineSyncService(database: database, apiClient: apiClient);
    await offline.refreshStatus();

    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<TaskTimelineProvider>(
            create: (_) =>
                TaskTimelineProvider(TaskTimelineApi(apiClient, offline: offline)),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const CreateTaskScreen(weddingPlanId: 'guest-plan-preview'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(CreateTaskScreen),
      matchesGoldenFile('goldens/create_task_form.png'),
    );
  });
}
