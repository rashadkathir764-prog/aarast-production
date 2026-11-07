import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// V1 checklist 4.10: a cost the owner or partner keeps to themselves.

void main() {
  test('a private cost and the right to record one read from the server', () {
    expect(
      WeddingCost.fromJson({'id': 'c', 'isPrivate': true}).isPrivate,
      isTrue,
    );
    expect(WeddingCost.fromJson({'id': 'c'}).isPrivate, isFalse);
    expect(
      MoneyPermissions.fromJson({
        'canManageMoney': true,
        'canRecordPrivateCost': true,
      }).canRecordPrivateCost,
      isTrue,
    );
    expect(
      MoneyPermissions.fromJson({'canManageMoney': true}).canRecordPrivateCost,
      isFalse,
    );
  });

  testWidgets(
    'a private cost shows a lock in «البنود», a shared one does not',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(_TwoCostsApi()),
          child: const MaterialApp(
            home: MoneyOverviewScreen(weddingPlanId: 'plan-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('البنود'));
      await tester.pumpAndSettle();

      final private = find.byKey(const ValueKey('money-item-private'));
      final shared = find.byKey(const ValueKey('money-item-shared'));
      expect(private, findsOneWidget);
      expect(shared, findsOneWidget);
      expect(
        find.descendant(
          of: private,
          matching: find.byKey(const ValueKey('cost-private-lock')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: shared,
          matching: find.byKey(const ValueKey('cost-private-lock')),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // An item whose agreements were all cancelled is waiting again: it was
  // gone from «البنود», reachable only through the folded cancelled ones.
  testWidgets('an item whose agreements were cancelled is back as «ما انحجز»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(_TwoCostsApi(allCancelled: true)),
        child: const MaterialApp(
          home: MoneyOverviewScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('البنود'));
    await tester.pumpAndSettle();

    final item = find.byKey(const ValueKey('money-item-category-category-1'));
    expect(item, findsOneWidget);
    expect(
      find.descendant(of: item, matching: find.text('ما انحجز')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // The old «كل التكاليف» page is gone: the next agreements load into
  // «البنود» itself.
  testWidgets('«باقي البنود» loads the next agreements into the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _TwoCostsApi(paged: true);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(api),
        child: const MaterialApp(
          home: MoneyOverviewScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('البنود'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('money-item-private')), findsOneWidget);
    expect(find.byKey(const ValueKey('money-item-shared')), findsNothing);
    final more = find.byKey(const ValueKey('money-items-more'));
    expect(more, findsOneWidget);

    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(api.pages, [1, 2]);
    expect(find.byKey(const ValueKey('money-item-private')), findsOneWidget);
    expect(find.byKey(const ValueKey('money-item-shared')), findsOneWidget);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TwoCostsApi extends FinanceApi {
  _TwoCostsApi({this.paged = false, this.allCancelled = false})
    : super(ApiClient(tokenProvider: () async => null));

  /// Both agreements of the item cancelled.
  final bool allCancelled;

  /// One agreement a page, so the second waits for «باقي البنود».
  final bool paged;
  final pages = <int>[];

  WeddingCost _cost(String id, String title, {required bool isPrivate}) =>
      WeddingCost.fromJson({
        'id': id,
        'weddingPlanId': 'plan-1',
        'budgetCategoryId': 'category-1',
        'title': title,
        'totalAmount': '1000',
        'paidAmount': '0',
        'remainingAmount': '1000',
        'status': allCancelled ? 'CANCELLED' : 'OPEN',
        'isPrivate': isPrivate,
      });

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => MoneySummary(
    planId: planId,
    currency: 'YER',
    costs: const MoneyCostsSummary(
      total: '2000',
      outstanding: '2000',
      count: 2,
    ),
    categories: const [
      MoneyCategorySummary(
        categoryId: 'category-1',
        name: 'الفستان',
        allocatedAmount: null,
        confirmedCost: '0',
        paid: '0',
        outstanding: '0',
        remainingAllocation: '0',
        costsCount: 0,
      ),
    ],
  );

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    BudgetCategory(id: 'category-1', weddingPlanId: planId, name: 'الفستان'),
  ];

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
    pages.add(page);
    final all = [
      _cost('private', 'فستان', isPrivate: true),
      _cost('shared', 'القاعة', isPrivate: false),
    ];
    final items = paged ? [all[page - 1]] : all;
    return FinancePage(
      items: items,
      page: page,
      pageSize: paged ? 1 : 30,
      total: all.length,
      totalPages: paged ? 2 : 1,
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => FinancePage(
    items: const [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];
}
