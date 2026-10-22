import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_status_widgets.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'blocked sync opens safe item details instead of retrying invisibly',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final item = await database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/wedding-plans/plan-1/tasks',
        method: 'POST',
        payload: {'title': ''},
        planId: 'plan-1',
        localEntityId: 'local-task-1',
      );
      await database.markSyncItemBlocked(
        item.id,
        'title should not be empty at /api/v1/private-route',
      );
      final service = OfflineSyncService(
        database: database,
        apiClient: ApiClient(tokenProvider: () async => null),
      );
      await service.refreshStatus();

      await tester.pumpWidget(
        ChangeNotifierProvider<OfflineSyncService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfflineSyncNowTile()),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sync-issues-sheet')), findsOneWidget);
      // w41: the refused change is named and says why in plain words.
      expect(find.text('تغيير واحد ينتظر'), findsOneWidget);
      expect(find.text('إضافة مهمة'), findsOneWidget);
      expect(find.textContaining('السيرفر رفضه'), findsOneWidget);
      expect(find.textContaining('title should'), findsNothing);
      expect(find.byKey(const Key('sync-issues-retry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // w41: a change waiting for the network is listed by its own name, not
  // only counted, and the list fits 320 px with large text.
  testWidgets('a waiting change is listed by its name', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'احجز القاعة'},
      planId: 'plan-1',
    );
    final service = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await service.refreshStatus();

    await tester.pumpWidget(
      ChangeNotifierProvider<OfflineSyncService>.value(
        value: service,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: OfflineSyncNowTile()),
        ),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('تغيير واحد ينتظر'), findsOneWidget);
    expect(find.text('مهمة: احجز القاعة'), findsOneWidget);
    expect(find.textContaining('السيرفر رفضه'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
