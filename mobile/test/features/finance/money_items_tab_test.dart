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
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// c02 «البنود» and c07 an item's page (D102, D105, D107, D109) on a plan kept
// on the phone: every figure from the phone's copy of the money rules, every
// sentence checked against the plan worked out by hand here.

const _planId = 'guest-plan-items-tab';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

String _day(int offset) {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day + offset).toIso8601String();
}

/// The plan: budget 3,000,000.
/// - Hall: share 1,200,000, estimate 1,300,000; agreed 1,200,000 for the
///   whole item, 400,000 paid; 300,000 three days late, 500,000 in 12 days.
/// - Photography: share 400,000, estimate 500,000; agreed 350,000 for a
///   part (300,000) of the estimate, due in 25 days.
/// - Gold: share 600,000, no estimate of its own.
/// - Cake: nothing.
/// Expected: hall 1,200,000 + photo 350,000 + (500,000 − 300,000) + gold
/// 600,000 = 2,350,000; agreed 1,550,000; estimates left 800,000; free
/// 650,000. The mahr (800,000) is outside the budget: recorded 3,150,000.
Future<FinanceProvider> _plan({
  String budget = '3000000',
  String? goldEstimate,
  String savings = '2000000',
}) async {
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
    totalBudget: budget,
    currency: 'YER',
    categories: [
      {
        'id': 'c-hall',
        'weddingPlanId': _planId,
        'name': 'القاعة',
        'allocatedAmount': '1200000',
        'estimatedAmount': '1300000',
      },
      {
        'id': 'c-photo',
        'weddingPlanId': _planId,
        'name': 'التصوير',
        'allocatedAmount': '400000',
        'estimatedAmount': '500000',
      },
      {
        'id': 'c-gold',
        'weddingPlanId': _planId,
        'name': 'الذهب',
        'allocatedAmount': '600000',
        'estimatedAmount': ?goldEstimate,
      },
      {'id': 'c-cake', 'weddingPlanId': _planId, 'name': 'الكيك'},
      {
        'id': 'c-mahr',
        'weddingPlanId': _planId,
        'name': 'المهر',
        'kind': 'MAHR',
        'allocatedAmount': '800000',
      },
    ],
  );
  Future<void> put(String table, Map<String, dynamic> json) => database
      .saveCachedItem(table: table, json: {...json, 'weddingPlanId': _planId});
  Map<String, dynamic> cost(
    String id,
    String item,
    String title,
    String total, {
    String paid = '0',
    String cover = 'WHOLE',
    String? part,
  }) => {
    'id': id,
    'budgetCategoryId': item,
    'title': title,
    'totalAmount': total,
    'paidAmount': paid,
    'status': paid == '0' ? 'PENDING' : 'PARTIALLY_PAID',
    'entryKind': 'AGREEMENT',
    'estimateCover': cover,
    'estimatePart': ?part,
    'createdAt': _day(-30),
  };
  await put(
    OfflineTables.cachedCosts,
    cost('k-hall', 'c-hall', 'قاعة الريان', '1200000', paid: '400000'),
  );
  await put(
    OfflineTables.cachedCosts,
    cost(
      'k-photo',
      'c-photo',
      'المصور',
      '350000',
      cover: 'PART',
      part: '300000',
    ),
  );
  await put(
    OfflineTables.cachedCosts,
    cost('k-mahr', 'c-mahr', 'المهر', '800000'),
  );
  await put(OfflineTables.cachedCostPayments, {
    'id': 'p-hall',
    'costId': 'k-hall',
    'amount': '400000',
    'entryType': 'PAYMENT',
    'paidAt': _day(-20),
  });
  for (final (id, costId, amount, day) in [
    ('s-late', 'k-hall', '300000', -3),
    ('s-next', 'k-hall', '500000', 12),
    ('s-photo', 'k-photo', '350000', 25),
  ]) {
    await put(OfflineTables.cachedPaymentSchedules, {
      'id': id,
      'costId': costId,
      'amount': amount,
      'status': 'PENDING',
      'dueDate': _day(day),
      'createdAt': _day(-30),
    });
  }
  await put(OfflineTables.cachedFundingSources, {
    'id': 'f-save',
    'kind': 'SAVINGS',
    'sourceName': 'مدخراتي',
    'amount': savings,
    'status': 'RECEIVED',
    'repayments': const [],
  });
  final provider = FinanceProvider(
    FinanceApi(
      _NoNetwork(),
      offline: offline,
      localPlanContextLoader: (_) async =>
          const LocalFinancePlanContext(currency: 'YER', persona: 'GROOM'),
    ),
  );
  return provider;
}

