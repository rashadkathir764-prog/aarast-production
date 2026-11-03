import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

// F07: a write the server confirmed must never be reported as a failed save
// just because the read that follows it failed.
void main() {
  late _WriteThenReadFinanceApi api;
  late FinanceProvider provider;

  setUp(() async {
    api = _WriteThenReadFinanceApi();
    provider = FinanceProvider(api, permissionsApi: _OwnerSharingApi());
    await provider.loadMoney('plan-1');
  });

  test(
    'confirmed payment followed by a failed refresh reports the save',
    () async {
      api.failReads = true;

      final payment = await provider.recordPayment(
        cost: api.cost,
        amount: '100',
      );

      expect(payment, isNotNull);
      expect(payment!.id, 'payment-1');
      expect(api.createPaymentCalls, 1);
      expect(provider.errorMessage, isNull);
      expect(provider.noticeMessage, FinanceProvider.savedButStaleMessage);
      expect(provider.isSubmitting, isFalse);
    },
  );

  test(
    'reloading after a stale save reads again and never writes again',
    () async {
      api.failReads = true;
      await provider.recordPayment(cost: api.cost, amount: '100');

      api.failReads = false;
      await provider.loadMoney('plan-1');

      expect(api.createPaymentCalls, 1);
      expect(provider.errorMessage, isNull);
    },
  );

  test('a rejected payment write is still reported as a failure', () async {
    api.rejectWrites = true;

    final payment = await provider.recordPayment(cost: api.cost, amount: '100');

    expect(payment, isNull);
    expect(provider.errorMessage, 'المبلغ أكبر من المتبقي.');
    expect(provider.noticeMessage, isNull);
  });

  test('a rejected write is a failed save, not a failed read', () async {
    api.rejectWrites = true;

    await provider.recordPayment(cost: api.cost, amount: '100');

    expect(provider.errorMessage, 'المبلغ أكبر من المتبقي.');
    // Money was read fine: no «old copy» notice follows a failed save.
    expect(provider.loadErrorMessage, isNull);
  });

  test('a confirmed save with a failed refresh says so once', () async {
    api.failReads = true;

    await provider.recordPayment(cost: api.cost, amount: '100');

    expect(provider.noticeMessage, FinanceProvider.savedButStaleMessage);
    expect(provider.loadErrorMessage, isNull);
  });

  test(
    'every money write keeps a confirmed save when the refresh fails',
    () async {
      api.failReads = true;

      final ok = await provider.cancelCost(api.cost);

      expect(ok, isTrue);
      expect(api.cancelCostCalls, 1);
      expect(provider.errorMessage, isNull);
      expect(provider.noticeMessage, FinanceProvider.savedButStaleMessage);
    },
  );

  // J1-08: a read of the money while an agreement is being saved must not
  // turn the server's «saved» into «ما انحفظ», nor leave the button busy.
  test(
    'a money read during the agreement save keeps the save and frees the button',
    () async {
      final gate = Completer<void>();
      api.createCostGate = gate;

      final pending = provider.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'حجز الصالة',
        totalAmount: '1000',
      );
      expect(provider.isSubmitting, isTrue);

      await provider.loadMoney('plan-1');
      gate.complete();
      final created = await pending;

      expect(created, isNotNull);
      expect(created!.id, 'created-cost-1');
      expect(api.createCostCalls, 1);
      expect(provider.errorMessage, isNull);
      expect(provider.isSubmitting, isFalse);
    },
  );

  test('one save holds the button from the agreement to the last date, and a '
      'second save while it runs writes nothing', () async {
    final gate = Completer<void>();
    var busyBetweenWrites = false;

    final first = provider.saveOnce(() async {
      final created = await provider.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'حجز الصالة',
        totalAmount: '1000',
      );
      // The screen's own step between the agreement and its dates.
      await gate.future;
      busyBetweenWrites = provider.isSubmitting;
      return created;
    });
    final second = provider.saveOnce(
      () => provider.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'حجز الصالة',
        totalAmount: '1000',
      ),
    );

    expect(await second, isNull);
    gate.complete();
    expect(await first, isNotNull);
    expect(busyBetweenWrites, isTrue);
    expect(api.createCostCalls, 1);
    expect(provider.isSubmitting, isFalse);
  });
}

class _WriteThenReadFinanceApi extends FinanceApi {
  _WriteThenReadFinanceApi()
    : super(ApiClient(tokenProvider: () async => null));

  bool failReads = false;
  bool rejectWrites = false;
  int createPaymentCalls = 0;
  int cancelCostCalls = 0;
  int createCostCalls = 0;

  /// When set, the agreement's write waits for it (a slow network).
  Completer<void>? createCostGate;

  @override
  Future<WeddingCost> createCost({
    required String planId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? payer,
    String? payerName,
    DateTime? agreementDate,
    String? note,
    bool isPrivate = false,
  }) async {
    createCostCalls += 1;
    final call = createCostCalls;
    await createCostGate?.future;
    return WeddingCost(
      id: 'created-cost-$call',
      weddingPlanId: planId,
      budgetCategoryId: budgetCategoryId,
      title: title,
      totalAmount: totalAmount,
      paidAmount: '0',
      remainingAmount: totalAmount,
      status: 'OPEN',
      createdAt: DateTime.utc(2026, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 11),
    );
  }

  final WeddingCost cost = WeddingCost(
    id: 'cost-1',
    weddingPlanId: 'plan-1',
    budgetCategoryId: 'category-1',
    title: 'حجز الصالة',
    totalAmount: '1000',
    paidAmount: '0',
    remainingAmount: '1000',
    status: 'OPEN',
    createdAt: DateTime.utc(2026, 7, 11),
    updatedAt: DateTime.utc(2026, 7, 11),
  );

  void _readGate() {
    if (failReads) {
      throw const ApiException('تعذر تحميل المال.', statusCode: 500);
    }
  }

  @override
  Future<CostPayment> createPayment({
    required WeddingCost cost,
    required String amount,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    if (rejectWrites) {
      throw const ApiException('المبلغ أكبر من المتبقي.', statusCode: 400);
    }
    createPaymentCalls += 1;
    return CostPayment(
      id: 'payment-$createPaymentCalls',
      costId: cost.id,
      amount: amount,
      paidAt: DateTime.utc(2026, 10, 11),
      weddingPlanId: cost.weddingPlanId,
    );
  }

  @override
  Future<WeddingCost> cancelCost(WeddingCost cost) async {
    cancelCostCalls += 1;
    return cost;
  }

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    _readGate();
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '10000',
        confirmedCost: '1000',
        remaining: '9000',
      ),
      costs: const MoneyCostsSummary(
        total: '1000',
        outstanding: '1000',
        count: 1,
      ),
      categories: const [],
    );
  }

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
    String? payer,
  }) async {
    _readGate();
    return FinancePage(
      items: [cost],
      page: page,
      pageSize: limit,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    _readGate();
    return FinancePage(
      items: const [],
      page: page,
      pageSize: limit,
      total: 0,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async {
    _readGate();
    return const [];
  }

  @override
  Future<WeddingCost> getCost(String costId) async {
    _readGate();
    return cost;
  }

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async {
    _readGate();
    return const [];
  }

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async {
    _readGate();
    return const [];
  }
}

class _OwnerSharingApi extends SharingApi {
  _OwnerSharingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async =>
      PlanAccessPermissions.owner(weddingPlanId: planId);
}
