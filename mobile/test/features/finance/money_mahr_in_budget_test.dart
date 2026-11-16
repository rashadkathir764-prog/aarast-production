import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/money_share_text.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D114 on the money tab, with the owner's own plan (2026-11-14): budget 7
// million, mahr 2 million of which 500 thousand handed over, nothing else
// agreed. In both modes he agreed 2 million, paid 500 thousand and owes 1.5
// million; the budget has 7 million left with the mahr on its own, 5 with
// the mahr inside it. The server's figures for each mode, as it sends them.

MoneySummary ownerPlan({required bool inside}) {
  final dueDay = DateTime.now().add(const Duration(days: 30));
  return MoneySummary(
    planId: 'plan-1',
    currency: 'YER',
    budget: MoneyBudgetSummary(
      total: '7000000',
      includesMahr: inside,
      unallocated: inside ? '5000000' : '7000000',
      confirmedCost: inside ? '2000000' : '0',
      paid: inside ? '500000' : '0',
      paidByOwner: inside ? '500000' : '0',
      outstanding: inside ? '1500000' : '0',
      // The mahr is never an agreement with a provider.
      count: 0,
      remaining: inside ? '5000000' : '7000000',
    ),
    costs: const MoneyCostsSummary(
      total: '2000000',
      paid: '500000',
      paidByOwner: '500000',
      outstanding: '1500000',
      count: 1,
    ),
    categories: const [
      MoneyCategorySummary(
        categoryId: 'mahr',
        name: 'المهر',
        confirmedCost: '2000000',
        paid: '500000',
        outstanding: '1500000',
        isMahr: true,
        costsCount: 1,
      ),
      MoneyCategorySummary(categoryId: 'hall', name: 'القاعة'),
    ],
    mahr: const MoneyMahrSummary(
      side: MahrSide.pays,
      total: '2000000',
      settled: '500000',
      remaining: '1500000',
    ),
    expected: MoneyExpected(
      wedding: const MoneyExpectedTotals(unknownCount: 1),
      mahr: const MoneyExpectedTotals(agreed: '2000000', expected: '2000000'),
      total: '2000000',
      budgetLeft: inside ? '5000000' : '7000000',
    ),
    outstanding: const MoneyOutstanding(
      total: '1500000',
      owner: '1500000',
      ownerMahr: '1500000',
    ),
    obligations: [
      MoneyObligation(
        kind: MoneyObligationKind.due,
        id: 'mahr-rest',
        weddingCostId: 'mahr-cost',
        title: 'المهر',
        amount: '1500000',
        scheduledAmount: '1500000',
        dueDate: DateTime(dueDay.year, dueDay.month, dueDay.day),
        mahr: true,
      ),
    ],
    permissions: const MoneyPermissions(
      canViewMoney: true,
      canManageMoney: true,
    ),
    funding: const MoneyFundingSummary(),
  );
}

class _Api extends FinanceApi {
  _Api(this.inside) : super(ApiClient(tokenProvider: () async => null));

  final bool inside;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async =>
      ownerPlan(inside: inside);

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    BudgetCategory.fromJson({
      'id': 'mahr',
      'weddingPlanId': planId,
      'name': 'المهر',
      'kind': 'MAHR',
    }),
    BudgetCategory(id: 'hall', weddingPlanId: planId, name: 'القاعة'),
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
    final items = [
      WeddingCost.fromJson({
        'id': 'mahr-cost',
        'weddingPlanId': planId,
        'budgetCategoryId': 'mahr',
        'title': 'المهر',
        'totalAmount': '2000000',
        'paidAmount': '500000',
        'remainingAmount': '1500000',
        'status': 'OPEN',
        'payer': 'GROOM',
      }),
    ];
    return FinancePage(
      items: items,
      page: 1,
      pageSize: 30,
      total: items.length,
      totalPages: 1,
    );
  }

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

/// Keeps what a budget save sent, and answers with the plan in its new mode.
class _SavingApi extends _Api {
  _SavingApi(super.inside);

  final sent = <bool?>[];

  @override
  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
    String? expectedBudgetVersion,
    bool? budgetIncludesMahr,
  }) async {
    sent.add(budgetIncludesMahr);
    return MoneyBudgetReplaceResult(
      summary: ownerPlan(inside: budgetIncludesMahr ?? inside),
      categories: [
        BudgetCategory(id: 'hall', weddingPlanId: planId, name: 'القاعة'),
      ],
      idMap: const {},
    );
  }
}

