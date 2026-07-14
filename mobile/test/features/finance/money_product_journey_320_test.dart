import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/cost_draft_intent.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/screens/payment_schedule_screens.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const _planId = 'plan-money-product';

void main() {
  group('canonical money product journey at 320px RTL and 1.3 scale', () {
    testWidgets('owner opens real schedule, category, and cost destinations', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byType(MoneyOverviewScreen), findsOneWidget);
      expect(find.text('المال'), findsOneWidget);
      expect(find.byType(ScheduleCard), findsOneWidget);
      _expectRtl(tester, find.byType(MoneyOverviewScreen));
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byType(ScheduleCard),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(ScheduleCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ScheduleCard));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyScheduleDetails(_planId, 'cost-1', 'schedule-1'),
      );
      expect(find.byType(PaymentScheduleDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      harness.router.pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('القاعات').first,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('القاعات').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('القاعات').first);
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCategoryDetails(_planId, 'category-1'),
      );
      expect(find.byType(BudgetCategoryDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      harness.router.pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(CostCard),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(CostCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CostCard));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCostDetails(_planId, 'cost-1'),
      );
      expect(find.byType(CostDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'no-budget owner enters the real budget screen without duplicate setup',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.money(_planId),
          noBudget: true,
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(find.text('ابدأ بميزانية واضحة'), findsOneWidget);
        expect(find.text('إعداد الميزانية'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final setup = find.widgetWithText(FilledButton, 'إعداد الميزانية');
        await tester.ensureVisible(setup);
        await tester.pumpAndSettle();
        await tester.tap(setup);
        await tester.pumpAndSettle();
        expect(harness.currentLocation, AppRouter.moneyBudget(_planId));
        expect(find.byType(MoneyBudgetScreen), findsOneWidget);
        expect(find.text('إدارة الميزانية'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('حفظ الميزانية'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('حفظ الميزانية'), findsOneWidget);
        _expectRtl(tester, find.byType(MoneyBudgetScreen));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('budget rejects duplicate categories before sending a write', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyBudget(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      await tester.tap(find.text('إضافة تصنيف'));
      await tester.pump();
      final duplicateName = find.byKey(
        const ValueKey('money-budget-category-name-1'),
      );
      await tester.scrollUntilVisible(
        duplicateName,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(duplicateName, 'القاعات');
      final save = find.widgetWithText(FilledButton, 'حفظ الميزانية');
      await tester.scrollUntilVisible(
        save,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      final duplicateError = find.text('لا يمكن تكرار اسم التصنيف.');
      await tester.scrollUntilVisible(
        duplicateError,
        -240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(duplicateError, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('category allocation cannot exceed the remaining budget', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyCategoryCreate(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      await tester.enterText(
        find.byKey(const ValueKey('money-category-form-name')),
        'التصوير',
      );
      await tester.enterText(
        find.byKey(const ValueKey('money-category-form-amount')),
        '400000',
      );
      await tester.tap(find.text('حفظ التصنيف'));
      await tester.pump();

      expect(find.text('المخصص يتجاوز المتبقي من الميزانية.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner cost form is complete and overflow-safe', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyCostCreate(
          _planId,
          categoryId: 'category-1',
        ),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byType(CostFormScreen), findsOneWidget);
      expect(find.text('إضافة تكلفة'), findsOneWidget);
      expect(find.text('التصنيف *'), findsOneWidget);
      expect(find.text('اسم التكلفة *'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('حفظ التكلفة'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('حفظ التكلفة'), findsOneWidget);
      _expectRtl(tester, find.byType(CostFormScreen));
      expect(tester.takeException(), isNull);

      harness.router.go(AppRouter.moneyCategoryCreate(_planId));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetCategoryFormScreen), findsOneWidget);
      expect(find.text('تصنيف جديد'), findsOneWidget);
      expect(find.text('اسم التصنيف'), findsOneWidget);
      expect(find.text('المخصص (اختياري)'), findsOneWidget);
      expect(find.text('حفظ التصنيف'), findsOneWidget);
      _expectRtl(tester, find.byType(BudgetCategoryFormScreen));
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepted quote with a different currency cannot mix amounts', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
        extra: const CostDraftIntent(
          title: 'عرض قاعة بالريال السعودي',
          totalAmount: '2500',
          providerId: 'provider-1',
          providerName: 'قاعة السعادة',
          quoteOfferId: 'offer-sar',
          currency: 'SAR',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('عرض السعر بعملة ريال سعودي'), findsOneWidget);
      final amountFieldFinder = find.byKey(const Key('cost-total-amount'));
      await tester.scrollUntilVisible(
        amountFieldFinder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final amountField = tester.widget<TextFormField>(amountFieldFinder);
      expect(amountField.controller?.text, isEmpty);
      expect(find.textContaining('إجمالي التكلفة (ر.ي)'), findsOneWidget);
      await tester.enterText(amountFieldFinder, '170000');
      final save = find.widgetWithText(FilledButton, 'حفظ التكلفة');
      await tester.scrollUntilVisible(
        save,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(harness.api.createdTotalAmount, '170000');
      expect(harness.api.createdProviderId, 'provider-1');
      expect(harness.api.createdQuoteOfferId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepted quote in plan currency keeps its agreed amount', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
        extra: const CostDraftIntent(
          title: 'عرض القاعة المقبول',
          totalAmount: '250000',
          providerId: 'provider-1',
          providerName: 'قاعة السعادة',
          quoteOfferId: 'offer-yer',
          currency: 'YER',
        ),
      );
      await tester.pumpAndSettle();

      final amountFieldFinder = find.byKey(const Key('cost-total-amount'));
      await tester.scrollUntilVisible(
        amountFieldFinder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final amountField = tester.widget<TextFormField>(amountFieldFinder);
      expect(amountField.controller?.text, '250000');
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: amountFieldFinder,
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.readOnly, isTrue);
      expect(
        find.text('القيمة مثبتة لأنها مرتبطة بعرض سعر مقبول.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'read-only member sees money but cannot enter budget or cost writes',
      (tester) async {
        final harness = _MoneyProductHarness.viewer(
          initialLocation: AppRouter.money(_planId),
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(find.byType(MoneyOverviewScreen), findsOneWidget);
        expect(find.byTooltip('إدارة الميزانية'), findsNothing);
        await tester.scrollUntilVisible(
          find.byType(CostCard),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('حجز القاعة'), findsWidgets);
        expect(tester.takeException(), isNull);

        harness.router.go(AppRouter.moneyBudget(_planId));
        await tester.pumpAndSettle();
        expect(find.byType(MoneyBudgetScreen), findsOneWidget);
        expect(find.text('العرض فقط'), findsOneWidget);
        expect(find.text('حفظ الميزانية'), findsNothing);
        expect(tester.takeException(), isNull);

        harness.router.go(AppRouter.moneyCostCreate(_planId));
        await tester.pumpAndSettle();
        expect(find.byType(CostFormScreen), findsOneWidget);
        expect(find.text('العرض فقط'), findsOneWidget);
        expect(find.text('حفظ التكلفة'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _MoneyProductHarness {
  _MoneyProductHarness._({
    required this.api,
    required this.provider,
    required this.router,
  });

  factory _MoneyProductHarness.owner({
    required String initialLocation,
    bool noBudget = false,
  }) {
    final api = _MoneyProductApi(noBudget: noBudget);
    final provider = FinanceProvider(api);
    return _MoneyProductHarness._from(
      api: api,
      provider: provider,
      initialLocation: initialLocation,
    );
  }

  factory _MoneyProductHarness.viewer({required String initialLocation}) {
    final api = _MoneyProductApi();
    final provider = FinanceProvider(
      api,
      permissionsApi: _MoneyPermissionsApi(
        const PlanAccessPermissions(
          weddingPlanId: _planId,
          isOwner: false,
          canViewMoney: true,
          canManageMoney: false,
        ),
      ),
    );
    return _MoneyProductHarness._from(
      api: api,
      provider: provider,
      initialLocation: initialLocation,
    );
  }

  factory _MoneyProductHarness._from({
    required _MoneyProductApi api,
    required FinanceProvider provider,
    required String initialLocation,
  }) {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/wedding-plans/:id/money',
          builder: (context, state) =>
              MoneyOverviewScreen(weddingPlanId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/budget',
          builder: (context, state) =>
              MoneyBudgetScreen(weddingPlanId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/categories/create',
          builder: (context, state) => BudgetCategoryFormScreen(
            weddingPlanId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/categories/:categoryId',
          builder: (context, state) => BudgetCategoryDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            categoryId: state.pathParameters['categoryId']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/create',
          builder: (context, state) => CostFormScreen(
            weddingPlanId: state.pathParameters['id']!,
            intent: state.extra is CostDraftIntent
                ? state.extra! as CostDraftIntent
                : null,
            initialCategoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
          builder: (context, state) => PaymentScheduleDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            costId: state.pathParameters['costId']!,
            scheduleId: state.pathParameters['scheduleId']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/:costId',
          builder: (context, state) => CostDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            costId: state.pathParameters['costId']!,
          ),
        ),
      ],
    );
    return _MoneyProductHarness._(api: api, provider: provider, router: router);
  }

  final _MoneyProductApi api;
  final FinanceProvider provider;
  final GoRouter router;

  String get currentLocation => router.state.uri.toString();

  Widget get app => ChangeNotifierProvider<FinanceProvider>.value(
    value: provider,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );

  void dispose() {
    router.dispose();
    provider.dispose();
  }
}

class _MoneyProductApi extends FinanceApi {
  _MoneyProductApi({this.noBudget = false})
    : super(ApiClient(tokenProvider: () async => null));

  final bool noBudget;
  final now = DateTime.utc(2026, 7, 14, 12);
  String? createdTotalAmount;
  String? createdProviderId;
  String? createdQuoteOfferId;

  WeddingCost get cost => WeddingCost(
    id: 'cost-1',
    weddingPlanId: _planId,
    budgetCategoryId: 'category-1',
    title: 'حجز القاعة',
    totalAmount: '500000',
    paidAmount: '100000',
    remainingAmount: '400000',
    status: 'PARTIALLY_PAID',
    providerId: 'provider-1',
    providerName: 'قاعة السعادة',
    paymentsCount: 1,
    createdAt: now.subtract(const Duration(days: 20)),
    updatedAt: now,
  );

  @override
  Future<WeddingCost> createCost({
    required String planId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    DateTime? agreementDate,
    DateTime? dueDate,
    String? note,
  }) async {
    createdTotalAmount = totalAmount;
    createdProviderId = providerId;
    createdQuoteOfferId = quoteOfferId;
    return WeddingCost(
      id: 'created-cost',
      weddingPlanId: planId,
      budgetCategoryId: budgetCategoryId,
      title: title,
      totalAmount: totalAmount,
      paidAmount: initialPaymentAmount ?? '0',
      remainingAmount: totalAmount,
      status: 'OPEN',
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      dueDate: dueDate,
      agreementDate: agreementDate,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  CostPayment get payment => CostPayment(
    id: 'payment-1',
    weddingPlanId: _planId,
    costId: 'cost-1',
    amount: '100000',
    paidAt: now.subtract(const Duration(days: 5)),
    costTitle: 'حجز القاعة',
  );

  PaymentSchedule get schedule => PaymentSchedule(
    id: 'schedule-1',
    weddingPlanId: _planId,
    costId: 'cost-1',
    amount: '200000',
    dueDate: now.add(const Duration(days: 10)),
    status: 'PENDING',
    costTitle: 'دفعة حجز القاعة',
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    if (noBudget) return MoneySummary.empty(planId);
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '1000000',
        allocated: '700000',
        unallocated: '300000',
        confirmedCost: '500000',
        remaining: '500000',
      ),
      costs: const MoneyCostsSummary(
        total: '500000',
        paid: '100000',
        outstanding: '400000',
        count: 1,
      ),
      paymentSchedules: MoneySchedulesSummary(upcomingCount: 1, next: schedule),
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'القاعات',
          allocatedAmount: '700000',
          confirmedCost: '500000',
          paid: '100000',
          outstanding: '400000',
          remainingAllocation: '200000',
          costsCount: 1,
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
  }) async {
    final items = noBudget ? const <WeddingCost>[] : [cost];
    return FinancePage(
      items: items,
      page: page,
      pageSize: limit,
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
    final items = noBudget ? const <CostPayment>[] : [payment];
    return FinancePage(
      items: items,
      page: page,
      pageSize: limit,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      noBudget ? const [] : [schedule];

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => noBudget ? const [] : [payment];

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => noBudget ? const [] : [schedule];
}

class _MoneyPermissionsApi extends SharingApi {
  _MoneyPermissionsApi(this.permissions)
    : super(ApiClient(tokenProvider: () async => null));

  final PlanAccessPermissions permissions;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async =>
      permissions;
}

Future<void> _pumpProduct(WidgetTester tester, Widget app) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 760);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void _expectRtl(WidgetTester tester, Finder finder) {
  expect(Directionality.of(tester.element(finder.first)), TextDirection.rtl);
}
