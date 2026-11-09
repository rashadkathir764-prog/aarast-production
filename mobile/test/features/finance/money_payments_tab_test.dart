import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/cost_payment_screens.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// c03 «الدفعات» (D102, D106) on a plan kept on the phone: the dates as a plan
// in time, whose they are, the loans apart, what was paid, and a date's own
// flows (pay less or more, agree a new day).

const _planId = 'guest-plan-payments-tab';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

String _day(int offset) {
  final today = sanaaToday();
  return DateTime.utc(
    today.year,
    today.month,
    today.day + offset,
  ).toIso8601String();
}

/// The hall: 1,200,000, 400,000 paid (100,000 of it towards the next date):
/// 300,000 three days late, 400,000 of 500,000 in 12 days, and the 100,000
/// left beyond its dates with no date. The photographer: 350,000 in 25 days, paid by the father. The mahr:
/// 800,000 with no date. A loan of 400,000: 200,000 back in 60 and in 120
/// days. An old payment of 50,000, taken back.
Future<FinanceProvider> _plan() async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: _NoNetwork(),
  );
  await offline.initialize();
  await FinanceLocalDataSource(offline).saveBudget(
    planId: _planId,
    totalBudget: '3000000',
    currency: 'YER',
    categories: const [
      {'id': 'c-hall', 'weddingPlanId': _planId, 'name': 'القاعة'},
      {'id': 'c-photo', 'weddingPlanId': _planId, 'name': 'التصوير'},
      {
        'id': 'c-mahr',
        'weddingPlanId': _planId,
        'name': 'المهر',
        'kind': 'MAHR',
      },
    ],
  );
  Future<void> put(String table, Map<String, dynamic> json) => database
      .saveCachedItem(table: table, json: {...json, 'weddingPlanId': _planId});
  Map<String, dynamic> cost(
    String id,
    String item,
    String title,
    String total,
    String paid, {
    String? payer,
    String? payerName,
  }) => {
    'id': id,
    'budgetCategoryId': item,
    'title': title,
    'totalAmount': total,
    'paidAmount': paid,
    'status': paid == '0' ? 'PENDING' : 'PARTIALLY_PAID',
    'entryKind': 'AGREEMENT',
    'estimateCover': 'WHOLE',
    'payer': ?payer,
    'payerName': ?payerName,
    'createdAt': _day(-40),
  };
  await put(
    OfflineTables.cachedCosts,
    cost('k-hall', 'c-hall', 'قاعة الريان', '1200000', '400000'),
  );
  await put(
    OfflineTables.cachedCosts,
    cost(
      'k-photo',
      'c-photo',
      'المصور',
      '350000',
      '0',
      payer: 'FAMILY',
      payerName: 'أبوي',
    ),
  );
  await put(
    OfflineTables.cachedCosts,
    cost('k-mahr', 'c-mahr', 'المهر', '800000', '0'),
  );
  for (final payment in [
    {'id': 'p-1', 'amount': '300000', 'paidAt': _day(-20)},
    {
      'id': 'p-2',
      'amount': '100000',
      'paidAt': _day(-2),
      'lowersScheduleId': 's-next',
    },
    {
      'id': 'p-old',
      'amount': '50000',
      'paidAt': _day(-30),
      'reversedById': 'p-rev',
    },
    {
      'id': 'p-rev',
      'amount': '50000',
      'paidAt': _day(-29),
      'entryType': 'REVERSAL',
      'reversalOfId': 'p-old',
    },
  ]) {
    await put(OfflineTables.cachedCostPayments, {
      'costId': 'k-hall',
      'entryType': 'PAYMENT',
      ...payment,
    });
  }
  for (final (id, costId, amount, day) in [
    ('s-late', 'k-hall', '300000', -3),
    ('s-next', 'k-hall', '400000', 12),
    ('s-photo', 'k-photo', '350000', 25),
  ]) {
    await put(OfflineTables.cachedPaymentSchedules, {
      'id': id,
      'costId': costId,
      'amount': amount,
      'status': 'PENDING',
      'dueDate': _day(day),
      'createdAt': _day(-40),
    });
  }
  for (final source in [
    {
      'id': 'f-save',
      'kind': 'SAVINGS',
      'sourceName': 'مدخراتي',
      'amount': '2000000',
      'status': 'RECEIVED',
      'repayments': const [],
    },
    {
      'id': 'f-loan',
      'kind': 'LOAN',
      'sourceName': 'سلفة من خالي',
      'amount': '400000',
      'status': 'RECEIVED',
      'repayments': [
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
    },
  ]) {
    await put(OfflineTables.cachedFundingSources, source);
  }
  return FinanceProvider(
    FinanceApi(
      _NoNetwork(),
      offline: offline,
      localPlanContextLoader: (_) async =>
          const LocalFinancePlanContext(currency: 'YER', persona: 'GROOM'),
    ),
  );
}

