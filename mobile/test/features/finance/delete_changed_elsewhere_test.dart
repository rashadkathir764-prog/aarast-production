import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-344 (the rest): an agreement or a payment date deleted from an
// older read is refused by the server (409 CHANGED_ELSEWHERE). The row stays,
// is read again, and the person is told in words that say a delete, not an
// edit.

const _plan = 'plan-1';

final _cost = WeddingCost(
  id: 'cost-1',
  weddingPlanId: _plan,
  budgetCategoryId: 'category-1',
  title: 'حجز الصالة',
  totalAmount: '1000',
  paidAmount: '0',
  remainingAmount: '1000',
  status: 'OPEN',
  createdAt: DateTime.utc(2026, 7, 11),
  updatedAt: DateTime.utc(2026, 7, 11),
);

final _schedule = PaymentSchedule(
  id: 'schedule-1',
  costId: 'cost-1',
  amount: '500',
  dueDate: DateTime.utc(2027, 1, 10),
  status: 'PENDING',
  weddingPlanId: _plan,
);

const _conflict = ApiException(
  'التكلفة تغيّرت من جهاز ثاني قبل الحذف، فما انحذفت.',
  statusCode: 409,
  serverCode: 'CHANGED_ELSEWHERE',
);

void main() {
  Future<(FinanceProvider, _Api)> provider() async {
    final api = _Api();
    final provider = FinanceProvider(
      api,
      permissionsApi: _Sharing(
        const PlanAccessPermissions(
          weddingPlanId: _plan,
          isOwner: true,
          canViewMoney: true,
          canManageMoney: true,
        ),
      ),
    );
    await provider.loadMoney(_plan);
    return (provider, api);
  }

  test('a refused cost delete keeps the cost, reads again, and says it was '
      'the delete', () async {
    final (money, api) = await provider();
    final reads = api.summaryCalls;

    final deleted = await money.deleteCost(_cost);

    expect(deleted, isFalse);
    expect(api.summaryCalls, greaterThan(reads), reason: 'read again');
    expect(money.errorMessage, contains('سبق الحذف'));
    expect(money.errorMessage, contains('فما انحذف'));
    expect(money.errorMessage, isNot(contains('تعديلك')));
  });

  test('a refused payment date delete says the same', () async {
    final (money, _) = await provider();

    final deleted = await money.deleteSchedule(
      schedule: _schedule,
      cost: _cost,
    );

    expect(deleted, isFalse);
    expect(money.errorMessage, contains('سبق الحذف'));
  });
}

class _Sharing extends SharingApi {
  _Sharing(this.permissions)
    : super(ApiClient(tokenProvider: () async => null));

  final PlanAccessPermissions permissions;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async =>
      permissions;
}

class _Api extends FinanceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  int summaryCalls = 0;

  @override
  Future<void> deleteCost(WeddingCost cost) async => throw _conflict;

  @override
  Future<void> deleteSchedule(PaymentSchedule schedule) async =>
      throw _conflict;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    summaryCalls += 1;
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
  }) async => FinancePage(
    items: [_cost],
    page: page,
    pageSize: limit,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => FinancePage(
    items: const [],
    page: page,
    pageSize: limit,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => const [];

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => const [];
}
