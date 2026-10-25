import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/money_payer_words.dart'
    show payerAvatarLetter, payerPaidLine;
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/screens/payer_payments_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/mahr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// B5, the mahr (a06, C1): the groom's agreement with the bride's family and
// the bride's mahr coming in, beside the wedding (c01), in its own section
// (c02) and, for her, among her money in (c05); then a06 for a saved plan
// and w20 «مين دفع ايش» (G14). Every number is the server's.

const _groomMahr = MoneyMahrSummary(
  side: MahrSide.pays,
  total: '3000000',
  settled: '2000000',
  remaining: '1000000',
);

final _brideMahr = MoneyMahrSummary(
  side: MahrSide.receives,
  total: '3000000',
  settled: '2000000',
  remaining: '1000000',
  nextDueAt: DateTime(2026, 11, 15),
);

Future<_Api> _pumpMoney(
  WidgetTester tester, {
  required JourneyProfile profile,
  required String persona,
  MoneyMahrSummary? mahr,
  List<FundingSource> sources = const [],
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Api(mahr: mahr, groomItem: mahr?.side == MahrSide.pays);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(api),
        ),
        ChangeNotifierProvider<FundingProvider>(
          create: (_) => FundingProvider(_FundingApi(sources)),
        ),
      ],
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: profile,
          child: MoneyOverviewScreen(
            weddingPlanId: 'plan-1',
            personaCode: persona,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('c01 the mahr beside the wedding', () {
    testWidgets('the groom: where the money goes, his agreement and his '
        'wedding', (tester) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.groom,
        persona: 'GROOM',
        mahr: _groomMahr,
      );

      expect(
        find.byKey(const ValueKey('money-mahr-and-wedding')),
        findsOneWidget,
      );
      expect(find.text('وين تروح الفلوس'), findsOneWidget);
      expect(find.text('الاتفاق مع أهل العروسة'), findsOneWidget);
      expect(find.text('عرسك'), findsOneWidget);
      final mahrCard = find.byKey(const ValueKey('money-mahr-card'));
      expect(
        find.descendant(of: mahrCard, matching: find.textContaining('سلّمت ')),
        findsOneWidget,
      );
      expect(find.textContaining('سلّمتِ'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bride: the mahr reaching her and her wedding', (
      tester,
    ) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.bride,
        persona: 'BRIDE',
        mahr: _brideMahr,
      );

      expect(find.text('المهر وعرسك'), findsOneWidget);
      expect(find.text('المهر يوصلك'), findsOneWidget);
      final mahrCard = find.byKey(const ValueKey('money-mahr-card'));
      expect(
        find.descendant(of: mahrCard, matching: find.textContaining('وصلك ')),
        findsOneWidget,
      );
      // D59: the hall was paid by her father, so it is not «دفعتِ».
      final weddingCard = find.byKey(const ValueKey('money-wedding-card'));
      expect(
        find.descendant(
          of: weddingCard,
          matching: find.textContaining('دفع عنك 1.2 مليون'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('اتفقتِ على'), findsOneWidget);
      expect(find.text('الاتفاق مع أهل العروسة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D59: the groom reads what he paid and what his father paid '
        'for him', (tester) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.groom,
        persona: 'GROOM',
        mahr: _groomMahr,
      );

      final hero = find.byKey(const ValueKey('money-dashboard-hero'));
      expect(
        find.descendant(
          of: hero,
          matching: find.textContaining('دفعت منها 2 مليون'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.textContaining('، ودفع عنك الوالد 1.2 مليون'),
        ),
        findsOneWidget,
      );
      // His mahr is recorded: no way to record it again.
      expect(find.byKey(const ValueKey('money-record-mahr')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D59: someone helping in his plan reads the groom named, never '
        'as if they had paid', (tester) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.of(
          planPersona: 'GROOM',
          readerFeminine: true,
          readerIsOwner: false,
        ),
        persona: 'GROOM',
        mahr: _groomMahr,
      );

      expect(find.textContaining('اتفق العريس على'), findsOneWidget);
      expect(find.textContaining('دفعتِ'), findsNothing);
      expect(find.textContaining('سلّمتِ'), findsNothing);
      final mahrCard = find.byKey(const ValueKey('money-mahr-card'));
      expect(
        find.descendant(
          of: mahrCard,
          matching: find.textContaining('العريس سلّم 2 مليون'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('دفع عنه الوالد'), findsOneWidget);
      expect(find.textContaining('باقي عليه'), findsOneWidget);
      // Only the owner records the mahr.
      expect(find.byKey(const ValueKey('money-record-mahr')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D59: a groom\'s or a bride\'s plan without its mahr always '
        'has the way back to record it, in c01 and c02', (tester) async {
      await _pumpMoney(tester, profile: JourneyProfile.bride, persona: 'BRIDE');

      expect(find.byKey(const ValueKey('money-record-mahr')), findsOneWidget);
      expect(find.text('سجّلي المهر'), findsOneWidget);
      await tester.tap(find.text('البنود'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('money-record-mahr')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D59: a helper\'s plan has no mahr to record', (tester) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.groom,
        persona: 'HELPER',
      );

      expect(find.byKey(const ValueKey('money-record-mahr')), findsNothing);
    });

    testWidgets('no mahr from the server, no mahr cards', (tester) async {
      await _pumpMoney(tester, profile: JourneyProfile.groom, persona: 'GROOM');

      expect(
        find.byKey(const ValueKey('money-mahr-and-wedding')),
        findsNothing,
      );
      expect(find.text('وين تروح الفلوس'), findsNothing);
    });
  });

  group('c02 the mahr is its own section above the wedding', () {
    testWidgets('the groom: his agreement, what he handed over, the rest\'s '
        'day', (tester) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.groom,
        persona: 'GROOM',
        mahr: _groomMahr,
      );
      await tester.tap(find.text('البنود'));
      await tester.pumpAndSettle();

      final section = find.byKey(const ValueKey('money-mahr-section'));
      expect(section, findsOneWidget);
      expect(find.text('الاتفاق مع أهل العروسة'), findsOneWidget);
      expect(
        find.descendant(of: section, matching: find.text('المهر')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: section, matching: find.textContaining('سلّمت ')),
        findsOneWidget,
      );
      // The rest is due on its schedule's day, from the plan's schedules.
      expect(
        find.descendant(
          of: section,
          matching: find.textContaining('الباقي 15 نوفمبر'),
        ),
        findsOneWidget,
      );
      expect(find.text('عرسك'), findsOneWidget);
      // The mahr item is not one of the wedding's rows.
      expect(
        find.descendant(of: section, matching: find.text('القاعة')),
        findsNothing,
      );
      expect(find.text('القاعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bride: the mahr reaching her from the groom', (
      tester,
    ) async {
      await _pumpMoney(
        tester,
        profile: JourneyProfile.bride,
        persona: 'BRIDE',
        mahr: _brideMahr,
      );
      await tester.tap(find.text('البنود'));
      await tester.pumpAndSettle();

      expect(find.text('المهر يوصلك من العريس'), findsOneWidget);
      final row = find.byKey(const ValueKey('money-item-mahr-received'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.textContaining('وصلك ')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('الباقي 15 نوفمبر'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('c05: her mahr is among her money in, the rest with its day', (
    tester,
  ) async {
    await _pumpMoney(
      tester,
      profile: JourneyProfile.bride,
      persona: 'BRIDE',
      mahr: _brideMahr,
      sources: [
        _source('mahr-in', 'المهر من العريس', '2000000', received: true),
        _source(
          'mahr-rest',
          'باقي المهر',
          '1000000',
          received: false,
          expectedAt: '2026-11-15',
        ),
      ],
    );
    await tester.tap(find.text('من وين'));
    await tester.pumpAndSettle();

    expect(find.text('المهر من العريس'), findsOneWidget);
    expect(find.text('باقي المهر'), findsOneWidget);
    expect(find.text('يوصلك 15 نوفمبر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D59 c05 as drawn: «صرفتِ · معك», what came first with the '
      'mahr leading it, then what is promised, a late one «متأخر»', (
    tester,
  ) async {
    FundingSource source(
      String id,
      String kind,
      String name, {
      required bool received,
      bool overdue = false,
    }) => FundingSource.fromJson({
      'id': id,
      'weddingPlanId': 'plan-1',
      'kind': kind,
      'sourceName': name,
      'amount': '1000000',
      'status': received ? 'RECEIVED' : 'PLEDGED',
      'isOverdue': overdue,
    });
    await _pumpMoney(
      tester,
      profile: JourneyProfile.bride,
      persona: 'BRIDE',
      mahr: _brideMahr,
      // In the order recorded: the mahr came last.
      sources: [
        source('savings', 'SAVINGS', 'مدخراتي', received: true),
        source('friend', 'OTHER', 'صاحبتي عبلة', received: false, overdue: true),
        source('mahr-in', 'MAHR', 'المهر من العريس', received: true),
        source('mahr-rest', 'MAHR', 'باقي المهر', received: false),
      ],
    );
    await tester.tap(find.text('من وين'));
    await tester.pumpAndSettle();

    expect(
      find.text('صرفتِ 1.2 مليون ر.ي · معك 800,000 ر.ي'),
      findsOneWidget,
    );
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('المهر من العريس'), lessThan(top('مدخراتي')));
    expect(top('مدخراتي'), lessThan(top('صاحبتي عبلة')));
    expect(top('صاحبتي عبلة'), lessThan(top('باقي المهر')));
    expect(find.text('متأخر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('a06 for a saved plan', () {
    testWidgets('the groom records what he handed over and the rest\'s day', (
      tester,
    ) async {
      final api = await _pumpMahr(tester, JourneyProfile.groom);

      expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
      expect(find.textContaining('اللي بتسلّمه لأهل العروسة'), findsOneWidget);
      expect(find.text('سلّمت منه'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('mahr-total')),
          matching: find.byType(EditableText),
        ),
        '3000000',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('mahr-settled')),
          matching: find.byType(EditableText),
        ),
        '2000000',
      );
      await tester.pumpAndSettle();
      expect(find.text('باقي مليون'), findsOneWidget);

      await tester.tap(find.text('احفظ المهر'));
      await tester.pumpAndSettle();

      expect(api.recorded, [(total: '3000000', settled: '2000000')]);
      expect(find.text('الرئيسية'), findsOneWidget);
    });

    testWidgets('no mahr typed, nothing is sent', (tester) async {
      final api = await _pumpMahr(tester, JourneyProfile.groom);

      await tester.tap(find.text('احفظ المهر'));
      await tester.pumpAndSettle();

      expect(find.text('اكتب كم المهر'), findsOneWidget);
      expect(api.recorded, isEmpty);
    });

    testWidgets('the bride receives it, in her words', (tester) async {
      await _pumpMahr(tester, JourneyProfile.bride);

      expect(find.textContaining('اللي بتستلمينه من العريس'), findsOneWidget);
      expect(find.text('استلمتِ منه'), findsOneWidget);
      expect(find.textContaining('عرس النساء'), findsOneWidget);
    });

    testWidgets('a groom reading a bride\'s plan: her side, his words', (
      tester,
    ) async {
      await _pumpMahr(tester, JourneyProfile.bride.readBy(feminine: false));

      expect(find.textContaining('اللي بتستلمه من العريس'), findsOneWidget);
      expect(find.text('استلمت منه'), findsOneWidget);
    });
  });

  group('w20 who paid what', () {
    testWidgets('each payer\'s total and only their payments', (tester) async {
      await _pumpPayers(tester);

      expect(find.text('مين دفع ايش'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('الوالد'), findsWidgets);
      expect(find.text('العريس'), findsWidgets);
      expect(find.text('اللي انحسب دفعه'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('payer-payment-hall-paid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('payer-payment-mahr-paid')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('payer-FAMILY|الوالد')));
      await tester.pumpAndSettle();

      expect(find.text('الوالد دفع'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('payer-payment-hall-paid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('payer-payment-mahr-paid')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    test('the payer as the plan\'s owner says it', () {
      expect(payerLabel('GROOM', null, bridePlan: false, owner: true), 'أنا');
      expect(
        payerLabel('GROOM', null, bridePlan: false, owner: false),
        'العريس',
      );
      expect(payerLabel('BRIDE', null, bridePlan: true, owner: true), 'أنا');
      expect(
        payerLabel('FAMILY', 'خالي أحمد', bridePlan: false, owner: true),
        'خالي أحمد',
      );
      expect(payerLabel('FAMILY', ' ', bridePlan: false, owner: true), 'الأهل');
      expect(payerLabel(null, null, bridePlan: false, owner: true), 'ما تحدد');
    });

    test('D59: the verb agrees with who paid; the avatar drops the article', () {
      const groom = JourneyProfile.groom;
      expect(payerPaidLine('BRIDE', 'العروسة', groom), 'العروسة دفعت');
      expect(payerPaidLine('FAMILY', 'الأهل', groom), 'الأهل دفعوا');
      expect(payerPaidLine('FAMILY', 'الوالد', groom), 'الوالد دفع');
      expect(payerPaidLine('GROOM', 'العريس', groom), 'العريس دفع');
      expect(payerPaidLine('SHARED', 'المشترك', groom), 'المدفوع المشترك');
      expect(payerPaidLine('GROOM', 'أنا', groom), 'دفعت أنا');
      expect(payerPaidLine('BRIDE', 'أنا', JourneyProfile.bride), 'دفعتِ أنا');
      expect(
        payerLabel('SHARED', null, bridePlan: false, owner: true),
        'المشترك',
      );
      expect(payerAvatarLetter('الوالد'), 'و');
      expect(payerAvatarLetter('العروسة'), 'ع');
      expect(payerAvatarLetter('خالي أحمد'), 'خ');
      expect(payerAvatarLetter('أنا'), 'أ');
    });

    testWidgets('D59: the groom reads his own payments as his, his father\'s '
        'as his father\'s', (
      tester,
    ) async {
      await _pumpPayers(tester, profile: JourneyProfile.groom);

      // The owner reads his own payments as his.
      expect(find.text('أنا'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('payer-FAMILY|الوالد')));
      await tester.pumpAndSettle();
      final total = find.byKey(const ValueKey('payer-total'));
      expect(
        find.descendant(of: total, matching: find.text('الوالد دفع')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: total, matching: find.text('و')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Future<_Api> _pumpMahr(WidgetTester tester, JourneyProfile profile) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Api();
  final router = GoRouter(
    initialLocation: '/mahr',
    routes: [
      GoRoute(
        path: AppRouter.home,
        builder: (_, _) => const Scaffold(body: Text('الرئيسية')),
      ),
      GoRoute(
        path: '/mahr',
        builder: (_, _) => const MahrScreen(weddingPlanId: 'plan-1'),
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

/// w20 as someone helping in the groom's plan reads it (the parties by
/// their words), or as [profile] reads it.
Future<void> _pumpPayers(WidgetTester tester, {JourneyProfile? profile}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(_Api(mahr: _groomMahr, groomItem: true)),
      child: MaterialApp(
        home: JourneyProfileScope(
          profile:
              profile ??
              JourneyProfile.of(
                planPersona: 'GROOM',
                readerFeminine: false,
                readerIsOwner: false,
              ),
          child: const PayerPaymentsScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FundingSource _source(
  String id,
  String name,
  String amount, {
  required bool received,
  String? expectedAt,
}) => FundingSource.fromJson({
  'id': id,
  'weddingPlanId': 'plan-1',
  'kind': 'MAHR',
  'sourceName': name,
  'amount': amount,
  'status': received ? 'RECEIVED' : 'PLEDGED',
  'expectedAt': ?expectedAt,
});

class _Api extends FinanceApi {
  _Api({this.mahr, this.groomItem = false})
    : super(ApiClient(tokenProvider: () async => null));

  final MoneyMahrSummary? mahr;

  /// The groom's mahr is an item of its own (outside the budget) with its
  /// agreement and its rest's schedule; the bride's is her money in.
  final bool groomItem;
  final recorded = <({String total, String settled})>[];

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => MoneySummary(
    planId: planId,
    currency: 'YER',
    // The hall is the father's (D59): its payments are not the owner's.
    budget: const MoneyBudgetSummary(
      total: '7000000',
      confirmedCost: '2400000',
      paid: '1200000',
      paidByOthers: '1200000',
      outstanding: '1200000',
      count: 1,
      remaining: '4600000',
    ),
    costs: MoneyCostsSummary(
      total: groomItem ? '5400000' : '2400000',
      paid: groomItem ? '3200000' : '1200000',
      paidByOwner: groomItem ? '2000000' : '0',
      paidByOthers: '1200000',
      outstanding: '2200000',
      count: groomItem ? 2 : 1,
    ),
    categories: [
      if (groomItem)
        const MoneyCategorySummary(
          categoryId: 'mahr',
          name: 'المهر',
          confirmedCost: '3000000',
          paid: '2000000',
          isMahr: true,
          costsCount: 1,
        ),
      const MoneyCategorySummary(
        categoryId: 'hall',
        name: 'القاعة',
        allocatedAmount: '2400000',
        confirmedCost: '2400000',
        paid: '1200000',
        costsCount: 1,
      ),
    ],
    funding: const MoneyFundingSummary(
      received: '2000000',
      pledged: '1000000',
      spent: '1200000',
      availableCash: '800000',
      sourcesCount: 2,
    ),
    mahr: mahr,
    payers: [
      if (groomItem)
        const MoneyPayerSummary(
          payer: 'GROOM',
          agreed: '3000000',
          paid: '2000000',
          outstanding: '1000000',
          costsCount: 1,
        ),
      const MoneyPayerSummary(
        payer: 'FAMILY',
        payerName: 'الوالد',
        ownerMoney: false,
        agreed: '2400000',
        paid: '1200000',
        outstanding: '1200000',
        costsCount: 1,
      ),
    ],
  );

  @override
  Future<MoneySummary> recordMahr(
    String planId, {
    required String total,
    required String settled,
    DateTime? remainingDueDate,
  }) async {
    recorded.add((total: total, settled: settled));
    return getMoneySummary(planId);
  }

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    if (groomItem)
      BudgetCategory.fromJson({
        'id': 'mahr',
        'weddingPlanId': planId,
        'name': 'المهر',
        'kind': 'MAHR',
      }),
    BudgetCategory(
      id: 'hall',
      weddingPlanId: planId,
      name: 'القاعة',
      allocatedAmount: '2400000',
    ),
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
      if (groomItem)
        WeddingCost.fromJson({
          'id': 'mahr-cost',
          'weddingPlanId': planId,
          'budgetCategoryId': 'mahr',
          'title': 'المهر',
          'totalAmount': '3000000',
          'paidAmount': '2000000',
          'remainingAmount': '1000000',
          'status': 'OPEN',
          'payer': 'GROOM',
        }),
      WeddingCost.fromJson({
        'id': 'hall-cost',
        'weddingPlanId': planId,
        'budgetCategoryId': 'hall',
        'title': 'القاعة',
        'totalAmount': '2400000',
        'paidAmount': '1200000',
        'remainingAmount': '1200000',
        'status': 'OPEN',
        'payer': 'FAMILY',
        'payerName': 'الوالد',
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
  }) async {
    final items = [
      if (groomItem)
        CostPayment.fromJson({
          'id': 'mahr-paid',
          'costId': 'mahr-cost',
          'amount': '2000000',
          'paidAt': '2026-08-01T09:00:00.000Z',
          'entryType': 'PAYMENT',
          'costTitle': 'المهر',
        }),
      CostPayment.fromJson({
        'id': 'hall-paid',
        'costId': 'hall-cost',
        'amount': '1200000',
        'paidAt': '2026-09-10T09:00:00.000Z',
        'entryType': 'PAYMENT',
        'costTitle': 'القاعة',
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
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async => [
    if (groomItem)
      PaymentSchedule.fromJson({
        'id': 'mahr-rest',
        'costId': 'mahr-cost',
        'amount': '1000000',
        'dueDate': '2026-11-15',
        'status': 'PENDING',
        'costTitle': 'المهر',
      }),
  ];
}

class _FundingApi extends FundingApi {
  _FundingApi(this.sources) : super(ApiClient(tokenProvider: () async => null));

  final List<FundingSource> sources;

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async =>
      sources;
}
