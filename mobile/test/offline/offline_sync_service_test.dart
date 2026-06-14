import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('refreshStatus exposes pending count and pending entity keys', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    final service = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );

    await service.refreshStatus();
    expect(service.pendingCount, 0);
    expect(service.hasPendingEntity('task', 'local-task-1'), isFalse);

    await database.enqueueSync(
      entityType: 'task',
      operation: 'create',
      endpoint: '/wedding-plans/plan-1/tasks',
      method: 'POST',
      payload: {'title': 'Offline task'},
      localEntityId: 'local-task-1',
    );

    await service.refreshStatus();

    expect(service.pendingCount, 1);
    expect(service.hasPendingEntity('task', 'local-task-1'), isTrue);
  });
}