class _App {
  _App(this.router);
  final GoRouter router;
  String get location => router.state.uri.toString();
}

Future<_App> _open(WidgetTester tester, FinanceProvider provider) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
          GoRoute(
            path: 'costs/:costId/schedules/:scheduleId/pay',
            builder: (_, state) => PayPaymentScheduleScreen(
              weddingPlanId: _planId,
              costId: state.pathParameters['costId']!,
              scheduleId: state.pathParameters['scheduleId']!,
            ),
          ),
          for (final path in const [
            'costs/:costId',
            'payments/:paymentId',
            'funding',
            'payers',
            'costs/create',
          ])
            GoRoute(
              path: path,
              builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(
          create: (_) => FundingProvider(FundingApi(_NoNetwork())),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return _App(router);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> _payments(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('journey-tab-2')));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

String _said(WidgetTester tester, Finder of) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: of, matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
].join(' ');

void main() {
  testWidgets('a plan in time: late, by month, no date; the loans apart', (
    tester,
  ) async {
    final provider = await tester.runAsync(_plan);
    await _open(tester, provider!);
    await _payments(tester);

    // 300,000 + 400,000 + 350,000 + 100,000 (hall, no date) + 800,000 =
    // 1,950,000, a half rounded up.
    final total = find.byKey(const ValueKey('money-due-total'));
    expect(_said(tester, total), contains('2 مليون'));
    expect(_said(tester, total), contains('5 دفعات'));
    expect(_said(tester, total), contains('منها متأخر 300,000'));

    final late = find.byKey(const ValueKey('money-due-late'));
    expect(
      find.descendant(
        of: late,
        matching: find.byKey(const ValueKey('money-due-s-late')),
      ),
      findsOneWidget,
    );
    // The partly paid date says so.
    final next = find.byKey(const ValueKey('money-due-s-next'));
    await _show(tester, next);
    expect(_said(tester, next), contains('اندفع 100,000'));
    expect(_said(tester, next), contains('من 500,000'));

    final undated = find.byKey(const ValueKey('money-due-undated'));
    await _show(tester, undated);
    expect(_said(tester, undated), contains('المهر'));
    expect(_said(tester, undated), contains('قاعة الريان'));

    // The loan: its own block, said to be a debt and not a wedding cost.
    final loan = find.byKey(const ValueKey('money-loan-f-loan'));
    await _show(tester, loan);
    expect(find.textContaining('مو من تكاليف العرس'), findsOneWidget);
    expect(
      find.descendant(of: total, matching: find.textContaining('400,000')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('whose: the father\'s date apart from his own', (tester) async {
    final provider = await tester.runAsync(_plan);
    await _open(tester, provider!);
    await _payments(tester);

    await tester.tap(find.byKey(const ValueKey('money-pay-who-FAMILY|أبوي')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-due-s-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('money-due-s-late')), findsNothing);
    // A loan is his debt, not the father's.
    expect(find.byKey(const ValueKey('money-loan-f-loan')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('money-pay-who-owner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-due-s-photo')), findsNothing);
    expect(find.byKey(const ValueKey('money-due-s-late')), findsOneWidget);
  });

  testWidgets('a date opens its pay page; what has no date, its agreement', (
    tester,
  ) async {
    final provider = await tester.runAsync(_plan);
    final app = await _open(tester, provider!);
    await _payments(tester);

    await _show(tester, find.byKey(const ValueKey('money-due-pay-s-late')));
    await tester.tap(find.byKey(const ValueKey('money-due-pay-s-late')));
    await _settle(tester);
    expect(
      app.location,
      AppRouter.moneySchedulePay(_planId, 'k-hall', 's-late'),
    );
    app.router.pop();
    await tester.pumpAndSettle();

    final undated = find.byKey(const ValueKey('money-due-k-mahr'));
    await _show(tester, undated);
    expect(find.byKey(const ValueKey('money-due-pay-k-mahr')), findsNothing);
    await tester.tap(undated);
    await tester.pumpAndSettle();
    expect(app.location, AppRouter.moneyCostDetails(_planId, 'k-mahr'));
  });

  testWidgets('paying less lowers the date, on its own page', (tester) async {
    final provider = await tester.runAsync(_plan);
    final app = await _open(tester, provider!);
    await _payments(tester);
    await _show(tester, find.byKey(const ValueKey('money-due-pay-s-late')));
    await tester.tap(find.byKey(const ValueKey('money-due-pay-s-late')));
    await _settle(tester);

    await tester.enterText(
      find.byKey(const Key('cost-payment-amount')),
      '100000',
    );
    await tester.pump();
    expect(find.textContaining('ويبقى عليه 200,000'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('payment-save')));
    await tester.tap(find.byKey(const ValueKey('payment-save')));
    await _settle(tester);

    final late = provider.summary.obligations.singleWhere(
      (line) => line.id == 's-late',
    );
    expect(moneyValue(late.amount), 200000);
    expect(moneyValue(late.paidTowards), 100000);
    expect(app.location, isNot(contains('/pay')));
  });

  testWidgets('a new day agreed from the late card: no longer late', (
    tester,
  ) async {
    final provider = await tester.runAsync(_plan);
    await _open(tester, provider!);

    await tester.tap(find.byKey(const ValueKey('money-late-move')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('money-move-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('money-move-week')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('money-move-save')));
    await _settle(tester);

    final late = provider.summary.obligations.singleWhere(
      (line) => line.id == 's-late',
    );
    expect(late.isOverdue, isFalse);
    expect(
      planDayToJson(late.rescheduledFrom!),
      planDayToJson(DateTime.parse(_day(-3))),
    );
    expect(find.byKey(const ValueKey('money-late-due')), findsNothing);
  });

  testWidgets('what was paid, newest first; a reversed one struck', (
    tester,
  ) async {
    final provider = await tester.runAsync(_plan);
    await _open(tester, provider!);
    await _payments(tester);
    await tester.tap(find.byKey(const ValueKey('money-pay-done')));
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('money-paid-list'));
    expect(list, findsOneWidget);
    // The reversal itself is not a payment of its own.
    expect(find.byKey(const ValueKey('money-paid-p-rev')), findsNothing);
    final old = find.byKey(const ValueKey('money-paid-p-old'));
    await _show(tester, old);
    expect(_said(tester, old), contains('انعكست'));
    final p2 = tester
        .getTopLeft(find.byKey(const ValueKey('money-paid-p-2')))
        .dy;
    final p1 = tester
        .getTopLeft(find.byKey(const ValueKey('money-paid-p-1')))
        .dy;
    expect(p2, lessThan(p1));
    // 300,000 + 100,000; the reversed 50,000 does not count.
    expect(find.textContaining('400,000'), findsWidgets);
  });
}
