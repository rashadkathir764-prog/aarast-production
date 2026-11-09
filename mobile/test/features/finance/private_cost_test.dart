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

      // An item all of whose agreements are the reader's own.
      final private = find.byKey(const ValueKey('money-item-category-1'));
      final shared = find.byKey(const ValueKey('money-item-category-2'));
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
  testWidgets(
    'an item whose agreements were cancelled is back among the open',
    (tester) async {
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

      expect(
        find.byKey(const ValueKey('money-item-category-category-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('money-item-category-category-2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('money-item-category-1')), findsNothing);
      expect(find.text('ما اتفقت عليها بعد'), findsOneWidget);
      // The cancelled agreements stay reachable, folded.
      expect(find.text('الملغية · 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // RA-MO-38: every money screen reads the plan's agreements whole (the
  // items, an item's page, the payment picker, the mahr), so the pages after
  // the first arrive with the money, not on a tap.
  testWidgets('the next agreements arrive with the money, without a tap', (
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

    expect(api.pages, [1, 2]);
    // Each item names who it is with: both pages are in.
    expect(_whoOf(tester, 'category-1'), contains('فستان المحل'));
    expect(_whoOf(tester, 'category-2'), contains('قاعة الريان'));
    expect(find.byKey(const ValueKey('money-items-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // The old «كل التكاليف» page is gone: when a later page could not be read
  // with the money, «باقي الاتفاقات» reads it into «البنود» itself.
  testWidgets('«باقي الاتفاقات» loads the next agreements into the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _TwoCostsApi(paged: true, failSecondPageOnce: true);

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

    // Both items are there (the summary has them); the second does not
    // know who it is with yet.
    expect(_whoOf(tester, 'category-1'), contains('فستان المحل'));
    expect(_whoOf(tester, 'category-2'), isNot(contains('قاعة الريان')));
    final more = find.byKey(const ValueKey('money-items-more'));
    expect(more, findsOneWidget);

    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(api.pages, [1, 2, 2]);
    expect(_whoOf(tester, 'category-2'), contains('قاعة الريان'));
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// What an item's row says, read as one line.
String _whoOf(WidgetTester tester, String item) => tester
    .widgetList<RichText>(
      find.descendant(
        of: find.byKey(ValueKey('money-item-$item')),
        matching: find.byType(RichText),
      ),
    )
    .map((text) => text.text.toPlainText())
    .join(' ');

class _TwoCostsApi extends FinanceApi {
  _TwoCostsApi({
    this.paged = false,
    this.allCancelled = false,
    this.failSecondPageOnce = false,
  }) : super(ApiClient(tokenProvider: () async => null));

  /// The second page cannot be read the first time it is asked for.
  bool failSecondPageOnce;

  /// Both agreements of the item cancelled.
  final bool allCancelled;

  /// One agreement a page, so the second waits for «باقي البنود».
  final bool paged;
  final pages = <int>[];

  WeddingCost _cost(
    String id,
    String item,
    String title, {
    required bool isPrivate,
  }) => WeddingCost.fromJson({
    'id': id,
    'weddingPlanId': 'plan-1',
    'budgetCategoryId': item,
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
    // Each item with its one agreement, as the server sums them; a
    // cancelled agreement holds nothing.
    categories: [
      for (final (id, name) in const [
        ('category-1', 'الفستان'),
        ('category-2', 'القاعة'),
      ])
        MoneyCategorySummary(
          categoryId: id,
          name: name,
          confirmedCost: allCancelled ? '0' : '1000',
          outstanding: allCancelled ? '0' : '1000',
          costsCount: allCancelled ? 0 : 1,
        ),
    ],
  );

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    BudgetCategory(id: 'category-1', weddingPlanId: planId, name: 'الفستان'),
    BudgetCategory(id: 'category-2', weddingPlanId: planId, name: 'القاعة'),
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
    if (page == 2 && failSecondPageOnce) {
      failSecondPageOnce = false;
      throw const ApiException('الخادم تأخر في الرد.', isNetworkFailure: true);
    }
    final all = [
      _cost('private', 'category-1', 'فستان المحل', isPrivate: true),
      _cost('shared', 'category-2', 'قاعة الريان', isPrivate: false),
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