class _App {
  _App(this.router, this.provider);
  final GoRouter router;
  final FinanceProvider provider;
  String get location => router.state.uri.toString();
}

Future<_App> _open(
  WidgetTester tester,
  FinanceProvider provider, {
  String? at,
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  Widget elsewhere(GoRouterState state) => Scaffold(
    body: Text(state.uri.toString(), key: const ValueKey('elsewhere')),
  );
  final router = GoRouter(
    initialLocation: at ?? AppRouter.money(_planId),
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (_, _) => const MoneyOverviewScreen(
          weddingPlanId: _planId,
          personaCode: 'groom',
        ),
        routes: [
          GoRoute(
            path: 'categories/:categoryId',
            builder: (_, state) => BudgetCategoryDetailsScreen(
              weddingPlanId: _planId,
              categoryId: state.pathParameters['categoryId']!,
            ),
          ),
          GoRoute(
            path: 'costs/create',
            builder: (_, state) => CostFormScreen(
              weddingPlanId: _planId,
              initialCategoryId: state.uri.queryParameters['categoryId'],
              expense: state.uri.queryParameters['kind'] == 'expense',
            ),
          ),
          for (final path in const [
            'costs/:costId/payments/create',
            'costs/:costId/schedules/:scheduleId/pay',
            'costs/:costId',
            'payments/:paymentId',
            'budget',
            'funding',
            'categories/create',
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
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return _App(router, provider);
}

/// The store answers off the test clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> _items(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
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

/// All a widget says, as one line.
String _said(WidgetTester tester, Finder of) => [
  for (final text in tester.widgetList<RichText>(
    find.descendant(of: of, matching: find.byType(RichText)),
  ))
    text.text.toPlainText(),
].join(' ');

void main() {
  group('«البنود»', () {
    testWidgets('the budget against the items: agreed, estimates, free', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      await _open(tester, provider!);
      await _items(tester);

      final box = find.byKey(const ValueKey('money-items-budget'));
      final said = _said(tester, box);
      expect(said, contains('3 مليون'));
      expect(said, contains('اتفاقات 1.6 مليون')); // 1,550,000
      expect(said, contains('تقديرات 800,000'));
      expect(said, contains('متاح 650,000'));
      expect(said, contains('تحت الميزانية بـ650,000'));

      final cost = find.byKey(const ValueKey('money-items-cost'));
      // 2,350,000 + the mahr's 800,000.
      expect(_said(tester, cost), contains('3.2 مليون'));
      expect(_said(tester, cost), contains('مو نهائية'));
      expect(_said(tester, cost), contains('بند واحد ما له تقدير'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('over the budget by the estimates: said everywhere alike', (
      tester,
    ) async {
      // Gold estimated at 1,500,000: expected 1,200,000 + 550,000 +
      // 1,500,000 = 3,250,000 over the 3,000,000 budget, while what is
      // agreed is under it. His money covers what is on him.
      final provider = await tester.runAsync(
        () => _plan(goldEstimate: '1500000', savings: '3000000'),
      );
      await _open(tester, provider!);
      await _items(tester);

      expect(
        _said(tester, find.byKey(const ValueKey('money-items-budget'))),
        contains('فوق الميزانية بـ250,000'),
      );
      // The line under «المال» holds the same rule (D105), not the
      // agreements alone.
      expect(find.text('فوق الميزانية'), findsOneWidget);
      expect(find.text('في حدود الميزانية'), findsNothing);
    });

    testWidgets('each item once: what is left, when, against its estimate', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      final app = await _open(tester, provider!);
      await _items(tester);

      final hall = find.byKey(const ValueKey('money-item-c-hall'));
      await _show(tester, hall);
      expect(_said(tester, hall), contains('قاعة الريان'));
      expect(_said(tester, hall), contains('باقي'));
      expect(_said(tester, hall), contains('800,000'));
      expect(_said(tester, hall), contains('متأخرة'));
      expect(_said(tester, hall), contains('أقل من تقديرك بـ100,000'));

      final photo = find.byKey(const ValueKey('money-item-c-photo'));
      await _show(tester, photo);
      expect(_said(tester, photo), contains('الجاية'));
      expect(_said(tester, photo), contains('أقل من تقديرك بـ150,000'));

      final gold = find.byKey(const ValueKey('money-item-category-c-gold'));
      await _show(tester, gold);
      expect(
        find.descendant(of: gold, matching: find.text('المخصص')),
        findsOneWidget,
      );
      final cake = find.byKey(const ValueKey('money-item-category-c-cake'));
      expect(
        find.descendant(of: cake, matching: find.text('بدون تقدير')),
        findsOneWidget,
      );

      // «ما اتفقت» shows only the items still at their estimate.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await _show(
        tester,
        find.byKey(const ValueKey('money-items-filter-open')),
      );
      await tester.tap(find.byKey(const ValueKey('money-items-filter-open')));
      await tester.pumpAndSettle();
      expect(hall, findsNothing);
      expect(find.byKey(const ValueKey('money-mahr-section')), findsNothing);
      await _show(tester, gold);
      expect(gold, findsOneWidget);

      await tester.tap(gold);
      await tester.pumpAndSettle();
      expect(app.location, AppRouter.moneyCategoryDetails(_planId, 'c-gold'));
    });

    testWidgets('«ايش الفرق؟» says the four words', (tester) async {
      final provider = await tester.runAsync(_plan);
      await _open(tester, provider!);
      await _items(tester);
      await _show(tester, find.byKey(const ValueKey('money-items-explain')));
      await tester.tap(find.byKey(const ValueKey('money-items-explain')));
      await tester.pumpAndSettle();
      for (final word in ['البند', 'التقدير', 'الاتفاق', 'المصروف']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
    });
  });

  group('an item\'s page', () {
    testWidgets('a part agreement: what is left of the estimate still counts', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      await _open(
        tester,
        provider!,
        at: AppRouter.moneyCategoryDetails(_planId, 'c-photo'),
      );

      final glance = find.byKey(const ValueKey('item-glance'));
      expect(_said(tester, glance), contains('500,000')); // his estimate
      expect(_said(tester, glance), contains('350,000')); // agreed, left
      // Its share is said apart from its own estimate (D109).
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('item-share'))).data,
        contains('400,000'),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('item-against-estimate')))
            .data,
        allOf(contains('أقل من تقديرك بـ150,000'), contains('(200,000')),
      );
      // Expected 550,000 against its 400,000 share; the reserve (the
      // budget not shared out: 3,000,000 − 3,000,000 shared) cannot cover
      // it, and the wedding is under the budget, so it says so.
      expect(find.byKey(const ValueKey('category-over')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('category-over-unshared')),
        findsNothing,
      );
      expect(find.textContaining('ومجموع العرس تحت الميزانية'), findsOneWidget);
      expect(find.textContaining('يطلع فوق الميزانية'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pay: a late date, or the one agreement with something left', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      final app = await _open(
        tester,
        provider!,
        at: AppRouter.moneyCategoryDetails(_planId, 'c-hall'),
      );

      await tester.tap(find.byKey(const ValueKey('item-pay')));
      await tester.pumpAndSettle();
      expect(app.location, AppRouter.moneyPaymentCreate(_planId, 'k-hall'));
      app.router.pop();
      await tester.pumpAndSettle();

      final late = find.byKey(const ValueKey('item-due-s-late'));
      await _show(tester, late);
      expect(_said(tester, late), contains('متأخرة'));
      await tester.tap(late);
      await tester.pumpAndSettle();
      expect(
        app.location,
        AppRouter.moneySchedulePay(_planId, 'k-hall', 's-late'),
      );
      app.router.pop();
      await tester.pumpAndSettle();

      final paid = find.byKey(const ValueKey('item-payment-p-hall'));
      await _show(tester, paid);
      expect(_said(tester, paid), contains('400,000'));
    });

    testWidgets('an estimate of its own: free, may pass the budget', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      await _open(
        tester,
        provider!,
        at: AppRouter.moneyCategoryDetails(_planId, 'c-gold'),
      );
      expect(find.text('المخصص له'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('item-estimate')));
      await tester.pumpAndSettle();
      // Others expect 1,750,000; with 1,500,000 the items pass 3,000,000
      // by 250,000: said under the field, not refused.
      await tester.enterText(
        find.byKey(const ValueKey('item-estimate-field')),
        '1500000',
      );
      await tester.pump();
      expect(find.textContaining('فوق الميزانية بـ250,000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('item-estimate-save')));
      await _settle(tester);

      final gold = provider.summary.categories.singleWhere(
        (item) => item.categoryId == 'c-gold',
      );
      expect(gold.estimateFromAllocation, isFalse);
      expect(moneyValue(gold.expectedCost), 1500000);
      // Its share stays.
      expect(
        moneyValue(provider.categoryById('c-gold')!.allocatedAmount),
        600000,
      );
      expect(find.text('تقديرك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('over its share: from the reserve when it covers it', (
      tester,
    ) async {
      // Budget 3,500,000: 500,000 not shared out covers the 150,000.
      final provider = await tester.runAsync(() => _plan(budget: '3500000'));
      await _open(
        tester,
        provider!,
        at: AppRouter.moneyCategoryDetails(_planId, 'c-photo'),
      );
      final reserve = find.byKey(const ValueKey('category-over-unshared'));
      await _show(tester, reserve);
      expect(find.textContaining('ويبقى الاحتياط 350,000'), findsOneWidget);
      await tester.tap(reserve);
      await _settle(tester);

      expect(
        moneyValue(provider.categoryById('c-photo')!.allocatedAmount),
        550000,
      );
      expect(moneyValue(provider.summary.budget.total), 3500000);
      expect(find.byKey(const ValueKey('category-over')), findsNothing);
    });
  });

  group('an expense and an agreement (D105, D107)', () {
    testWidgets('an expense where an agreement is open asks first', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      final app = await _open(
        tester,
        provider!,
        at: AppRouter.moneyCategoryDetails(_planId, 'c-hall'),
      );
      await _show(tester, find.byKey(const ValueKey('item-expense')));
      await tester.tap(find.byKey(const ValueKey('item-expense')));
      await tester.pumpAndSettle();
      expect(find.text('مصروف بدون اتفاق'), findsOneWidget);
      // The mahr has its own way, never an expense (C1).
      expect(find.text('المهر'), findsNothing);
      // Paid in full the day it is recorded: no plan.
      expect(find.text('كيف بتدفع؟'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cost-total-amount')),
        '50000',
      );
      await tester.pump();
      final guard = find.byKey(const ValueKey('cost-guard-open-agreement'));
      await _show(tester, guard);
      expect(_said(tester, guard), contains('قاعة الريان'));
      expect(_said(tester, guard), contains('800,000'));

      // Not answered: nothing is saved.
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await _settle(tester);
      expect(provider.costs.where((cost) => cost.isExpense), isEmpty);

      await _show(tester, find.byKey(const ValueKey('cost-guard-separate')));
      await tester.tap(find.byKey(const ValueKey('cost-guard-separate')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await _settle(tester);

      final expense = provider.costs.singleWhere((cost) => cost.isExpense);
      expect(expense.budgetCategoryId, 'c-hall');
      expect(moneyValue(expense.paidAmount), 50000);
      expect(moneyValue(expense.remainingAmount), 0);
      expect(app.location, AppRouter.moneyCategoryDetails(_planId, 'c-hall'));
    });

    testWidgets('the payment goes on the agreement instead', (tester) async {
      final provider = await tester.runAsync(_plan);
      final app = await _open(
        tester,
        provider!,
        at: AppRouter.moneyCostCreate(
          _planId,
          categoryId: 'c-hall',
          expense: true,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('cost-total-amount')),
        '300000',
      );
      await tester.pump();
      await _show(
        tester,
        find.byKey(const ValueKey('cost-guard-pay-agreement')),
      );
      await tester.tap(find.byKey(const ValueKey('cost-guard-pay-agreement')));
      await tester.pumpAndSettle();
      expect(app.location, AppRouter.moneyPaymentCreate(_planId, 'k-hall'));
      expect(provider.costs.where((cost) => cost.isExpense), isEmpty);
    });

    testWidgets('an agreement for part of the estimate keeps the rest', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      await _open(
        tester,
        provider!,
        at: AppRouter.moneyCostCreate(_planId, categoryId: 'c-gold'),
      );
      await tester.enterText(
        find.byKey(const Key('cost-total-amount')),
        '400000',
      );
      await tester.pump();
      await _show(tester, find.byKey(const ValueKey('cost-cover-part')));
      // Whole by default: the agreement takes the estimate's place.
      expect(find.textContaining('التقدير يسقط'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cost-cover-part')));
      await tester.pump();
      // Its share is 600,000 and it covers 400,000 of it.
      expect(find.textContaining('يبقى من التقدير 200,000'), findsOneWidget);
      await _show(tester, find.byKey(const ValueKey('cost-save')));
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await _settle(tester);

      final gold = provider.summary.categories.singleWhere(
        (item) => item.categoryId == 'c-gold',
      );
      // 400,000 + (600,000 − 400,000).
      expect(moneyValue(gold.expectedCost), 600000);
      final cost = provider.costs.singleWhere(
        (cost) => cost.budgetCategoryId == 'c-gold',
      );
      expect(cost.estimateCover, 'PART');
    });

    testWidgets('the same amount in the same item today asks first', (
      tester,
    ) async {
      final provider = await tester.runAsync(_plan);
      await _open(
        tester,
        provider!,
        at: AppRouter.moneyCostCreate(_planId, categoryId: 'c-cake'),
      );
      Future<void> agree() async {
        await tester.enterText(
          find.byKey(const Key('cost-total-amount')),
          '90000',
        );
        await tester.pump();
        await _show(tester, find.byKey(const ValueKey('cost-save')));
        await tester.tap(find.byKey(const ValueKey('cost-save')));
        await _settle(tester);
      }

      await agree();
      expect(
        provider.costs.where((c) => c.budgetCategoryId == 'c-cake'),
        hasLength(1),
      );
      // Again, the same: asked, not saved.
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(AppRouter.moneyCostCreate(_planId, categoryId: 'c-cake'));
      await _settle(tester);
      await agree();
      final guard = find.byKey(const ValueKey('cost-guard-same-today'));
      await _show(tester, guard);
      expect(guard, findsOneWidget);
      expect(
        provider.costs.where((c) => c.budgetCategoryId == 'c-cake'),
        hasLength(1),
      );
      await _show(tester, find.byKey(const ValueKey('cost-guard-again')));
      await tester.tap(find.byKey(const ValueKey('cost-guard-again')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await _settle(tester);
      expect(
        provider.costs.where((c) => c.budgetCategoryId == 'c-cake'),
        hasLength(2),
      );
    });
  });

  test('the theme the screens use exists', () {
    expect(AarastV3Color.amberSoft, isNotNull);
  });
}
