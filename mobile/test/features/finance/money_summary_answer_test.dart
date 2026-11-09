import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/money_plan.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D102-D109 «الملخص» on a plan kept on the phone: every figure comes from the
// phone's copy of the money rules (held to the server's by
// money_plan_parity_test), and every sentence is checked against the plan's
// arithmetic worked out by hand here.

const _planId = 'guest-plan-summary-answer';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

/// A day [offset] days from the plan's today.
String _day(int offset) {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day + offset).toIso8601String();
}

Map<String, dynamic> _cost(
  String id,
  String category,
  String title,
  String total, {
  String cover = 'WHOLE',
  String? part,
  String? payer,
}) => {
  'id': id,
  'budgetCategoryId': category,
  'title': title,
  'totalAmount': total,
  'paidAmount': '0',
  'status': 'PENDING',
  'entryKind': 'AGREEMENT',
  'estimateCover': cover,
  'estimatePart': ?part,
  'payer': ?payer,
};

Map<String, dynamic> _date(String id, String cost, String amount, int day) => {
  'id': id,
  'costId': cost,
  'amount': amount,
  'status': 'PENDING',
  'dueDate': _day(day),
  'createdAt': _day(-30),
};

Map<String, dynamic> _source(
  String id,
  String kind,
  String name,
  String amount, {
  bool pledged = false,
  int? expected,
  List<Map<String, dynamic>> repayments = const [],
}) => {
  'id': id,
  'kind': kind,
  'sourceName': name,
  'contributorName': kind == 'FAMILY_SUPPORT' ? name : null,
  'amount': amount,
  'status': pledged ? 'PLEDGED' : 'RECEIVED',
  'expectedAt': expected == null ? null : _day(expected),
  'repayments': repayments,
};

const _hall = {
  'id': 'c-hall',
  'weddingPlanId': _planId,
  'name': 'القاعة',
  'allocatedAmount': '1200000',
  'estimatedAmount': '1300000',
};

/// A plan on the phone, through the real API and store the app uses.
Future<(FinanceApi, FundingApi)> _plan({
  String? budget = '3000000',
  List<Map<String, dynamic>> items = const [_hall],
  List<Map<String, dynamic>> costs = const [],
  List<Map<String, dynamic>> payments = const [],
  List<Map<String, dynamic>> dates = const [],
  List<Map<String, dynamic>> sources = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: _NoNetwork(),
  );
  await offline.initialize();
  final local = FinanceLocalDataSource(offline);
  if (budget != null || items.isNotEmpty) {
    await local.saveBudget(
      planId: _planId,
      totalBudget: budget,
      currency: 'YER',
      categories: items,
    );
  }
  Future<void> put(String table, Map<String, dynamic> json) => database
      .saveCachedItem(table: table, json: {...json, 'weddingPlanId': _planId});
  for (final cost in costs) {
    await put(OfflineTables.cachedCosts, cost);
  }
  for (final payment in payments) {
    await put(OfflineTables.cachedCostPayments, payment);
  }
  for (final date in dates) {
    await put(OfflineTables.cachedPaymentSchedules, date);
  }
  for (final source in sources) {
    await put(OfflineTables.cachedFundingSources, source);
  }
  return (
    FinanceApi(
      _NoNetwork(),
      offline: offline,
      localPlanContextLoader: (_) async =>
          const LocalFinancePlanContext(currency: 'YER', persona: 'GROOM'),
    ),
    FundingApi(_NoNetwork(), offline: offline),
  );
}

/// The hall: 1,200,000 agreed, 400,000 paid, 300,000 three days late and
/// 500,000 in twelve days.
const _hallCost = [
  {
    'id': 'k-hall',
    'budgetCategoryId': 'c-hall',
    'title': 'قاعة الريان',
    'totalAmount': '1200000',
    'paidAmount': '400000',
    'status': 'PARTIALLY_PAID',
    'entryKind': 'AGREEMENT',
    'estimateCover': 'WHOLE',
  },
];
final _hallPaid = [
  {
    'id': 'p-hall',
    'costId': 'k-hall',
    'amount': '400000',
    'entryType': 'PAYMENT',
    'paidAt': _day(-20),
  },
];
final _hallDates = [
  _date('s-late', 'k-hall', '300000', -3),
  _date('s-next', 'k-hall', '500000', 12),
];

