// Visual preview for the dashboard-aligned money root: compact budget summary,
// standalone next-payment card, settings access, costs, and recent payments.
//
// Regenerate with:
//   flutter test test/money_overview_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/preview_fonts.dart';

const _planId = 'plan-money-preview';
final _now = DateTime(2026, 7, 4);

void main() {
  setUpAll(loadPreviewAppFonts);

  test('golden fixture follows the canonical money arithmetic', () async {
    final api = _FakeFinanceApi();
    final summary = await api.getMoneySummary(_planId);
    final costs = (await api.getCosts(_planId)).items;
    final payments = (await api.getPlanPayments(_planId)).items;

    final cardsTotal = costs.fold<num>(
      0,
      (sum, cost) => sum + moneyValue(cost.totalAmount),
    );
    final cardsPaid = costs.fold<num>(
      0,
      (sum, cost) => sum + moneyValue(cost.paidAmount),
    );
    final ledgerPaid = payments.fold<num>(
      0,
      (sum, payment) => sum + moneyValue(payment.signedAmount),
    );
    final categoriesAllocated = summary.categories.fold<num>(
      0,
      (sum, category) => sum + moneyValue(category.allocatedAmount),
    );
    final categoriesCost = summary.categories.fold<num>(
      0,
      (sum, category) => sum + moneyValue(category.confirmedCost),
    );

    expect(costs.length, summary.costs.count);
    expect(cardsTotal, moneyValue(summary.costs.total));
    expect(cardsTotal, moneyValue(summary.budget.confirmedCost));
    expect(cardsPaid, moneyValue(summary.costs.paid));
    expect(ledgerPaid, moneyValue(summary.costs.paid));
    expect(cardsTotal - cardsPaid, moneyValue(summary.costs.outstanding));
    expect(categoriesAllocated, moneyValue(summary.budget.allocated));
    expect(categoriesCost, cardsTotal);
    expect(
      moneyValue(summary.budget.total) - cardsTotal,
      moneyValue(summary.budget.remaining),
    );
    expect(
      moneyValue(summary.budget.total) - categoriesAllocated,
      moneyValue(summary.budget.unallocated),
    );
    expect(summary.confirmedRatio, closeTo(.26, .0000001));
  });

  testWidgets('money — overview root (420)', (tester) async {
    tester.view.physicalSize = const Size(420, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_FakeFinanceApi()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MoneyOverviewScreen(weddingPlanId: _planId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Under the budget the bar draws the 26% share; the card does not say it
    // again as a number (the screen card's «لا تكرار», e19c2da). The number
    // stays only over the budget, where the bar is pinned full.
    expect(find.textContaining('26%'), findsNothing);
    // D102: the root opens on «الملخص», which leads with what is on the
    // owner. (The old root's «دفعة متأخرة» card is gone with it.)
    expect(find.text('الملخص'), findsOneWidget);
    expect(find.text('عليك من العرس'), findsOneWidget);
    await expectLater(
      find.byType(MoneyOverviewScreen),
      matchesGoldenFile('goldens/money_overview.png'),
    );
  });

  testWidgets('money — budget category action (420)', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_FakeFinanceApi()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MoneyBudgetScreen(weddingPlanId: _planId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addCategory = find.byKey(const ValueKey('money-budget-add-category'));
    await tester.dragUntilVisible(
      addCategory,
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(addCategory, findsOneWidget);
    await expectLater(
      find.byType(MoneyBudgetScreen),
      matchesGoldenFile('goldens/money_budget_category_action.png'),
    );
  });
}

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '10000000',
        allocated: '3500000',
        unallocated: '6500000',
        confirmedCost: '2600000',
        // The server's wedding figures and whose money paid (D59).
        paid: '1500000',
        paidByOwner: '1500000',
        outstanding: '1100000',
        count: 3,
        remaining: '7400000',
      ),
      costs: const MoneyCostsSummary(
        total: '2600000',
        paid: '1500000',
        paidByOwner: '1500000',
        outstanding: '1100000',
        count: 3,
      ),
      paymentSchedules: const MoneySchedulesSummary(
        totalCount: 1,
        overdueCount: 1,
      ),
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'القاعة',
          allocatedAmount: '2000000',
          confirmedCost: '1500000',
          paid: '1000000',
          outstanding: '500000',
          remainingAllocation: '500000',
          costsCount: 1,
        ),
        MoneyCategorySummary(
          categoryId: 'category-2',
          name: 'التصوير',
          allocatedAmount: '800000',
          confirmedCost: '600000',
          paid: '0',
          outstanding: '600000',
          remainingAllocation: '200000',
          costsCount: 1,
        ),
        MoneyCategorySummary(
          categoryId: 'category-3',
          name: 'الملابس',
          allocatedAmount: '700000',
          confirmedCost: '500000',
          paid: '500000',
          outstanding: '0',
          remainingAllocation: '200000',
          costsCount: 1,
        ),
      ],
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
    items: [
      WeddingCost(
        id: 'cost-1',
        weddingPlanId: _planId,
        budgetCategoryId: 'category-1',
        title: 'حجز صالة الأفراح',
        totalAmount: '1500000',
        paidAmount: '1000000',
        remainingAmount: '500000',
        status: 'PARTIALLY_PAID',
        createdAt: _now,
        updatedAt: _now,
      ),
      WeddingCost(
        id: 'cost-2',
        weddingPlanId: _planId,
        budgetCategoryId: 'category-2',
        title: 'باقة التصوير الذهبية',
        totalAmount: '600000',
        paidAmount: '0',
        remainingAmount: '600000',
        status: 'OPEN',
        providerId: 'provider-1',
        createdAt: _now,
        updatedAt: _now,
      ),
      WeddingCost(
        id: 'cost-3',
        weddingPlanId: _planId,
        budgetCategoryId: 'category-3',
        title: 'بدلة العريس',
        totalAmount: '500000',
        paidAmount: '500000',
        remainingAmount: '0',
        status: 'PAID',
        createdAt: _now,
        updatedAt: _now,
      ),
    ],
    page: page,
    pageSize: limit,
    total: 3,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => FinancePage(
    items: [
      CostPayment(
        id: 'payment-1',
        costId: 'cost-1',
        amount: '1000000',
        paidAt: _now.subtract(const Duration(days: 3)),
        costTitle: 'حجز صالة الأفراح',
      ),
      CostPayment(
        id: 'payment-2',
        costId: 'cost-3',
        amount: '500000',
        paidAt: _now.subtract(const Duration(days: 7)),
        costTitle: 'بدلة العريس',
      ),
    ],
    page: page,
    pageSize: limit,
    total: 2,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async => [
    PaymentSchedule(
      id: 'schedule-1',
      costId: 'cost-1',
      amount: '500000',
      dueDate: _now.add(const Duration(days: 2)),
      status: 'PENDING',
      costTitle: 'حجز صالة الأفراح',
    ),
  ];
}
