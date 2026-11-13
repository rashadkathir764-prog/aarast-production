import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('category details is a complete money destination at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_CategoryFinanceApi()),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BudgetCategoryDetailsScreen(
              weddingPlanId: 'plan-1',
              categoryId: 'category-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الصالة'), findsWidgets);
    // D102: its share (the estimate it falls back to, D109), what was
    // agreed, paid and left; its one agreement, and a second one away.
    expect(find.text('المخصص له'), findsOneWidget);
    expect(find.text('اتفقت'), findsOneWidget);
    expect(find.text('اندفع'), findsOneWidget);
    expect(find.text('باقي'), findsOneWidget);
    expect(find.text('الاتفاق'), findsOneWidget);
    expect(find.text('حجز الصالة'), findsWidgets);
    expect(find.text('اتفاق ثاني'), findsOneWidget);
    expect(find.byKey(const ValueKey('item-pay')), findsOneWidget);
    final overflow = find.byKey(const ValueKey('money-category-overflow'));
    expect(overflow, findsOneWidget);
    expect(
      tester.getCenter(overflow).dx,
      lessThan(tester.getCenter(find.text('الصالة').first).dx),
    );
    expect(tester.getCenter(overflow).dx, lessThan(72));
    expect(tester.takeException(), isNull);

    // x15: an item with an agreement cannot be removed.
    await tester.tap(overflow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-category-remove')));
    await tester.pumpAndSettle();
    expect(find.text('ما تقدر تشيل الصالة'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-remove-delete')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an item over its share offers to grow the budget (w18)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.reset);
    final api = _CategoryFinanceApi(allocated: '300000');

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(api),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BudgetCategoryDetailsScreen(
              weddingPlanId: 'plan-1',
              categoryId: 'category-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-over')), findsOneWidget);
    expect(find.textContaining('عن المحطوط'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-over-grow')));
    await tester.pumpAndSettle();

    // The budget and this item grow by the 200 thousand it went over.
    expect(api.savedTotalBudget, '1200000');
    expect(api.savedAllocations, {'category-1': '500000'});
    expect(tester.takeException(), isNull);
  });
}

class _CategoryFinanceApi extends FinanceApi {
  _CategoryFinanceApi({this.allocated = '1000000'})
    : super(ApiClient(tokenProvider: () async => null));

  final String allocated;
  String? savedTotalBudget;
  Map<String, String?>? savedAllocations;

  @override
  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
    String? expectedBudgetVersion,
  }) async {
    savedTotalBudget = totalBudget;
    savedAllocations = {
      for (final item in categories) item.id ?? item.name: item.allocatedAmount,
    };
    return MoneyBudgetReplaceResult(
      summary: await getMoneySummary(planId),
      categories: const [],
      idMap: const {},
    );
  }

  static final _now = DateTime.utc(2026, 7, 10);

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '1000000',
        allocated: '1000000',
        unallocated: '0',
        confirmedCost: '500000',
        remaining: '500000',
      ),
      costs: const MoneyCostsSummary(
        total: '500000',
        paid: '100000',
        outstanding: '400000',
        count: 1,
      ),
      categories: [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'الصالة',
          allocatedAmount: allocated,
          // D109: no estimate of its own, so its share stands in.
          estimate: allocated,
          estimateFromAllocation: true,
          expectedCost: '500000',
          confirmedCost: '500000',
          paid: '100000',
          outstanding: '400000',
          remainingAllocation: '500000',
          costsCount: 1,
        ),
      ],
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
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
    return FinancePage(
      items: [
        WeddingCost(
          id: 'cost-1',
          weddingPlanId: planId,
          budgetCategoryId: 'category-1',
          title: 'حجز الصالة',
          totalAmount: '500000',
          paidAmount: '100000',
          remainingAmount: '400000',
          status: 'PARTIALLY_PAID',
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
      page: 1,
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
}