class _Screen {
  _Screen(this.router);
  final GoRouter router;
  String get location => router.state.uri.path;
}

Future<_Screen> _open(
  WidgetTester tester,
  (FinanceApi, FundingApi) apis, {
  double textScale = 1.3,
  JourneyProfile? profile,
}) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // A second plan in one test gets its own providers, not the first's.
  await tester.pumpWidget(const SizedBox.shrink());
  Widget elsewhere(GoRouterState state) =>
      Scaffold(body: Text(state.uri.path, key: const ValueKey('elsewhere')));
  final router = GoRouter(
    initialLocation: AppRouter.money(_planId),
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (_, _) => const MoneyOverviewScreen(
          weddingPlanId: _planId,
          personaCode: 'groom',
        ),
        routes: [
          for (final path in const [
            'costs/:costId/schedules/:scheduleId/pay',
            'costs/:costId',
            'costs/new',
            'funding',
            'budget',
          ])
            GoRoute(path: path, builder: (_, state) => elsewhere(state)),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider(apis.$1)),
        ChangeNotifierProvider(create: (_) => FundingProvider(apis.$2)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: profile == null
                ? child!
                : JourneyProfileScope(profile: profile, child: child!),
          ),
        ),
      ),
    ),
  );
  // The store answers off the test clock.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  return _Screen(router);
}

