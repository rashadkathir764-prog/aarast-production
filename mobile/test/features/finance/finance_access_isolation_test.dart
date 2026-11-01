import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/cost_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'view-only money access loads every canonical read resource once',
    () async {
      final financeApi = _CountingFinanceApi(withCost: true);
      final provider = FinanceProvider(
        financeApi,
        permissionsApi: _FakeSharingApi(_viewer('plan-viewer')),
      );

      await provider.loadMoney('plan-viewer');

      expect(financeApi.summaryCalls, 1);
      expect(financeApi.costCalls, 1);
      expect(financeApi.paymentCalls, 1);
      expect(financeApi.scheduleCalls, 1);
      expect(provider.costs, hasLength(1));
      expect(provider.canViewMoney, isTrue);
      expect(provider.canManageMoney, isFalse);
    },
  );

  // The money starter is gone (rule zero): an empty plan opens on «البنود».
  testWidgets('empty view-only money opens on the items with no add action', (
    tester,
  ) async {
    await _setPhoneView(tester);
    await tester.pumpWidget(
      _financeScreen(
        const MoneyOverviewScreen(weddingPlanId: 'plan-viewer'),
        api: _CountingFinanceApi(withCost: false, withCategories: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما في بنود بعد'), findsOneWidget);
    expect(find.text('أضف أول بند'), findsNothing);
    expect(find.text('أضف بند'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Field test Q02 asked that a budget alone still leads to items; with the
  // starter gone the empty money opens where the first item is added.
  testWidgets('an owner with a budget but no items opens on «أضف أول بند»', (
    tester,
  ) async {
    await _setPhoneView(tester);
    await tester.pumpWidget(
      _financeScreen(
        const MoneyOverviewScreen(weddingPlanId: 'plan-owner'),
        api: _CountingFinanceApi(withCategories: false),
        permissions: PlanAccessPermissions(
          weddingPlanId: 'plan-owner',
          isOwner: true,
          canViewMoney: true,
          canManageMoney: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(MoneyOverviewScreen))
        .read<FinanceProvider>();
    expect(provider.summary.hasBudget, isTrue);
    expect(provider.categories, isEmpty);
    expect(find.text('ما في بنود بعد'), findsOneWidget);
    expect(find.text('أضف أول بند'), findsOneWidget);
    expect(find.textContaining('جهّز'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'failed plan switch cannot leave the previous plan data visible',
    () async {
      final financeApi = _CountingFinanceApi(
        withCost: true,
        failSummaryFor: 'plan-b',
      );
      final permissionsApi = _FakeSharingApi(
        const PlanAccessPermissions.owner(weddingPlanId: 'plan-a'),
      );
      final provider = FinanceProvider(
        financeApi,
        permissionsApi: permissionsApi,
      );

      await provider.loadMoney('plan-a');
      expect(provider.costs, isNotEmpty);

      permissionsApi.permissions = const PlanAccessPermissions.owner(
        weddingPlanId: 'plan-b',
      );
      await provider.loadMoney('plan-b');

      expect(provider.loadedPlanId, 'plan-b');
      expect(provider.categories, isEmpty);
      expect(provider.costs, isEmpty);
      expect(provider.payments, isEmpty);
      expect(provider.dueSchedules, isEmpty);
      expect(provider.summary.planId, 'plan-b');
      expect(provider.errorMessage, isNotNull);
    },
  );

  test(
    'revoked money access clears previously loaded data for the same plan',
    () async {
      final permissionsApi = _FakeSharingApi(
        const PlanAccessPermissions.owner(weddingPlanId: 'plan-a'),
      );
      final provider = FinanceProvider(
        _CountingFinanceApi(withCost: true),
        permissionsApi: permissionsApi,
      );

      await provider.loadMoney('plan-a');
      expect(provider.costs, isNotEmpty);

      permissionsApi.failure = const ApiException(
        'لم تعد عضوًا في هذه الخطة.',
        statusCode: 404,
      );
      await provider.loadMoney('plan-a');

      expect(provider.access.hasAnyFinanceAccess, isFalse);
      expect(provider.categories, isEmpty);
      expect(provider.costs, isEmpty);
      expect(provider.payments, isEmpty);
      expect(provider.dueSchedules, isEmpty);
      expect(provider.summary.hasAnyData, isFalse);
      expect(provider.errorMessage, isNotNull);
    },
  );

  testWidgets('view-only member sees costs without write actions', (
    tester,
  ) async {
    await _setPhoneView(tester);
    await tester.pumpWidget(
      _financeScreen(const MoneyOverviewScreen(weddingPlanId: 'plan-viewer')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('البنود'));
    await tester.pumpAndSettle();

    expect(find.text('الصالة'), findsWidgets);
    expect(find.text('أضف بند'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('view-only member sees cost details without edit or payment', (
    tester,
  ) async {
    await _setPhoneView(tester);
    await tester.pumpWidget(
      _financeScreen(
        const CostDetailsScreen(weddingPlanId: 'plan-viewer', costId: 'cost-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حجز الصالة'), findsWidgets);
    expect(find.textContaining('هذه التفاصيل للعرض فقط'), findsOneWidget);
    expect(find.byTooltip('تعديل التكلفة'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);
    expect(find.text('حذف'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct cost write route fails closed for a viewer', (
    tester,
  ) async {
    await _setPhoneView(tester);
    await tester.pumpWidget(
      _financeScreen(const CostFormScreen(weddingPlanId: 'plan-viewer')),
    );
    await tester.pumpAndSettle();

    expect(find.text('العرض فقط'), findsOneWidget);
    expect(find.text('حفظ الاتفاق'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setPhoneView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _financeScreen(
  Widget child, {
  FinanceApi? api,
  PlanAccessPermissions? permissions,
}) {
  return ChangeNotifierProvider<FinanceProvider>(
    create: (_) => FinanceProvider(
      api ?? _CountingFinanceApi(withCost: true),
      permissionsApi: _FakeSharingApi(permissions ?? _viewer('plan-viewer')),
    ),
    child: MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

PlanAccessPermissions _viewer(String planId) {
  return PlanAccessPermissions(
    weddingPlanId: planId,
    isOwner: false,
    canViewMoney: true,
    canManageMoney: false,
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi(this.permissions)
    : super(ApiClient(tokenProvider: () async => null));

  PlanAccessPermissions permissions;
  ApiException? failure;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async {
    final error = failure;
    if (error != null) throw error;
    return permissions;
  }
}

class _CountingFinanceApi extends FinanceApi {
  _CountingFinanceApi({
    this.failSummaryFor,
    this.withCost = false,
    this.withCategories = true,
  }) : super(ApiClient(tokenProvider: () async => null));

  final String? failSummaryFor;
  final bool withCost;
  final bool withCategories;
  int summaryCalls = 0;
  int costCalls = 0;
  int paymentCalls = 0;
  int scheduleCalls = 0;

  WeddingCost _cost(String planId) => WeddingCost(
    id: 'cost-1',
    weddingPlanId: planId,
    budgetCategoryId: 'category-1',
    title: 'حجز الصالة',
    totalAmount: '1000',
    paidAmount: '0',
    remainingAmount: '1000',
    status: 'OPEN',
    createdAt: DateTime.utc(2026, 7, 11),
    updatedAt: DateTime.utc(2026, 7, 11),
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    summaryCalls += 1;
    if (planId == failSummaryFor) throw Exception('failed');
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '10000',
        confirmedCost: '1000',
        remaining: '9000',
      ),
      costs: MoneyCostsSummary(
        total: withCost ? '1000' : '0',
        outstanding: withCost ? '1000' : '0',
        count: withCost ? 1 : 0,
      ),
      categories: withCategories
          ? const [
              MoneyCategorySummary(
                categoryId: 'category-1',
                name: 'الصالة',
                allocatedAmount: '5000',
                costsCount: 1,
              ),
            ]
          : const [],
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
  }) async {
    costCalls += 1;
    final items = withCost ? [_cost(planId)] : const <WeddingCost>[];
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
    paymentCalls += 1;
    return FinancePage(
      items: const [],
      page: page,
      pageSize: limit,
      total: 0,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async {
    scheduleCalls += 1;
    return const [];
  }

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => const [];

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => const [];
}
