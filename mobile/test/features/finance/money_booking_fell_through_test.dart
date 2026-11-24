import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RA-BE-138 (Q-34 (ب)): the provider declined (or cancelled) the booking of
// an offer the owner accepted. The agreement it made stays in «اتفقت على»,
// and «يحتاج انتباهك» names it with «احذف البند؟», opening the agreement
// where it is deleted or cancelled.

Map<String, dynamic> _summaryJson() => {
  'planId': 'plan-1',
  'currency': 'YER',
  'budget': {'total': '3000000', 'remaining': '2600000'},
  'costs': {
    'total': '400000',
    'paid': '0',
    'outstanding': '400000',
    'count': 1,
  },
  'categories': [
    {
      'categoryId': 'photo',
      'name': 'التصوير',
      'allocatedAmount': '500000',
      'confirmedCost': '400000',
    },
  ],
  'bookingFellThrough': [
    {
      'weddingCostId': 'cost-noor',
      'budgetCategoryId': 'photo',
      'title': 'استوديو النور',
      'amount': '400000',
    },
  ],
};

class _Api extends FinanceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async =>
      MoneySummary.fromJson(_summaryJson());

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    BudgetCategory(id: 'photo', weddingPlanId: planId, name: 'التصوير'),
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
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

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
}

class _FundingApi extends FundingApi {
  _FundingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async =>
      const [];
}

void main() {
  test('the server names the agreements whose booking fell through', () {
    final summary = MoneySummary.fromJson(_summaryJson());
    expect(summary.bookingFellThrough, hasLength(1));
    final item = summary.bookingFellThrough.single;
    expect(item.weddingCostId, 'cost-noor');
    expect(item.title, 'استوديو النور');
    expect(item.amount, '400000');
    // An older server says nothing of it.
    expect(
      MoneySummary.fromJson({'planId': 'plan-1'}).bookingFellThrough,
      isEmpty,
    );
  });

  for (final (label, profile, ask) in [
    ('groom', JourneyProfile.groom, 'احذف البند؟'),
    ('bride', JourneyProfile.bride, 'احذفي البند؟'),
  ]) {
    testWidgets('«يحتاج انتباهك» names the kept item and asks to delete it '
        '($label)', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>(
              create: (_) => FinanceProvider(_Api()),
            ),
            ChangeNotifierProvider<FundingProvider>(
              create: (_) => FundingProvider(_FundingApi()),
            ),
          ],
          child: MaterialApp(
            home: JourneyProfileScope(
              profile: profile,
              child: const MoneyOverviewScreen(
                weddingPlanId: 'plan-1',
                personaCode: 'GROOM',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(
        const ValueKey('money-attention-fell-through-cost-noor'),
      );
      await tester.scrollUntilVisible(row, 200);
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text('انلغى حجز «استوديو النور» وبنده باقي'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining(ask)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('400,000')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
