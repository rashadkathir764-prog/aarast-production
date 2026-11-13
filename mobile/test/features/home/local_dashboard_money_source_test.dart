import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'local dashboard derives money from costs and payment schedules',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      const planId = 'local-money-plan';
      final now = DateTime.now();

      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {
          'id': 'cost-active',
          'planId': planId,
          'weddingPlanId': planId,
          'title': 'القاعة',
          'totalAmount': '1000',
          'paidAmount': '400',
          'status': 'PARTIALLY_PAID',
          'createdAt': now.toIso8601String(),
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {
          'id': 'cost-cancelled',
          'planId': planId,
          'weddingPlanId': planId,
          'title': 'تكلفة ملغاة',
          'totalAmount': '9000',
          'paidAmount': '0',
          'status': 'CANCELLED',
          'createdAt': now.toIso8601String(),
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-active',
          'planId': planId,
          'weddingPlanId': planId,
          'costId': 'cost-active',
          'amount': '600',
          'dueDate': now.add(const Duration(days: 2)).toIso8601String(),
          'status': 'PENDING',
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-paid',
          'planId': planId,
          'weddingPlanId': planId,
          'costId': 'cost-active',
          'amount': '100',
          'dueDate': now.toIso8601String(),
          'status': 'PAID',
        },
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-cancelled-cost',
          'planId': planId,
          'weddingPlanId': planId,
          'costId': 'cost-cancelled',
          'amount': '9000',
          'dueDate': now.toIso8601String(),
          'status': 'PENDING',
        },
      );

      final metrics = await LocalDashboardMetrics.load(
        database: database,
        planId: planId,
      );

      expect(metrics.confirmedCostTotal, 1000);
      expect(metrics.paidTotal, 400);
      expect(metrics.outstandingTotal, 600);
      expect(metrics.duePaymentSchedulesCount, 1);
      expect(metrics.nextPaymentScheduleDue?.id, 'schedule-active');
      expect(metrics.nextPaymentScheduleDue?.weddingCostId, 'cost-active');
      expect(
        metrics.importantItems.map((item) => item.type),
        contains('PAYMENT_SCHEDULE_DUE'),
      );
      expect(
        metrics.recentActivity.map((item) => item.type),
        contains('LOCAL_MONEY_COST'),
      );
    },
  );

  // RA-MO-91 (D59): on a plan kept on the phone the home said every
  // agreement was on the owner, the father's with it.
  test('the owner\'s share leaves out what the family pays', () async {
    SharedPreferences.setMockInitialValues({});
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    const planId = 'local-share-plan';
    Future<void> cost(String id, String payer, String total, String paid) =>
        database.saveCachedItem(
          table: OfflineTables.cachedCosts,
          json: {
            'id': id,
            'planId': planId,
            'weddingPlanId': planId,
            'title': id,
            'totalAmount': total,
            'paidAmount': paid,
            'payer': payer,
            'status': 'PARTIALLY_PAID',
          },
        );
    await cost('hall', 'GROOM', '1000', '400');
    await cost('photo', 'FAMILY', '800', '0');
    await cost('cake', 'SHARED', '300', '100');

    final metrics = await LocalDashboardMetrics.load(
      database: database,
      planId: planId,
      persona: 'GROOM',
    );

    expect(metrics.outstandingTotal, 1600);
    expect(metrics.ownerOutstandingTotal, 800);
  });
}
