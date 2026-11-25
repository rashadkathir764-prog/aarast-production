import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_status_widgets.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/app_text_scale.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'blocked sync opens safe item details instead of retrying invisibly',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        1.3,
      ).scale(1);
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
      // Changed on purpose (UX critique, home_sync_blocked): a refused change
      // does not wait for the network, so the sheet does not say it does.
      expect(find.text('تغيير واحد ما انقبل'), findsOneWidget);
      expect(find.text('تغيير واحد ينتظر'), findsNothing);
      expect(find.textContaining('أول ما يرجع النت'), findsNothing);
      expect(find.text('إضافة مهمة'), findsOneWidget);
      // Changed on purpose (Q-32): «ما انقبل», without «الخادم».
      expect(find.textContaining('ما انقبل، ويحتاج مراجعة'), findsOneWidget);
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
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      1.3,
    ).scale(1);
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
    expect(find.textContaining('ما انقبل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-344: a change refused because the row changed elsewhere can never
  // go as it is: the sheet offers only to drop it, with the reason.
  testWidgets('a change refused as changed elsewhere offers only to drop it', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final item = await database.enqueueSync(
      entityType: 'guest',
      operation: 'update',
      endpoint: '/api/v1/guests/g1',
      method: 'PATCH',
      payload: {
        'name': 'خالد',
        'expected': {'name': 'خلد'},
      },
      planId: 'plan-1',
      localEntityId: 'g1',
    );
    final api = ApiClient(tokenProvider: () async => 'token');
    api.dio.httpClientAdapter = _Answers(
      409,
      '{"statusCode":409,"code":"CHANGED_ELSEWHERE",'
      '"message":"الضيف تغيّر من جهاز ثاني. حدّث الشاشة وعدّل من جديد."}',
    );
    final service = OfflineSyncService(database: database, apiClient: api);
    await service.ensureCacheOwner('user-A');
    await tester.runAsync(service.syncPendingChanges);
    expect(service.blockedCount, 1);

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

    expect(find.textContaining('الضيف تغيّر من جهاز ثاني'), findsOneWidget);
    expect(find.byKey(ValueKey('sync-discard-${item.id}')), findsOneWidget);
    expect(find.byKey(const Key('sync-issues-retry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // UX critique (home_sync_blocked): «احذفه» deleted the change at once,
  // with no way back. It asks first, by the change's name; «رجوع» keeps it.
  testWidgets('dropping a refused change asks first', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final item = await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'احجز القاعة'},
      planId: 'plan-1',
    );
    await database.markSyncItemBlocked(item.id, 'ما انقبل، ويحتاج مراجعة');
    final service = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await service.refreshStatus();
    expect(service.blockedCount, 1);

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

    // The reason is read whole, not cut at one line.
    final reason = tester.widget<Text>(
      find.textContaining('ما انقبل، ويحتاج مراجعة'),
    );
    expect(reason.maxLines, greaterThanOrEqualTo(2));

    await tester.tap(find.byKey(ValueKey('sync-discard-${item.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-discard-confirm')), findsOneWidget);
    expect(find.text('تمسح «مهمة: احجز القاعة» من جوالك؟'), findsOneWidget);
    expect(find.text('ما يرجع بعدها.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-discard-no')));
    await tester.pumpAndSettle();
    await tester.runAsync(service.refreshStatus);
    expect(service.blockedCount, 1);
    expect(find.byKey(const Key('sync-issues-sheet')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('sync-discard-${item.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sync-discard-yes')));
    await tester.pumpAndSettle();
    await tester.runAsync(service.refreshStatus);
    expect(service.blockedCount, 0);
    expect(tester.takeException(), isNull);
  });
}

/// Answers every request with [status] and [body].
class _Answers implements HttpClientAdapter {
  _Answers(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
