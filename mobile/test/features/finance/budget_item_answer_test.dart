// D72 on a money item's own screen (2026-11-26 review): an essential item
// with nothing agreed on it offers the home's two answers, «لاحقًا» and
// «لا أحتاجه»; once answered it says what the answer did and takes it back.

import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/home_fixtures.dart';

const _item = 'category-photo';

void main() {
  Future<_AnswerFinanceApi> pump(
    WidgetTester tester, {
    bool essential = true,
    String? suggestion,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1100);
    addTearDown(tester.view.reset);
    final api = _AnswerFinanceApi(suggestion: suggestion);
    final plans = _Plans(
      homeSummary(
        date: homeWedding,
        today: DateTime(2026, 10, 20),
        essentials: [
          {
            'key': 'PHOTO',
            'status': 'MISSING',
            'budgetCategoryId': essential ? _item : 'another-item',
          },
        ],
      ),
    );
    final dashboard = DashboardSummaryProvider(weddingPlansApi: plans);
    await dashboard.loadDashboard(homePlanId);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FinanceApi>.value(value: api),
          ChangeNotifierProvider<FinanceProvider>(
            create: (_) => FinanceProvider(api),
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BudgetCategoryDetailsScreen(
              weddingPlanId: homePlanId,
              categoryId: _item,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('an essential item with no agreement offers «لاحقًا» and «لا '
      'أحتاجه»; a second tap on its way sends nothing', (tester) async {
    final api = await pump(tester);
    api.hold = Completer<void>();

    expect(find.text('هل تحتاج هذا البند؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('item-essential-later')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('item-essential-later')));
    await tester.tap(find.byKey(const ValueKey('item-essential-not-needed')));
    await tester.pump();
    expect(api.choices, ['LATER']);

    api.hold!.complete();
    await tester.pump();
    await tester.pump();
    // Said on the item's own screen: «هنا» was the home's word for itself.
    expect(find.text('ستقترحه الرئيسية مرة أخرى بعد أسبوع.'), findsOneWidget);
    expect(api.choices, ['LATER']);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('«لا أحتاجه» answered: what it did, and the way back', (
    tester,
  ) async {
    final api = await pump(tester, suggestion: 'NOT_NEEDED');

    expect(find.byKey(const ValueKey('item-essential-answers')), findsNothing);
    expect(
      // No «قلتَ…»: the partner with the money right reads the same line,
      // and she did not say it.
      find.text('سُجّل أن الخطة لا تحتاج هذا البند، فلا تقترحه الرئيسية.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('item-essential-take-back')));
    await tester.pump();
    await tester.pump();
    expect(api.choices, [null]);
    expect(find.text('عاد البند إلى اقتراحات الرئيسية.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('an item that is not one of the essentials is not asked', (
    tester,
  ) async {
    await pump(tester, essential: false);
    expect(find.byKey(const ValueKey('item-essential-answers')), findsNothing);
    expect(find.byKey(const ValueKey('item-essential-answered')), findsNothing);
    expect(find.text('لاحقًا'), findsNothing);
  });
}

class _Plans extends WeddingPlansApi {
  _Plans(this.summary) : super(ApiClient(tokenProvider: () async => null));

  final DashboardSummary summary;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async => summary;

  @override
  Future<DashboardSummary?> cachedDashboardSummary(String planId) async => null;
}

class _AnswerFinanceApi extends FinanceApi {
  _AnswerFinanceApi({this.suggestion})
    : super(ApiClient(tokenProvider: () async => null));

  String? suggestion;
  final choices = <String?>[];

  /// Holds the answer on its way until completed.
  Completer<void>? hold;

  @override
  Future<void> setBudgetItemSuggestion({
    required String weddingPlanId,
    required String categoryId,
    required String? choice,
  }) async {
    choices.add(choice);
    await hold?.future;
    suggestion = choice;
  }

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '1000000',
        allocated: '300000',
        unallocated: '700000',
        confirmedCost: '0',
        remaining: '1000000',
      ),
      costs: const MoneyCostsSummary(
        total: '0',
        paid: '0',
        outstanding: '0',
        count: 0,
      ),
      categories: [
        MoneyCategorySummary(
          categoryId: _item,
          name: 'التصوير',
          allocatedAmount: '300000',
          estimate: '300000',
          estimateFromAllocation: true,
          expectedCost: '300000',
          remainingAllocation: '300000',
          suggestion: suggestion,
          suggestionHidden: suggestion != null,
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
  }) async => FinancePage(
    items: const [],
    page: 1,
    pageSize: limit,
    total: 0,
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
}