String _coverText(WidgetTester tester) {
  final cover = find.byKey(const ValueKey('money-cover'));
  expect(cover, findsOneWidget);
  return tester
      .widgetList<Text>(find.descendant(of: cover, matching: find.byType(Text)))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join(' ');
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  group('«الملخص» says what is on him and whether his money covers it', () {
    // Cash 900,000 (savings 900,000 + loan 400,000 − 400,000 paid). With
    // the father's 500,000 on day 10: 600 (late, today) → 1,100 → 600
    // (day 12) → 250 (photographer, day 25) → 50 (repayment, day 60) →
    // −150 (repayment, day 120) → −950 (the mahr, undated, last).
    Future<(FinanceApi, FundingApi)> twoDips() => _plan(
      items: const [
        _hall,
        {
          'id': 'c-photo',
          'weddingPlanId': _planId,
          'name': 'التصوير',
          'allocatedAmount': '400000',
          'estimatedAmount': '500000',
        },
        {
          'id': 'c-mahr',
          'weddingPlanId': _planId,
          'name': 'المهر',
          'kind': 'MAHR',
          'allocatedAmount': '800000',
        },
      ],
      costs: [
        ..._hallCost,
        _cost(
          'k-photo',
          'c-photo',
          'المصور',
          '350000',
          cover: 'PART',
          part: '300000',
        ),
        _cost('k-mahr', 'c-mahr', 'المهر', '800000'),
      ],
      payments: _hallPaid,
      dates: [..._hallDates, _date('s-photo', 'k-photo', '350000', 25)],
      sources: [
        _source('f-save', 'SAVINGS', 'مدخراتي', '900000'),
        _source(
          'f-father',
          'FAMILY_SUPPORT',
          'أبوي',
          '500000',
          pledged: true,
          expected: 10,
        ),
        _source(
          'f-loan',
          'LOAN',
          'سلفة من خالي',
          '400000',
          repayments: [
            {
              'id': 'r-1',
              'amount': '200000',
              'dueDate': _day(60),
              'status': 'PLANNED',
            },
            {
              'id': 'r-2',
              'amount': '200000',
              'dueDate': _day(120),
              'status': 'PLANNED',
            },
          ],
        ),
      ],
    );

    testWidgets(
      'short: the whole gap, from the day it starts, as the home says',
      (tester) async {
        final apis = await tester.runAsync(twoDips);
        await _open(tester, apis!);

        // 800,000 hall + 350,000 photographer + 800,000 mahr: 1,950,000, a
        // half rounded up.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('money-share-figure')))
              .data,
          matches(RegExp(r'^2[\s\u00A0]مليون')),
        );
        final cover = _coverText(tester);
        // D103: what is missing is the deepest fall (950,000), the home's
        // shortfall, said from its first day; never the first day's 150,000.
        expect(cover, contains('ينقصك 950,000'));
        expect(cover, contains('يبدأ'));
        expect(cover, contains('(سلفة من خالي)'));
        expect(cover, isNot(contains('150,000')));
        expect(cover, contains('معك 900,000'));
        expect(cover, contains('800,000'));
        expect(cover, contains('عليك بدون موعد'));
        final provider = tester
            .element(find.byType(MoneyOverviewScreen))
            .read<FinanceProvider>();
        // The home's figure is the same 950,000.
        expect(moneyValue(provider.summary.funding?.shortfall), 950000);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the late date comes first, and is paid on its own page', (
      tester,
    ) async {
      final apis = await tester.runAsync(twoDips);
      final screen = await _open(tester, apis!);

      final late = find.byKey(const ValueKey('money-late-due'));
      expect(late, findsOneWidget);
      expect(
        find.descendant(of: late, matching: find.textContaining('قاعة الريان')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('money-late-move')), findsOneWidget);
      // Above the share: the one loud card.
      expect(
        tester.getTopLeft(late).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('money-share-hero'))).dy,
        ),
      );
      // The late date is not repeated among the coming ones.
      expect(
        find.byKey(const ValueKey('money-coming-due-s-late')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('money-late-pay')));
      await tester.pumpAndSettle();
      expect(
        screen.location,
        AppRouter.moneySchedulePay(_planId, 'k-hall', 's-late'),
      );
    });

    testWidgets('«كيف حسبناها؟» walks the account line by line', (
      tester,
    ) async {
      final apis = await tester.runAsync(twoDips);
      await _open(tester, apis!);

      await _scrollTo(tester, find.byKey(const ValueKey('money-how-counted')));
      await tester.tap(find.byKey(const ValueKey('money-how-counted')));
      await tester.pumpAndSettle();
      // His lines on their days, the father's promise among them, and the
      // undated mahr last: 7 steps.
      String step(int index) => tester
          .widget<JourneyListRow>(
            find.byKey(ValueKey('money-counted-step-$index')),
          )
          .title;
      expect(
        [for (var index = 0; index < 7; index++) step(index)],
        [
          'قاعة الريان',
          'أبوي',
          'قاعة الريان',
          'المصور',
          'سلفة من خالي',
          'سلفة من خالي',
          'المهر',
        ],
      );
      expect(find.byKey(const ValueKey('money-counted-step-7')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('what needs him, apart from paying', (tester) async {
      final apis = await tester.runAsync(twoDips);
      await _open(tester, apis!);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('money-needs-attention')),
      );

      // D105, D109: 350,000 agreed for part of the 500,000 estimate, so
      // 350,000 + (500,000 − 300,000) = 550,000 against 400,000 allocated.
      expect(find.text('بند «التصوير» فوق المخصص له'), findsOneWidget);
      expect(find.textContaining('بـ 150,000'), findsOneWidget);
      // The mahr has no date.
      expect(find.textContaining('المهر: 800,000'), findsOneWidget);
      // The hall's 1,200,000 replaces its 1,300,000 estimate (WHOLE): not
      // over its 1,200,000.
      expect(find.textContaining('«القاعة» فوق'), findsNothing);
    });

    testWidgets('the whole picture: three figures, never added together', (
      tester,
    ) async {
      final apis = await tester.runAsync(twoDips);
      await _open(tester, apis!);
      await _scrollTo(tester, find.byKey(const ValueKey('money-whole-cost')));

      final left = find.byKey(const ValueKey('money-whole-left'));
      // All of it is on him: said, not its figure twice.
      expect(
        find.descendant(of: left, matching: find.text('كله عليك')),
        findsOneWidget,
      );
      final loans = find.byKey(const ValueKey('money-whole-loans'));
      expect(
        find.descendant(of: loans, matching: find.textContaining('400,000')),
        findsOneWidget,
      );
      // Hall 1,200,000 + photo 550,000 + mahr 800,000: 2,550,000.
      final cost = find.byKey(const ValueKey('money-whole-cost'));
      expect(
        find.descendant(of: cost, matching: find.textContaining('2.6 مليون')),
        findsOneWidget,
      );

      // A row opens its tab from the top, not where the summary was.
      await tester.tap(cost);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('money-tabs')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('money-tabs'))).dy,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });

    // The lead's parts (the mahr's rest, his agreements) when there are
    // both; one part alone would say the lead's figure twice.
    testWidgets('the lead is split only when it has two parts', (tester) async {
      final both = await tester.runAsync(twoDips);
      await _open(tester, both!);
      // Mahr 800,000; hall 800,000 left + photo 350,000: 1,150,000.
      expect(find.textContaining('باقي المهر 800,000'), findsOneWidget);
      expect(find.textContaining('اتفاقاتك 1.2 مليون'), findsOneWidget);

      final hallOnly = await tester.runAsync(
        () => _plan(costs: _hallCost, payments: _hallPaid, dates: _hallDates),
      );
      await _open(tester, hallOnly!);
      expect(find.textContaining('باقي المهر'), findsNothing);
      expect(find.textContaining('اتفاقاتك'), findsNothing);
    });

    // The loan is the owner's debt: «عليك» to him, «على العريس» to anyone
    // helping, as «الدفعات» says it.
    testWidgets('a loan is the owner\'s debt, said to the reader', (
      tester,
    ) async {
      final apis = await tester.runAsync(twoDips);
      await _open(tester, apis!);
      var loans = find.byKey(const ValueKey('money-whole-loans'));
      await _scrollTo(tester, loans);
      expect(
        find.descendant(
          of: loans,
          matching: find.textContaining('دين عليك، من'),
        ),
        findsOneWidget,
      );

      final again = await tester.runAsync(twoDips);
      await _open(
        tester,
        again!,
        profile: JourneyProfile.of(
          planPersona: 'GROOM',
          readerFeminine: true,
          readerIsOwner: false,
        ),
      );
      loans = find.byKey(const ValueKey('money-whole-loans'));
      await _scrollTo(tester, loans);
      expect(
        find.descendant(
          of: loans,
          matching: find.textContaining('دين على العريس، من'),
        ),
        findsOneWidget,
      );
    });

    // D103, D105: the verdict «يكفي ... ويبقى» is the money in hand alone;
    // the estimates' «if» counts the dated promise too, and says so.
    testWidgets('the estimates\' «if» names the promise it counts', (
      tester,
    ) async {
      // Cash 1,100,000 (1,500,000 − 400,000 paid); 800,000 due on day 12
      // leaves 300,000. أبوي's 600,000 on day 30 makes it 900,000.
      Future<(FinanceApi, FundingApi)> plan(String photo) => _plan(
        items: [
          _hall,
          {
            'id': 'c-photo',
            'weddingPlanId': _planId,
            'name': 'التصوير',
            'estimatedAmount': photo,
          },
        ],
        costs: _hallCost,
        payments: _hallPaid,
        dates: [_date('s-next', 'k-hall', '800000', 12)],
        sources: [
          _source('f-save', 'SAVINGS', 'مدخراتي', '1500000'),
          _source(
            'f-father',
            'FAMILY_SUPPORT',
            'أبوي',
            '600000',
            pledged: true,
            expected: 30,
          ),
        ],
      );
      Future<String> ifLine() async {
        await tester.tap(find.text('من وين'));
        await tester.pumpAndSettle();
        final line = find.byKey(const ValueKey('money-sources-if'));
        await _scrollTo(tester, line);
        return tester.widget<Text>(line).data!;
      }

      // The photographer at 500,000: 900,000 − 500,000.
      await _open(tester, (await tester.runAsync(() => plan('500000')))!);
      expect(find.textContaining('ويبقى 300,000'), findsOneWidget);
      var words = await ifLine();
      expect(words, contains('يبقى معك 400,000'));
      expect(words, contains('لو وصل أبوي ('));
      expect(words, contains('في موعده'));

      // At 1,000,000: short by 100,000 even with the promise.
      await _open(tester, (await tester.runAsync(() => plan('1000000')))!);
      words = await ifLine();
      expect(words, contains('ينقصك 100,000'));
      expect(words, contains('حتى لو وصل أبوي ('));
    });

    // RA-BE-115: the money in hand covers everything, so no «ينقصك» is
    // raised for a promised loan whose repayment is set before it arrives.
    testWidgets('no shortfall beside a verdict that the money covers it', (
      tester,
    ) async {
      final summary = await tester.runAsync(() async {
        final apis = await _plan(
          costs: [_cost('k-hall', 'c-hall', 'قاعة الريان', '900')],
          dates: [_date('s-hall', 'k-hall', '900', 20)],
          sources: [
            _source('f-save', 'SAVINGS', 'مدخراتي', '1000'),
            _source(
              'f-loan',
              'LOAN',
              'سلفة من خالي',
              '300',
              pledged: true,
              expected: 30,
              repayments: [
                {
                  'id': 'r-early',
                  'amount': '300',
                  'dueDate': _day(25),
                  'status': 'PLANNED',
                },
              ],
            ),
          ],
        );
        return apis.$1.getMoneySummary(_planId);
      });
      expect(summary!.coverage?.verdict, MoneyCoverageVerdict.covered);
      expect(
        summary.warnings.where((w) => w.type == 'FUNDING_SHORTFALL'),
        isEmpty,
      );
      expect(summary.funding?.shortfall, isNull);
    });

    testWidgets('covered only if the promise arrives on its day', (
      tester,
    ) async {
      // Cash 500,000 (900,000 in, 400,000 paid on the hall): 200 (late,
      // today) → 700 (father, day 10) → 200 (day 12). Without the father:
      // −300,000 on day 12.
      final apis = await tester.runAsync(
        () => _plan(
          costs: _hallCost,
          payments: _hallPaid,
          dates: _hallDates,
          sources: [
            _source('f-save', 'SAVINGS', 'مدخراتي', '900000'),
            _source(
              'f-father',
              'FAMILY_SUPPORT',
              'أبوي',
              '500000',
              pledged: true,
              expected: 10,
            ),
          ],
        ),
      );
      await _open(tester, apis!);

      final cover = _coverText(tester);
      expect(cover, contains('يكفي بشرط يوصل موعود أبوي'));
      expect(cover, contains('بدونه ينقصك 300,000'));
      expect(cover, contains('(قاعة الريان)'));
    });

    testWidgets('covered: what is left after every date', (tester) async {
      final apis = await tester.runAsync(
        () => _plan(
          costs: _hallCost,
          payments: _hallPaid,
          dates: _hallDates,
          sources: [_source('f-save', 'SAVINGS', 'مدخراتي', '2000000')],
        ),
      );
      await _open(tester, apis!);

      final cover = _coverText(tester);
      // «معك» 1,600,000 (2,000,000 in, 400,000 paid), less 300,000 and
      // 500,000.
      expect(cover, contains('معك 1.6 مليون'));
      expect(cover, contains('يكفي دفعاتك بمواعيدها'));
      expect(cover, contains('ويبقى 800,000'));
      expect(find.byKey(const ValueKey('money-late-due')), findsOneWidget);
    });

    testWidgets('nothing left on him', (tester) async {
      final apis = await tester.runAsync(
        () => _plan(
          costs: [
            {..._hallCost.single, 'paidAmount': '1200000', 'status': 'PAID'},
          ],
          payments: [
            {..._hallPaid.single, 'amount': '1200000'},
          ],
          sources: [_source('f-save', 'SAVINGS', 'مدخراتي', '1500000')],
        ),
      );
      await _open(tester, apis!);

      expect(_coverText(tester), contains('ما عليك شي باقي، ومعك 300,000'));
      expect(find.byKey(const ValueKey('money-late-due')), findsNothing);
      expect(find.byKey(const ValueKey('money-coming-dues')), findsNothing);
    });

    testWidgets('first days: the steps, and no claim about cover', (
      tester,
    ) async {
      final apis = await tester.runAsync(() => _plan(budget: null));
      final screen = await _open(tester, apis!);
      // An empty plan opens on «البنود»; the summary is one tap away.
      await tester.tap(find.byKey(const ValueKey('journey-tab-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('money-cover-unknown')), findsOneWidget);
      expect(find.byKey(const ValueKey('money-cover')), findsNothing);
      await _scrollTo(tester, find.byKey(const ValueKey('money-first-steps')));
      expect(find.byKey(const ValueKey('money-first-steps')), findsOneWidget);
      // No source yet: «من وين» is its own page, not a tab.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-cover-unknown')));
      await tester.pumpAndSettle();
      expect(screen.location, AppRouter.moneyFunding(_planId));
    });

    testWidgets('more than three things to see: three, then «الكل»', (
      tester,
    ) async {
      // No budget; the father's promise is late; two items over their
      // share; the mahr has no date.
      final apis = await tester.runAsync(
        () => _plan(
          budget: null,
          items: const [
            {
              'id': 'c-a',
              'weddingPlanId': _planId,
              'name': 'الكوشة',
              'allocatedAmount': '100000',
            },
            {
              'id': 'c-b',
              'weddingPlanId': _planId,
              'name': 'الفستان',
              'allocatedAmount': '100000',
            },
            {
              'id': 'c-mahr',
              'weddingPlanId': _planId,
              'name': 'المهر',
              'kind': 'MAHR',
            },
          ],
          costs: [
            _cost('k-a', 'c-a', 'الكوشة', '200000'),
            _cost('k-b', 'c-b', 'الفستان', '300000'),
            _cost('k-mahr', 'c-mahr', 'المهر', '800000'),
          ],
          dates: [
            _date('s-a', 'k-a', '200000', 5),
            _date('s-b', 'k-b', '300000', 9),
          ],
          sources: [
            _source('f-save', 'SAVINGS', 'مدخراتي', '100000'),
            _source(
              'f-father',
              'FAMILY_SUPPORT',
              'أبوي',
              '500000',
              pledged: true,
              expected: -4,
            ),
          ],
        ),
      );
      await _open(tester, apis!);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('money-needs-attention')),
      );

      final box = find.byKey(const ValueKey('money-needs-attention'));
      Finder rows() => find.descendant(
        of: box,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'money-attention-',
              ),
        ),
      );
      expect(rows(), findsNWidgets(3));
      // The late promise leads.
      expect(
        find.byKey(const ValueKey('money-attention-pledge-f-father')),
        findsOneWidget,
      );
      final all = find.descendant(of: box, matching: find.text('الكل (5)'));
      expect(all, findsOneWidget);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(rows(), findsNWidgets(5));
      expect(
        find.byKey(const ValueKey('money-attention-no-budget')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('«أخفِ المبالغ» hides every figure on the summary', (
      tester,
    ) async {
      final apis = await tester.runAsync(twoDips);
      await _open(tester, apis!);
      final provider = tester
          .element(find.byType(MoneyOverviewScreen))
          .read<FinanceProvider>();
      provider.toggleAmountsVisibility();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('money-share-figure')))
            .data,
        '••••',
      );
      expect(find.textContaining('950,000'), findsNothing);
      expect(find.textContaining('300,000'), findsNothing);
    });
  });
}
