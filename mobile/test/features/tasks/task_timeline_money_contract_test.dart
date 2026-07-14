import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('timeline parses the canonical paymentSchedules contract', () {
    final timeline = Timeline.fromJson({
      'upcomingTasks': const [],
      'paymentSchedules': [
        {
          'id': 'schedule-1',
          'weddingCostId': 'cost-1',
          'costTitle': 'القاعة',
          'amount': '125000',
          'dueDate': '2026-08-01T12:30:00.000Z',
          'status': 'PENDING',
        },
      ],
    });

    expect(timeline.paymentSchedules, hasLength(1));
    final schedule = timeline.paymentSchedules.single;
    expect(schedule.id, 'schedule-1');
    expect(schedule.weddingCostId, 'cost-1');
    expect(schedule.costTitle, 'القاعة');
    expect(schedule.amount, '125000');
    expect(schedule.dueDate, DateTime.utc(2026, 8, 1, 12, 30));
    expect(schedule.status, 'PENDING');
  });

  test('timeline does not consume removed financial timeline collections', () {
    final timeline = Timeline.fromJson({
      'upcomingTasks': const [],
      'dueCommitments': [
        {
          'id': 'legacy-commitment',
          'amount': '1000',
          'dueDate': '2026-08-02T00:00:00.000Z',
        },
      ],
      'dueInstallments': [
        {
          'id': 'legacy-installment',
          'amount': '2000',
          'dueDate': '2026-08-03T00:00:00.000Z',
        },
      ],
    });

    expect(timeline.paymentSchedules, isEmpty);
  });

  test(
    'local timeline fallback exposes canonical cached payment schedules',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final offline = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      const planId = 'guest-plan-timeline-money-contract';

      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {
          'id': 'cost-cached',
          'weddingPlanId': planId,
          'budgetCategoryId': 'category-cached',
          'title': 'التصوير',
          'totalAmount': '80000',
          'paidAmount': '0',
          'status': 'OPEN',
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-cached',
          'weddingPlanId': planId,
          'weddingCostId': 'cost-cached',
          'amount': '80000',
          'dueDate': '2026-08-05T00:00:00.000Z',
          'status': 'PENDING',
        },
      );

      final timeline = await TaskTimelineApi(
        apiClient,
        offline: offline,
      ).getTimeline(planId);

      expect(timeline.paymentSchedules, hasLength(1));
      final schedule = timeline.paymentSchedules.single;
      expect(schedule.id, 'schedule-cached');
      expect(schedule.weddingCostId, 'cost-cached');
      expect(schedule.costTitle, 'التصوير');
      expect(schedule.amount, '80000');
      expect(schedule.dueDate, DateTime.utc(2026, 8, 5));
      expect(schedule.status, 'PENDING');
    },
  );
}
