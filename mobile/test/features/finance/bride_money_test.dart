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
  MoneyCoverage? coverage,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) =>
          FinanceProvider(_Api(funding: funding, coverage: coverage)),
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
  // D102: the summary leads with what is on her, in her own form.
  testWidgets('c01: her summary speaks to her, on a rose tab', (tester) async {
    await _pump(
      tester,
      JourneyProfile.bride,
      funding: const MoneyFundingSummary(),
    );

    expect(_tabFill(tester, 0), AarastV3Color.rose);
    expect(find.text('عليكِ من العرس'), findsOneWidget);
    expect(find.text('عليك من العرس'), findsNothing);
    expect(
      find.byKey(const ValueKey('money-cover-unknown')),
      findsOneWidget,
      reason: 'before a source, nothing claims to cover it',
    );
    expect(find.textContaining('ما سجلتِ من وين فلوسك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // D103: short is said with the day it falls and what it is, from the
  // server's verdict; what is in hand follows.
  testWidgets('c01: short, with the day and what is in hand', (tester) async {
    await _pump(
      tester,
      JourneyProfile.bride,
      funding: const MoneyFundingSummary(availableCash: '200', sourcesCount: 2),
      coverage: MoneyCoverage(
        verdict: MoneyCoverageVerdict.short,
        cash: '200',
        total: '1500',
        withPledges: MoneyCoverageRun(
          firstShort: MoneyCoverageShort(
            amount: '400',
            title: 'فستان الزفة',
            id: 's1',
            date: DateTime(2026, 12, 1),
          ),
          deepest: MoneyCoverageShort(
            amount: '1300',
            title: 'فستان الزفة',
            id: 's1',
            date: DateTime(2026, 12, 1),
          ),
          end: '-1300',
        ),
      ),
    );

    final cover = find.byKey(const ValueKey('money-cover'));
    expect(
      find.descendant(of: cover, matching: find.textContaining('ينقصك')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cover, matching: find.textContaining('فستان الزفة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cover, matching: find.textContaining('معك ')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('money-how-counted')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // D103: covered is one sentence with what is in hand and until when.
  testWidgets('c01: covered, in one sentence with until when', (tester) async {
    await _pump(
      tester,
      JourneyProfile.bride,
      funding: const MoneyFundingSummary(
        availableCash: '2500',
        sourcesCount: 2,
      ),
      coverage: MoneyCoverage(
        verdict: MoneyCoverageVerdict.covered,
        cash: '2500',
        total: '1500',
        lastDate: DateTime(2026, 12, 1),
        withoutPledges: const MoneyCoverageRun(end: '1000'),
        withPledges: const MoneyCoverageRun(end: '1000'),
      ),
    );

    final cover = find.byKey(const ValueKey('money-cover'));
    expect(
      find.descendant(of: cover, matching: find.textContaining('يكفي دفعاتك')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cover, matching: find.textContaining('لين ')),
      findsOneWidget,
    );
    expect(find.textContaining('ينقصك'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('c02: her items speak to her and invite her to add', (
    tester,
  ) async {
    await _pump(tester, JourneyProfile.bride);
    await tester.tap(find.text('البنود'));
    await tester.pumpAndSettle();

    expect(find.text('اتفقتِ عليها'), findsOneWidget);
    expect(find.text('اتفقت عليها'), findsNothing);
    expect(find.text('اتفقتِ 1'), findsOneWidget);
    // What is left on her dress, from its agreement.
    final row = find.byKey(const ValueKey('money-item-category-1'));
    expect(
      find.descendant(of: row, matching: find.textContaining('فستان الزفة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('1,500')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('أضيفي بند'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('أضيفي بند'), findsOneWidget);
    expect(find.text('أضف بند'), findsNothing);
  });

  testWidgets('the groom keeps his teal and his words', (tester) async {
    await _pump(
      tester,
      JourneyProfile.groom,
      funding: const MoneyFundingSummary(),
    );

    expect(_tabFill(tester, 0), AarastV3Color.primary);
    expect(find.text('عليك من العرس'), findsOneWidget);
    expect(find.textContaining('ما سجلت من وين فلوسك'), findsOneWidget);
  });

  test('c12: her gifts are «هدايا ونقوط», his are «رفد ونقوط»', () {
    expect(fundingKindChoice('GIFT', JourneyProfile.bride), 'هدايا ونقوط');
    expect(fundingKindChoice('GIFT', JourneyProfile.groom), 'رفد ونقوط');
  });
}

class _Api extends FinanceApi {
  _Api({this.funding, this.coverage})
    : super(ApiClient(tokenProvider: () async => null));

  final MoneyFundingSummary? funding;
  final MoneyCoverage? coverage;

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
    // D102: what is left on her, and the coverage the server worked out.
    outstanding: const MoneyOutstanding(total: '1500', owner: '1500'),
    coverage: coverage,
    // Her one item, as the server sums its agreement.
    categories: const [
      MoneyCategorySummary(
        categoryId: 'category-1',
        name: 'الفستان',
        confirmedCost: '2000',
        paid: '500',
        outstanding: '1500',
        costsCount: 1,
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
