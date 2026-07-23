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
    expect(find.text('المخصص'), findsOneWidget);
    expect(find.text('التكاليف'), findsWidgets);
    expect(find.text('المدفوع'), findsWidgets);
    expect(find.text('الباقي عليك'), findsOneWidget);
    expect(find.text('حجز الصالة'), findsWidgets);
    expect(find.text('إضافة تكلفة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CategoryFinanceApi extends FinanceApi {
  _CategoryFinanceApi() : super(ApiClient(tokenProvider: () async => null));

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
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'الصالة',
          allocatedAmount: '1000000',
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