class _FundingApi extends FundingApi {
  _FundingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async =>
      const [];
}

Future<void> _pump(
  WidgetTester tester, {
  required bool inside,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(_Api(inside)),
        ),
        ChangeNotifierProvider<FundingProvider>(
          create: (_) => FundingProvider(_FundingApi()),
        ),
      ],
      child: const MaterialApp(
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: MoneyOverviewScreen(
            weddingPlanId: 'plan-1',
            personaCode: 'GROOM',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final hero = find.byKey(const ValueKey('money-share-hero'));
  // The card read in order: since 2026-11-17 a figure's label and its figure
  // are two texts on one line, so «الميزانية 7» is read across them.
  Finder inHero(WidgetTester tester, String text) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: hero, matching: find.byType(Text)),
        )
        .map((t) => (t.data ?? '').replaceAll(' ', ' '))
        .join(' ');
    return texts.contains(text)
        ? find.byKey(const ValueKey('money-share-hero'))
        : find.byKey(const ValueKey('__absent__'));
  }

  group('the top card reads complete', () {
    testWidgets('inside: what is on him, then the budget with the mahr in '
        'it', (tester) async {
      await _pump(tester, inside: true);

      expect(inHero(tester, 'باقي عليك'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('money-share-figure')))
            .data,
        startsWith('1.5'),
      );
      expect(inHero(tester, 'الميزانية 7'), findsOneWidget);
      expect(inHero(tester, 'باقي منها 5'), findsOneWidget);
      // «منها المهر» is the note under «اتفقت على», its figure at the end.
      expect(inHero(tester, 'اتفقت على منها المهر 2'), findsOneWidget);
      expect(inHero(tester, 'دفعت 500'), findsOneWidget);
      expect(inHero(tester, 'برّا الميزانية'), findsNothing);
      // No figure that is all mahr is called the wedding's.
      expect(inHero(tester, 'العرس'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on its own: the budget untouched, the mahr its own line', (
      tester,
    ) async {
      await _pump(tester, inside: false);

      expect(inHero(tester, 'باقي عليك'), findsOneWidget);
      expect(inHero(tester, 'الميزانية 7'), findsOneWidget);
      expect(inHero(tester, 'باقي منها 7'), findsOneWidget);
      expect(inHero(tester, 'اتفقت على 2'), findsOneWidget);
      expect(inHero(tester, 'منها المهر'), findsNothing);
      final line = find.byKey(const ValueKey('money-share-mahr-line'));
      expect(line, findsOneWidget);
      final words = tester.widget<Text>(line).data!;
      expect(words, contains('برّا الميزانية'));
      expect(words, contains('سلّمت 500'));
      expect(words, contains('وباقي 1.5'));
      expect(inHero(tester, 'العرس'), findsNothing);
    });

    testWidgets('320 wide at text scale 1.3, both modes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final inside in [true, false]) {
        await _pump(tester, inside: inside, width: 320);
        expect(tester.takeException(), isNull, reason: 'inside: $inside');
      }
    });
  });

  testWidgets('«سجّل أول اتفاق» waits for a provider: the mahr is not one', (
    tester,
  ) async {
    await _pump(tester, inside: false);

    final step = find.byKey(const ValueKey('money-first-step-2'));
    expect(step, findsOneWidget);
    expect(find.descendant(of: step, matching: find.text('تم')), findsNothing);
  });

  testWidgets('the rows under it never call the mahr the wedding\'s', (
    tester,
  ) async {
    await _pump(tester, inside: false);

    expect(find.text('الدفعات الجاية'), findsOneWidget);
    expect(find.text('دفعات العرس الجاية'), findsNothing);
    expect(find.text('باقي على الاتفاقات كلها'), findsOneWidget);
    expect(find.text('باقي على العرس كله'), findsNothing);
    expect(find.text('التكلفة المسجّلة'), findsOneWidget);
    expect(find.text('تكلفة العرس المسجّلة'), findsNothing);
  });

  group('«البنود» follows the mode', () {
    Future<void> openItems(WidgetTester tester, {required bool inside}) async {
      await _pump(tester, inside: inside);
      await tester.tap(find.text('البنود'));
      await tester.pumpAndSettle();
    }

    testWidgets('inside: the box holds the mahr, its section says so', (
      tester,
    ) async {
      await openItems(tester, inside: true);

      final box = find.byKey(const ValueKey('money-items-budget'));
      expect(
        find.descendant(of: box, matching: find.text('الميزانية، فيها المهر')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: box, matching: find.textContaining('المهر 2')),
        findsWidgets,
      );
      final status = tester
          .widget<Text>(find.byKey(const ValueKey('money-items-budget-status')))
          .data!;
      expect(status, contains('المهر 2'));
      expect(status, contains('باقي منها 5'));
      expect(find.text('من الميزانية'), findsOneWidget);
      expect(find.text('برا الميزانية'), findsNothing);
      expect(find.textContaining('وهو برا الميزانية'), findsNothing);
      expect(find.textContaining('والمهر 2'), findsOneWidget);
    });

    testWidgets('on its own: as before', (tester) async {
      await openItems(tester, inside: false);

      expect(find.text('ميزانية العرس'), findsOneWidget);
      expect(find.text('برا الميزانية'), findsOneWidget);
      expect(find.textContaining('وهو برا الميزانية'), findsOneWidget);
    });
  });

  group('w19 «توزيع الميزانية»', () {
    Future<_SavingApi> pumpBudget(
      WidgetTester tester, {
      required bool inside,
      JourneyProfile profile = JourneyProfile.groom,
    }) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _SavingApi(inside);
      final router = GoRouter(
        initialLocation: '/budget',
        routes: [
          GoRoute(
            path: '/budget',
            builder: (_, _) => const MoneyBudgetScreen(weddingPlanId: 'plan-1'),
          ),
          GoRoute(
            path: AppRouter.money('plan-1'),
            builder: (_, _) => const Scaffold(body: Text('المال')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(api),
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                JourneyProfileScope(profile: profile, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('inside: the head says so, the reserve is after the mahr', (
      tester,
    ) async {
      await pumpBudget(tester, inside: true);

      expect(find.textContaining('فيها المهر'), findsWidgets);
      expect(find.textContaining('المهر لحاله'), findsNothing);
      // 7 million less the 2 million mahr: 5 million to give the items.
      final box = find.byKey(const ValueKey('money-budget-reserve'));
      expect(
        find.descendant(of: box, matching: find.textContaining('5')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('money-budget-mahr-note')), findsOne);
    });

    testWidgets('the sheet asks, in his numbers, and the save sends it', (
      tester,
    ) async {
      final api = await pumpBudget(tester, inside: false);

      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      expect(find.text('المهر لحاله، برا الميزانية'), findsNothing);
      expect(find.text('المهر من الميزانية؟'), findsOneWidget);
      expect(
        find.text(
          'من الميزانية 7 مليون يروح مليونين للمهر، ويبقى للعرس 5 مليون',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mahr-budget-inside')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-budget-total-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-budget-save')));
      await tester.pumpAndSettle();

      expect(api.sent, [true]);
    });

    // The keyboard up on a 320 phone hides the choice under the budget:
    // the first «تمام» brings it into view, the next closes the sheet.
    testWidgets('the keyboard up: the first «تمام» shows the choice', (
      tester,
    ) async {
      await pumpBudget(tester, inside: false);
      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('money-budget-total')),
        '8000000',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final choice = find.byKey(const ValueKey('mahr-budget-choice'));
      bool shown() {
        if (choice.evaluate().isEmpty) return false;
        final rect = tester.getRect(choice);
        final view = tester.getRect(
          find.ancestor(of: choice, matching: find.byType(Scrollable)).first,
        );
        return rect.top >= view.top - 0.5 &&
            rect.bottom <= view.bottom + 0.5 &&
            rect.bottom <= 700 - tester.view.viewInsets.bottom;
      }

      expect(shown(), isFalse, reason: 'the keyboard hides it');
      final done = find.byKey(const ValueKey('money-budget-total-done'));
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(done, findsOneWidget);
      // The press closes the keyboard, and the system takes its space back
      // (the test's own inset stays until it is reset). Changed on purpose:
      // this used to ask for the whole choice above a keyboard still up,
      // which held only while the choice was short enough; with the line
      // that says why the press did not close the sheet it is not.
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(shown(), isTrue);
      expect(
        find.byKey(const ValueKey('mahr-budget-choice-prompt')),
        findsOneWidget,
        reason: 'a press that did not close the sheet says why',
      );

      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(done, findsNothing);
    });

    // From the review of this branch: «تمام» was spent on showing the
    // choice even when the total was not touched, and nothing said so.
    testWidgets('the total as it was: «تمام» closes at the first press', (
      tester,
    ) async {
      await pumpBudget(tester, inside: false);
      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final done = find.byKey(const ValueKey('money-budget-total-done'));
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(done, findsNothing);
    });

    testWidgets('an untouched answer is not sent', (tester) async {
      final api = await pumpBudget(tester, inside: false);

      await tester.tap(find.byKey(const ValueKey('money-budget-save')));
      await tester.pumpAndSettle();
      expect(api.sent, [null]);
    });

    testWidgets('a bride\'s plan is never asked', (tester) async {
      await pumpBudget(tester, inside: false, profile: JourneyProfile.bride);

      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsNothing);
    });

    // From the review of this branch: the server lets only a plan that
    // pays the mahr count it in its budget, and a plan that names neither
    // a groom nor a bride pays none. It was asked all the same (anything
    // that is not a bride's was taken for a groom's), the server refused
    // the answer, and the whole budget save was lost with it.
    testWidgets('a plan that names no groom is not asked', (tester) async {
      await pumpBudget(
        tester,
        inside: false,
        profile: JourneyProfile.of(planPersona: null, readerFeminine: false),
      );

      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsNothing);
    });

    test('only a groom\'s plan pays the mahr', () {
      expect(JourneyProfile.groom.paysMahr, isTrue);
      expect(JourneyProfile.bride.paysMahr, isFalse);
      expect(JourneyProfile.fromPersona('GROOM').paysMahr, isTrue);
      expect(JourneyProfile.fromPersona(' groom ').paysMahr, isTrue);
      expect(JourneyProfile.fromPersona(null).paysMahr, isFalse);
      expect(JourneyProfile.fromPersona('BRIDE').paysMahr, isFalse);
      expect(
        JourneyProfile.of(planPersona: 'GROOM', readerFeminine: true).paysMahr,
        isTrue,
      );
      // The same plan read by someone else is still the groom's.
      expect(JourneyProfile.groom.readBy(feminine: true).paysMahr, isTrue);
    });
  });

  group('the shared summary follows the mode', () {
    test('inside: the mahr in the agreed, and what is left of the budget', () {
      final text = moneyShareText(
        ownerPlan(inside: true),
        planTitle: 'عرس محمد',
        hideAmounts: false,
      );
      expect(text, contains('• الميزانية: 7 مليون ر.ي، فيها المهر'));
      expect(text, contains('• باقي من الميزانية: 5 مليون ر.ي'));
      expect(text, contains('• المهر (من الميزانية): 2 مليون ر.ي'));
      expect(text, isNot(contains('برا الميزانية')));
    });

    test('on its own: the mahr outside, the budget untouched', () {
      final text = moneyShareText(
        ownerPlan(inside: false),
        planTitle: 'عرس محمد',
        hideAmounts: false,
      );
      expect(text, contains('• الميزانية: 7 مليون ر.ي'));
      expect(text, isNot(contains('فيها المهر')));
      expect(text, contains('• باقي من الميزانية: 7 مليون ر.ي'));
      expect(text, contains('• المهر (برا الميزانية): 2 مليون ر.ي'));
    });
  });

  // The mahr item's own page said «برا الميزانية» whatever the plan chose.
  group('the mahr item\'s page says where the mahr is counted', () {
    Future<void> openMahrItem(WidgetTester tester, {required bool inside}) {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(_Api(inside)),
          child: const MaterialApp(
            home: JourneyProfileScope(
              profile: JourneyProfile.groom,
              child: BudgetCategoryDetailsScreen(
                weddingPlanId: 'plan-1',
                categoryId: 'mahr',
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('inside the budget', (tester) async {
      await openMahrItem(tester, inside: true);
      await tester.pumpAndSettle();

      expect(find.text('من الميزانية'), findsOneWidget);
      expect(find.text('برا الميزانية'), findsNothing);
    });

    testWidgets('on its own', (tester) async {
      await openMahrItem(tester, inside: false);
      await tester.pumpAndSettle();

      expect(find.text('برا الميزانية'), findsOneWidget);
      expect(find.text('من الميزانية'), findsNothing);
    });
  });
}
