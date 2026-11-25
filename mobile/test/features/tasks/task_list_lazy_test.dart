import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-367: the tasks list built every row at once, so a plan with a long
// list paid for all of them on each build. Its rows are built as they come
// into view; the last one is still reached by scrolling.

const _planId = 'guest-plan-lazy';
const _count = 120;

void main() {
  testWidgets('the tasks list builds its rows as they come into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(database: database, apiClient: apiClient);
    await offline.refreshStatus();
    final provider = TaskTimelineProvider(
      TaskTimelineApi(apiClient, offline: offline),
    );
    // Far-off days, so every task sits in one open group, in this order.
    final start = DateTime(2030, 1, 1);
    for (var index = 0; index < _count; index++) {
      await provider.createTask(
        weddingPlanId: _planId,
        title: 'مهمة رقم ${index + 1}',
        dueDate: start.add(Duration(days: index)),
        taskCategory: 'GENERAL',
      );
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
        ],
        child: MaterialApp(
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

    final built = find.byType(TaskRow).evaluate().length;
    expect(built, greaterThan(0));
    expect(
      built,
      lessThan(_count ~/ 2),
      reason: 'every row was built at once ($built of $_count)',
    );

    await tester.scrollUntilVisible(
      find.text('مهمة رقم $_count'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('مهمة رقم $_count'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
