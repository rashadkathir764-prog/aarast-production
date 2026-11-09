import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// «البنود»'s writes (D105, D107, D109) through the provider the screens
// use, on a plan kept on the phone: what each one does to the item's
// expected cost and to what was paid.

const _planId = 'guest-plan-items-actions';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

Future<FinanceProvider> _provider({String? budget = '1000000'}) async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: _NoNetwork(),
  );
  await offline.initialize();
  await FinanceLocalDataSource(offline).saveBudget(
    planId: _planId,
    totalBudget: budget,
    currency: 'YER',
    categories: const [
      {
        'id': 'c-photo',
        'weddingPlanId': _planId,
        'name': 'التصوير',
        'allocatedAmount': '400000',
      },
    ],
  );
  final provider = FinanceProvider(
    FinanceApi(
      _NoNetwork(),
      offline: offline,
      localPlanContextLoader: (_) async =>
          const LocalFinancePlanContext(currency: 'YER', persona: 'GROOM'),
    ),
  );
  await provider.loadMoney(_planId);
  return provider;
}

num _expected(FinanceProvider provider) => moneyValue(
  provider.summary.categories
      .singleWhere((item) => item.categoryId == 'c-photo')
      .expectedCost,
);

void main() {
  group('the item estimate (D109)', () {
    test('an item with no estimate of its own reads its share', () async {
      final provider = await _provider();
      final item = provider.summary.categories.single;
      expect(item.estimateFromAllocation, isTrue);
      expect(moneyValue(item.estimate), 400000);
      expect(_expected(provider), 400000);
    });

    test(
      'its own estimate replaces the share, and may pass the budget',
      () async {
        final provider = await _provider();
        final ok = await provider.setItemEstimate(
          category: provider.categoryById('c-photo')!,
          estimatedAmount: '1500000',
        );
        expect(ok, isTrue, reason: provider.errorMessage);
        final item = provider.summary.categories.single;
        expect(item.estimateFromAllocation, isFalse);
        expect(moneyValue(item.estimatedAmount), 1500000);
        expect(_expected(provider), 1500000);
        // Over the 1,000,000 budget by 500,000: said, not refused.
        expect(moneyValue(provider.summary.expected?.budgetLeft), -500000);
        // The share is not touched.
        expect(
          moneyValue(provider.categoryById('c-photo')!.allocatedAmount),
          400000,
        );
      },
    );

    test('zero is an answer; clearing it goes back to the share', () async {
      final provider = await _provider();
      final item = provider.categoryById('c-photo')!;
      expect(
        await provider.setItemEstimate(category: item, estimatedAmount: '0'),
        isTrue,
      );
      expect(_expected(provider), 0);
      expect(
        await provider.setItemEstimate(
          category: provider.categoryById('c-photo')!,
          estimatedAmount: null,
        ),
        isTrue,
      );
      expect(provider.summary.categories.single.estimateFromAllocation, isTrue);
      expect(_expected(provider), 400000);
    });

    test('a budget saved after keeps the estimate', () async {
      final provider = await _provider();
      await provider.setItemEstimate(
        category: provider.categoryById('c-photo')!,
        estimatedAmount: '500000',
      );
      expect(
        await provider.setTotalBudget(planId: _planId, totalBudget: '2000000'),
        isTrue,
      );
      await provider.loadMoney(_planId);
      expect(
        moneyValue(provider.summary.categories.single.estimatedAmount),
        500000,
      );
      expect(_expected(provider), 500000);
    });
  });

  group('an agreement and an expense (D105, D107)', () {
    test('an agreement for part of the estimate adds the rest of it', () async {
      final provider = await _provider();
      await provider.setItemEstimate(
        category: provider.categoryById('c-photo')!,
        estimatedAmount: '500000',
      );
      final cost = await provider.createCost(
        planId: _planId,
        budgetCategoryId: 'c-photo',
        title: 'المصور',
        totalAmount: '350000',
        partyName: 'المصور',
        estimateCover: 'PART',
        estimatePart: '300000',
      );
      expect(cost, isNotNull, reason: provider.errorMessage);
      // 350,000 + (500,000 − 300,000).
      expect(_expected(provider), 550000);

      // Now for the whole item: the agreement replaces the estimate.
      final saved = await provider.updateCost(
        cost: provider.costs.single,
        budgetCategoryId: 'c-photo',
        title: 'المصور',
        totalAmount: '350000',
        partyName: 'المصور',
        estimateCover: 'WHOLE',
      );
      expect(saved, isTrue, reason: provider.errorMessage);
      expect(_expected(provider), 350000);
    });

    test('an expense is paid in full the day it is recorded', () async {
      final provider = await _provider();
      final cost = await provider.createCost(
        planId: _planId,
        budgetCategoryId: 'c-photo',
        title: 'ألبوم',
        totalAmount: '50000',
        partyName: 'المطبعة',
        isExpense: true,
        estimateCover: 'PART',
      );
      expect(cost, isNotNull, reason: provider.errorMessage);
      expect(cost!.entryKind, 'EXPENSE');
      final saved = provider.costs.single;
      expect(moneyValue(saved.paidAmount), 50000);
      expect(moneyValue(saved.remainingAmount), 0);
      expect(moneyValue(provider.summary.costs.paid), 50000);
      // It covers part of the 400,000 share: 50,000 + 400,000 − 50,000.
      expect(_expected(provider), 400000);
    });
  });
}
