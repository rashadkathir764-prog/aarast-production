import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/widgets/funding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The bride's money (bride_profile/out c01, c02, c12): the groom's money in
// her rose and her feminine address, from the plan's one profile.

Future<void> _pump(
  WidgetTester tester,
  JourneyProfile profile, {
  MoneyFundingSummary? funding,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(_Api(funding: funding)),
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: profile,
          child: const MoneyOverviewScreen(
            weddingPlanId: 'plan-1',
            personaCode: 'BRIDE',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _tabFill(WidgetTester tester, int index) =>
    (tester
                .widget<AnimatedContainer>(
                  find.byKey(ValueKey('journey-tab-$index')),
                )
                .decoration!
            as BoxDecoration)
        .color;

void main() {
  testWidgets('c01: her summary speaks to her, on a rose tab', (tester) async {
    await _pump(tester, JourneyProfile.bride);

    expect(_tabFill(tester, 0), AarastV3Color.rose);
    expect(find.textContaining('اتفقتِ على '), findsOneWidget);
    expect(find.textContaining('، دفعتِ منها '), findsOneWidget);
    expect(find.textContaining('اتفقت على '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('c01: the four-part bar names paid, in hand, promised, short', (
    tester,
  ) async {
    await _pump(
      tester,
      JourneyProfile.bride,
      funding: const MoneyFundingSummary(
        received: '700',
        pledged: '400',
        availableCash: '200',
        shortfall: '400',
        sourcesCount: 2,
      ),
    );

    expect(find.byKey(const ValueKey('money-funding-bar')), findsOneWidget);
    for (final label in ['دفعتِ', 'معك', 'موعود', 'ناقصك']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('c01: no bar before any funding source', (tester) async {
    await _pump(
      tester,
      JourneyProfile.bride,
      funding: const MoneyFundingSummary(),
    );

    expect(find.byKey(const ValueKey('money-funding-bar')), findsNothing);
  });

  testWidgets('c02: her items say what she paid and invite her to add', (
    tester,
  ) async {
    await _pump(tester, JourneyProfile.bride);
    await tester.tap(find.text('البنود'));
    await tester.pumpAndSettle();

    expect(find.textContaining('دفعتِ '), findsOneWidget);
    expect(find.text('أضيفي بند'), findsOneWidget);
    expect(find.text('أضف بند'), findsNothing);
  });

  testWidgets('the groom keeps his teal and his words', (tester) async {
    await _pump(tester, JourneyProfile.groom);

    expect(_tabFill(tester, 0), AarastV3Color.primary);
    expect(find.textContaining('اتفقت على '), findsOneWidget);
  });

  test('c12: her gifts are «هدايا ونقوط», his are «رفد ونقوط»', () {
    expect(fundingKindChoice('GIFT', JourneyProfile.bride), 'هدايا ونقوط');
    expect(fundingKindChoice('GIFT', JourneyProfile.groom), 'رفد ونقوط');
  });
}

class _Api extends FinanceApi {
  _Api({this.funding}) : super(ApiClient(tokenProvider: () async => null));

  final MoneyFundingSummary? funding;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => MoneySummary(
    planId: planId,
    currency: 'YER',
    costs: const MoneyCostsSummary(
      total: '2000',
      paid: '500',
      // D59: she paid it from her own money.
      paidByOwner: '500',
      outstanding: '1500',
      count: 1,
    ),
    funding: funding,
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
  }) async => FinancePage(
    items: [
      WeddingCost.fromJson({
        'id': 'dress',
        'weddingPlanId': planId,
        'budgetCategoryId': 'category-1',
        'title': 'فستان الزفة',
        'totalAmount': '2000',
        'paidAmount': '500',
        'remainingAmount': '1500',
        'status': 'OPEN',
      }),
    ],
    page: 1,
    pageSize: 30,
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
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];
}
