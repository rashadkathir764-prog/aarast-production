// Captures today's real money screens for the groom before/after review.
//   flutter test test/prototype/now_money/now_money_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_status_widgets.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/core/offline/local_database_contract.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/cost_draft_intent.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_payment_screens.dart';
import 'package:aarast_mobile/features/finance/screens/costs_screen.dart';
import 'package:aarast_mobile/features/finance/screens/funding_sources_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/screens/payment_schedule_screens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

const _plan = 'plan-mohammed-salma';

enum _Mode { full, noBudget, empty, exceeded }

Future<void> _shot(
  WidgetTester tester,
  String name,
  String location, {
  _Mode mode = _Mode.full,
  double h = 844,
  bool offline = false,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final client = ApiClient(tokenProvider: () async => null);
  client.dio.httpClientAdapter = _EmptyListAdapter();
  final api = _Api(mode);
  final finance = FinanceProvider(api);
  final funding = FundingProvider(_Funding());
  final sync = _OfflineSync(JsonLocalDatabase(prefs), client, offline);
  final router = _router(location, offline: offline);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider<FinanceProvider>.value(value: finance),
        ChangeNotifierProvider<FundingProvider>.value(value: funding),
        ChangeNotifierProvider<OfflineSyncService>.value(value: sync),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

GoRouter _router(String initial, {bool offline = false}) {
  String id(GoRouterState s) => s.pathParameters['id']!;
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (c, s) {
          final screen = MoneyOverviewScreen(
            weddingPlanId: id(s),
            personaCode: 'GROOM',
          );
          if (!offline) return screen;
          // The real shell puts the sync banner above the plan tabs.
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const OfflineStatusBanner(),
                  Expanded(child: screen),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/budget',
        builder: (c, s) => MoneyBudgetScreen(weddingPlanId: id(s)),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/funding',
        builder: (c, s) => FundingSourcesScreen(weddingPlanId: id(s)),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/schedules',
        builder: (c, s) => PaymentSchedulesScreen(
          weddingPlanId: id(s),
          costId: s.uri.queryParameters['costId'],
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/categories/create',
        builder: (c, s) => BudgetCategoryFormScreen(weddingPlanId: id(s)),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/categories/:categoryId',
        builder: (c, s) => BudgetCategoryDetailsScreen(
          weddingPlanId: id(s),
          categoryId: s.pathParameters['categoryId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs',
        builder: (c, s) => CostsScreen(weddingPlanId: id(s)),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/create',
        builder: (c, s) => CostFormScreen(
          weddingPlanId: id(s),
          intent: s.extra is CostDraftIntent ? s.extra! as CostDraftIntent : null,
          initialCategoryId: s.uri.queryParameters['categoryId'],
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/payments/create',
        builder: (c, s) => RecordCostPaymentScreen(
          weddingPlanId: id(s),
          costId: s.pathParameters['costId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/payments/:paymentId',
        builder: (c, s) => CostPaymentDetailsScreen(
          weddingPlanId: id(s),
          costId: s.uri.queryParameters['costId'],
          paymentId: s.pathParameters['paymentId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/create',
        builder: (c, s) => PaymentScheduleFormScreen(
          weddingPlanId: id(s),
          costId: s.pathParameters['costId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/pay',
        builder: (c, s) => PayPaymentScheduleScreen(
          weddingPlanId: id(s),
          costId: s.pathParameters['costId']!,
          scheduleId: s.pathParameters['scheduleId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
        builder: (c, s) => PaymentScheduleDetailsScreen(
          weddingPlanId: id(s),
          costId: s.pathParameters['costId']!,
          scheduleId: s.pathParameters['scheduleId']!,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId',
        builder: (c, s) => CostDetailsScreen(
          weddingPlanId: id(s),
          costId: s.pathParameters['costId']!,
        ),
      ),
    ],
  );
}

const _m = '/wedding-plans/$_plan/money';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('m01 overview', (t) => _shot(t, 'm01_overview', _m, h: 1700));
  testWidgets(
    'm02 overview exceeded',
    (t) => _shot(t, 'm02_overview_exceeded', _m, mode: _Mode.exceeded, h: 1100),
  );
  testWidgets(
    'm03 overview no budget',
    (t) => _shot(t, 'm03_overview_no_budget', _m, mode: _Mode.noBudget, h: 1500),
  );
  testWidgets(
    'm04 starter',
    (t) => _shot(t, 'm04_starter', _m, mode: _Mode.empty, h: 1700),
  );
  testWidgets('m05 share', (t) async {
    await _shot(
      t,
      'm05_share',
      _m,
      h: 1000,
      act: () async {
        final share = find.byKey(const Key('money-share-summary'));
        await t.ensureVisible(share);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(share);
        await t.pump(const Duration(milliseconds: 800));
      },
    );
  });
  testWidgets(
    'm06 offline',
    (t) => _shot(t, 'm06_offline', _m, offline: true, h: 1100),
  );
  testWidgets(
    'm07 budget',
    (t) => _shot(t, 'm07_budget', '$_m/budget', h: 1700),
  );
  testWidgets(
    'm08 category',
    (t) => _shot(t, 'm08_category', '$_m/categories/cat-photo', h: 1300),
  );
  testWidgets(
    'm09 category form',
    (t) => _shot(t, 'm09_category_form', '$_m/categories/create'),
  );
  testWidgets('m10 costs', (t) => _shot(t, 'm10_costs', '$_m/costs', h: 1300));
  testWidgets('m11 costs filter', (t) async {
    await _shot(
      t,
      'm11_costs_filter',
      '$_m/costs',
      h: 1000,
      act: () async {
        await t.tap(find.textContaining('تصفية').first);
        await t.pump(const Duration(milliseconds: 800));
      },
    );
  });
  testWidgets(
    'm12 cost detail',
    (t) => _shot(t, 'm12_cost_detail', '$_m/costs/cost-hall', h: 1900),
  );
  testWidgets('m13 cost menu', (t) async {
    await _shot(
      t,
      'm13_cost_menu',
      '$_m/costs/cost-photo',
      act: () async {
        await t.tap(find.byTooltip('المزيد'));
        await t.pump(const Duration(milliseconds: 600));
      },
    );
  });
  testWidgets(
    'm14 cost form',
    (t) => _shot(t, 'm14_cost_form', '$_m/costs/create', h: 1700),
  );
  testWidgets(
    'm15 record payment',
    (t) => _shot(
      t,
      'm15_record_payment',
      '$_m/costs/cost-hall/payments/create',
      h: 1300,
    ),
  );
  testWidgets(
    'm16 payment detail',
    (t) => _shot(
      t,
      'm16_payment_detail',
      '$_m/payments/pay-hall-1?costId=cost-hall',
      h: 1200,
    ),
  );
  testWidgets('m17 payment reverse', (t) async {
    await _shot(
      t,
      'm17_payment_reverse',
      '$_m/payments/pay-hall-1?costId=cost-hall',
      act: () async {
        final btn = find.text('عكس الدفعة');
        await t.ensureVisible(btn);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(btn);
        await t.pump(const Duration(milliseconds: 600));
      },
    );
  });
  testWidgets(
    'm18 schedules',
    (t) => _shot(t, 'm18_schedules', '$_m/schedules', h: 1300),
  );
  testWidgets(
    'm19 schedule pay',
    (t) => _shot(
      t,
      'm19_schedule_pay',
      '$_m/costs/cost-hall/schedules/sch-hall-2/pay',
      h: 1100,
    ),
  );
  testWidgets(
    'm20 schedule form',
    (t) => _shot(
      t,
      'm20_schedule_form',
      '$_m/costs/cost-hall/schedules/create',
      h: 1000,
    ),
  );
  testWidgets(
    'm21 funding',
    (t) => _shot(t, 'm21_funding', '$_m/funding', h: 1200),
  );
  testWidgets('m22 funding add', (t) async {
    await _shot(
      t,
      'm22_funding_add',
      '$_m/funding',
      h: 1100,
      act: () async {
        await t.tap(find.byKey(const ValueKey('funding-add')));
        await t.pump(const Duration(milliseconds: 800));
      },
    );
  });
  testWidgets('m23 loan', (t) async {
    await _shot(
      t,
      'm23_loan',
      '$_m/funding',
      h: 1100,
      act: () async {
        await t.tap(find.byKey(const ValueKey('funding-row-src-loan')));
        await t.pump(const Duration(milliseconds: 800));
      },
    );
  });
}

// ---------- seed: «عرس محمد وسلمى», Sana'a, wedding 2027-01-21 ----------

final _d = DateTime(2026, 10, 20, 12);

const _cats = <(String, String, String, String, String, int)>[
  // id, name, allocated, confirmed cost, paid, costs count
  ('cat-hall', 'القاعة', '2500000', '2200000', '1000000', 1),
  ('cat-photo', 'التصوير', '600000', '650000', '200000', 1),
  ('cat-gold', 'الذهب والشبكة', '1500000', '1400000', '1400000', 1),
  ('cat-kiswa', 'الكسوة', '500000', '0', '0', 0),
  ('cat-food', 'الوليمة والذبائح', '1200000', '0', '0', 0),
];

class _Api extends FinanceApi {
  _Api(this.mode) : super(ApiClient(tokenProvider: () async => null));

  final _Mode mode;

  bool get _empty => mode == _Mode.empty;

  List<WeddingCost> get _costs => [
    WeddingCost(
      id: 'cost-hall',
      weddingPlanId: _plan,
      budgetCategoryId: 'cat-hall',
      categoryName: 'القاعة',
      title: 'قاعة ليالي صنعاء',
      totalAmount: '2200000',
      paidAmount: '1000000',
      remainingAmount: '1200000',
      status: 'PARTIALLY_PAID',
      providerId: 'prov-hall',
      providerName: 'قاعة ليالي صنعاء',
      payer: 'GROOM',
      agreementDate: DateTime(2026, 8, 10),
      note: 'ليلة الخميس 21 يناير، مع الإضاءة.',
      paymentsCount: 1,
      createdAt: DateTime(2026, 8, 10),
      updatedAt: _d,
    ),
    WeddingCost(
      id: 'cost-photo',
      weddingPlanId: _plan,
      budgetCategoryId: 'cat-photo',
      categoryName: 'التصوير',
      title: 'تصوير فيديو وفوتو',
      totalAmount: '650000',
      paidAmount: '200000',
      remainingAmount: '450000',
      status: 'PARTIALLY_PAID',
      partyName: 'استوديو الضوء',
      partyPhone: '777123456',
      payer: 'GROOM',
      agreementDate: DateTime(2026, 9, 1),
      paymentsCount: 1,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: _d,
    ),
    WeddingCost(
      id: 'cost-gold',
      weddingPlanId: _plan,
      budgetCategoryId: 'cat-gold',
      categoryName: 'الذهب والشبكة',
      title: 'الشبكة',
      totalAmount: '1400000',
      paidAmount: '1400000',
      remainingAmount: '0',
      status: 'PAID',
      payer: 'FAMILY',
      payerName: 'الوالد',
      agreementDate: DateTime(2026, 9, 20),
      paymentsCount: 1,
      createdAt: DateTime(2026, 9, 20),
      updatedAt: _d,
    ),
  ];

  List<CostPayment> get _payments => [
    CostPayment(
      id: 'pay-gold-1',
      weddingPlanId: _plan,
      costId: 'cost-gold',
      costTitle: 'الشبكة',
      amount: '1400000',
      paidAt: DateTime(2026, 9, 20),
      method: 'كاش',
      reversible: true,
    ),
    CostPayment(
      id: 'pay-photo-1',
      weddingPlanId: _plan,
      costId: 'cost-photo',
      costTitle: 'تصوير فيديو وفوتو',
      amount: '200000',
      paidAt: DateTime(2026, 9, 1),
      method: 'كاش',
      reversible: true,
    ),
    CostPayment(
      id: 'pay-hall-1',
      weddingPlanId: _plan,
      costId: 'cost-hall',
      costTitle: 'قاعة ليالي صنعاء',
      amount: '1000000',
      paidAt: DateTime(2026, 8, 10),
      method: 'تحويل بنكي',
      note: 'العربون',
      reversible: true,
    ),
  ];

  List<PaymentSchedule> get _schedules => [
    PaymentSchedule(
      id: 'sch-hall-2',
      weddingPlanId: _plan,
      costId: 'cost-hall',
      costTitle: 'قاعة ليالي صنعاء',
      amount: '700000',
      dueDate: DateTime(2026, 10, 15),
      status: 'PENDING',
      isOverdue: true,
      note: 'الدفعة الثانية',
    ),
    PaymentSchedule(
      id: 'sch-photo-2',
      weddingPlanId: _plan,
      costId: 'cost-photo',
      costTitle: 'تصوير فيديو وفوتو',
      amount: '450000',
      dueDate: DateTime(2026, 11, 5),
      status: 'PENDING',
      note: 'الباقي قبل العرس',
    ),
  ];

  PaymentSchedule get _hallFinal => PaymentSchedule(
    id: 'sch-hall-3',
    weddingPlanId: _plan,
    costId: 'cost-hall',
    costTitle: 'قاعة ليالي صنعاء',
    amount: '500000',
    dueDate: DateTime(2027, 1, 15),
    status: 'PENDING',
    note: 'آخر دفعة قبل العرس بأسبوع',
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    const perms = MoneyPermissions(canViewMoney: true, canManageMoney: true);
    if (_empty) {
      return MoneySummary(planId: planId, currency: 'YER', permissions: perms);
    }
    final noBudget = mode == _Mode.noBudget;
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      permissions: perms,
      budget: MoneyBudgetSummary(
        total: noBudget ? null : '8000000',
        allocated: '6300000',
        unallocated: noBudget ? null : '1700000',
        confirmedCost: '4250000',
        remaining: noBudget ? null : '3750000',
      ),
      costs: const MoneyCostsSummary(
        total: '4250000',
        paid: '2600000',
        outstanding: '1650000',
        count: 3,
      ),
      paymentSchedules: MoneySchedulesSummary(
        totalCount: 3,
        upcomingCount: 2,
        overdueCount: 1,
        paidCount: 3,
        next: _schedules.first,
      ),
      categories: [
        for (final c in _cats)
          MoneyCategorySummary(
            categoryId: c.$1,
            name: c.$2,
            allocatedAmount: c.$3,
            confirmedCost: c.$4,
            paid: c.$5,
            outstanding: (int.parse(c.$4) - int.parse(c.$5)).toString(),
            remainingAllocation: (int.parse(c.$3) - int.parse(c.$4))
                .toString(),
            costsCount: c.$6,
          ),
      ],
      warnings: [
        if (mode == _Mode.exceeded || mode == _Mode.full)
          const MoneyWarning(
            type: 'CATEGORY_EXCEEDED',
            severity: 'WARNING',
            categoryId: 'cat-photo',
            amount: '50000',
          ),
      ],
      funding: noBudget
          ? null
          : const MoneyFundingSummary(
              total: '4000000',
              received: '3000000',
              pledged: '1000000',
              availableCash: '400000',
              shortfall: '250000',
              loanTotal: '1000000',
              loanOutstanding: '1000000',
              sourcesCount: 3,
            ),
    );
  }

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    if (!_empty)
      for (final c in _cats)
        BudgetCategory(
          id: c.$1,
          weddingPlanId: planId,
          name: c.$2,
          allocatedAmount: c.$3,
          confirmedCost: c.$4,
          paid: c.$5,
          costsCount: c.$6,
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
    final items = _empty
        ? <WeddingCost>[]
        : _costs
              .where(
                (c) =>
                    (categoryId == null || c.budgetCategoryId == categoryId) &&
                    (status == null || c.status == status) &&
                    (payer == null || c.payer == payer),
              )
              .toList();
    return FinancePage(
      items: items,
      page: 1,
      pageSize: limit,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<WeddingCost> getCost(String costId) async =>
      _costs.firstWhere((c) => c.id == costId);

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    final items = _empty ? <CostPayment>[] : _payments;
    return FinancePage(
      items: items,
      page: 1,
      pageSize: limit,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      _empty ? const [] : _schedules;

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => _payments.where((p) => p.costId == costId).toList();

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => [
    ..._schedules.where((s) => s.costId == costId),
    if (costId == 'cost-hall') _hallFinal,
  ];
}

class _Funding extends FundingApi {
  _Funding() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async => [
    FundingSource(
      id: 'src-savings',
      weddingPlanId: weddingPlanId,
      kind: FundingKind.savings,
      sourceName: 'مدخراتي',
      amount: '2000000',
      status: FundingStatus.received,
      receivedAt: DateTime(2026, 7, 1),
    ),
    FundingSource(
      id: 'src-father',
      weddingPlanId: weddingPlanId,
      kind: FundingKind.familySupport,
      sourceName: 'الوالد',
      amount: '1000000',
      status: FundingStatus.pledged,
    ),
    FundingSource(
      id: 'src-loan',
      weddingPlanId: weddingPlanId,
      kind: FundingKind.loan,
      sourceName: 'سلفة من ابن العم عادل',
      amount: '1000000',
      status: FundingStatus.received,
      receivedAt: DateTime(2026, 9, 15),
      repaidAmount: '0',
      outstandingAmount: '1000000',
      repayments: [
        for (var i = 0; i < 4; i++)
          LoanRepayment(
            id: 'rep-$i',
            fundingSourceId: 'src-loan',
            amount: '250000',
            status: RepaymentStatus.planned,
            dueDate: DateTime(2027, 2 + i, 1),
          ),
      ],
    ),
  ];
}

class _OfflineSync extends OfflineSyncService {
  _OfflineSync(LocalDatabase db, ApiClient client, this.offline)
    : super(database: db, apiClient: client);

  final bool offline;

  @override
  SyncState get state => offline ? SyncState.offline : SyncState.synced;

  @override
  int get pendingCount => offline ? 2 : 0;

  @override
  DateTime? get lastSyncedAt => offline ? DateTime(2026, 10, 20, 9, 40) : null;
}

/// Receipts list (`GET /costs/:id/receipts`) answers an empty list.
class _EmptyListAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(<Object>[]),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
