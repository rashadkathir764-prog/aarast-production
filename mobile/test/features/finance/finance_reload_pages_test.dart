import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-179: a save re-read the first page of agreements only; every one
// past the first 30 left the list until a full read.

WeddingCost _cost(int index) => WeddingCost(
  id: 'cost-$index',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'اتفاق $index',
  totalAmount: '1000',
  paidAmount: '0',
  remainingAmount: '1000',
  status: 'OPEN',
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

class _Api extends FinanceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final costs = [for (var i = 0; i < 35; i++) _cost(i)];

  int summaryReads = 0;
  int schedulesMade = 0;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    summaryReads += 1;
    return const MoneySummary(planId: 'plan-1', categories: []);
  }

  @override
  Future<PaymentSchedule> createSchedule({
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) async {
    schedulesMade += 1;
    if (note == 'refused') {
      throw const ApiException('الموعد بعد العرس بكثير', statusCode: 400);
    }
    return PaymentSchedule(
      id: 's$schedulesMade',
      costId: cost.id,
      amount: amount,
      dueDate: dueDate,
      status: 'PENDING',
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
    final from = (page - 1) * 30;
    final to = from + 30 > costs.length ? costs.length : from + 30;
    return FinancePage(
      items: costs.sublist(from, to),
      page: page,
      pageSize: 30,
      total: costs.length,
      totalPages: (costs.length / 30).ceil(),
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];

  @override
  Future<void> deleteCost(WeddingCost cost) async {
    costs.removeWhere((item) => item.id == cost.id);
  }
}

void main() {
  test('a save keeps every agreement read before', () async {
    final provider = FinanceProvider(_Api());
    await provider.loadMoney('plan-1');
    await provider.loadMoreCosts();
    expect(provider.costs, hasLength(35));

    expect(await provider.deleteCost(provider.costs.first), isTrue);

    expect(provider.costs, hasLength(34));
  });

  // RA-MO-176: each date re-read the whole money; six dates were some 40
  // requests behind one spinner. They are read back once, and a refused
  // date does not stop the rest.
  test('an agreement\'s dates are read back once', () async {
    final api = _Api();
    final provider = FinanceProvider(api);
    await provider.loadMoney('plan-1');
    final readsBefore = api.summaryReads;

    final saved = await provider.createSchedules(
      cost: provider.costs.first,
      dates: [
        for (var i = 0; i < 6; i++)
          (
            amount: '100',
            dueDate: DateTime(2027, 1, i + 1),
            note: i == 2 ? 'refused' : null,
          ),
      ],
    );

    expect(api.schedulesMade, 6);
    expect(saved, 5);
    expect(api.summaryReads - readsBefore, 1);
  });
}
