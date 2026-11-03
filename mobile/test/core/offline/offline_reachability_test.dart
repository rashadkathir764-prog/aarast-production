import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_status_widgets.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D84: «بدون نت» is a measured state that ends with the first answer from
// the server, and the banner says the measured cause.

Future<OfflineSyncService> _service(ServerReachability reachability) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final service = OfflineSyncService(
    database: database,
    apiClient: ApiClient(tokenProvider: () async => null),
    reachability: reachability,
  );
  await service.refreshStatus();
  return service;
}

Future<void> _pumpBanner(WidgetTester tester, OfflineSyncService service) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ChangeNotifierProvider<OfflineSyncService>.value(
      value: service,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: OfflineStatusBanner()),
      ),
    ),
  );
}

void main() {
  test('the first answer from the server ends the offline state', () async {
    final reachability = ServerReachability();
    final service = await _service(reachability);
    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.timeout,
        at: DateTime(2026, 11, 3),
      ),
    );
    await service.noteNetworkFailure('الخادم تأخر في الرد');
    expect(service.state, SyncState.offline);

    reachability.noteReached();
    await Future<void>.delayed(Duration.zero);

    expect(service.state, isNot(SyncState.offline));
    expect(service.lastError, isNull);
  });

  testWidgets('a slow server is not «بدون نت»', (tester) async {
    final reachability = ServerReachability();
    final service = await _service(reachability);
    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.timeout,
        at: DateTime(2026, 11, 3),
      ),
    );
    await service.noteNetworkFailure('الخادم تأخر في الرد');
    await _pumpBanner(tester, service);

    expect(find.textContaining('بدون نت'), findsNothing);
    expect(
      find.text('ما نقدر نوصل للخادم الحين، واللي تضيفه ينحفظ في جوالك'),
      findsOneWidget,
    );
    expect(find.text('الخادم تأخر في الرد · اضغط للفحص'), findsOneWidget);
  });

  testWidgets('a phone without net is «بدون نت»', (tester) async {
    final reachability = ServerReachability();
    final service = await _service(reachability);
    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.noNetwork,
        at: DateTime(2026, 11, 3),
      ),
    );
    await service.noteNetworkFailure('ما فيه نت');
    await _pumpBanner(tester, service);

    expect(find.text('بدون نت، واللي تضيفه ينحفظ في جوالك'), findsOneWidget);
    expect(
      find.text('ما فيه نت في الجوال الحين · اضغط للفحص'),
      findsOneWidget,
    );
  });
}
