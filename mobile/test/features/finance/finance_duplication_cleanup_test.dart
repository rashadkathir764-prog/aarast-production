import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('one money system cleanup', () {
    testWidgets('first money visit shows one budget setup action', (
      tester,
    ) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.noBudget()));
      await tester.pumpAndSettle();

      expect(find.text('إعداد الميزانية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money root previews only the three newest costs', (
      tester,
    ) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.withCosts()));
      await tester.pumpAndSettle();

      expect(find.text('تكلفة 4'), findsOneWidget);
      expect(find.text('تكلفة 3'), findsOneWidget);
      expect(find.text('تكلفة 2'), findsOneWidget);
      expect(find.text('تكلفة 1'), findsNothing);
    });

    testWidgets('money root stays overflow-free at 320px RTL and scale 1.3', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), textScale: 1.3),
      );
      await tester.pumpAndSettle();

      expect(find.text('المال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('embedded money root owns an opaque ivory surface', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), embedded: true),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('money-overview-surface')),
      );
      final list = tester.widget<ListView>(
        find.byKey(const PageStorageKey('money-overview-list')),
      );
      final padding = list.padding! as EdgeInsets;
      expect(surface.color, AppTheme.ivory);
      expect(
        padding.bottom,
        greaterThanOrEqualTo(196),
        reason:
            'The final money card must scroll fully clear of the smart FAB.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('member without money access sees the private state only', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), sharedMember: _deniedMember()),
      );
      await tester.pumpAndSettle();

      expect(find.text('المال خاص'), findsOneWidget);
      expect(find.text('تكلفة 4'), findsNothing);
      expect(find.text('إعداد الميزانية'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('removed finance implementations cannot return', () {
      for (final path in <String>[
        'lib/features/finance/data/budget_expense_api.dart',
        'lib/features/finance/models/expense.dart',
        'lib/features/finance/models/financial_commitment.dart',
        'lib/features/finance/screens/budget_expense_screen.dart',
        'lib/features/finance/screens/financial_payables_screen.dart',
        'lib/features/finance/widgets/finance_overview',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }

      final router = File(
        'lib/core/routing/app_router.dart',
      ).readAsStringSync();
      for (final removed in <String>[
        'BudgetExpenseScreen',
        'FinancialPayablesScreen',
        '/expenses',
        '/financial-commitments',
      ]) {
        expect(router, isNot(contains(removed)), reason: removed);
      }
    });
  });
}

Widget _wrap(
  _FakeFinanceApi api, {
  SharedMember? sharedMember,
  double textScale = 1,
  bool embedded = false,
}) {
  const planId = 'plan-money-cleanup';
  return ChangeNotifierProvider<FinanceProvider>(
    create: (_) => FinanceProvider(api),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MoneyOverviewScreen(
          weddingPlanId: planId,
          sharedMember: sharedMember,
          embedded: embedded,
        ),
      ),
    ),
  );
}

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi._(this._costs)
    : super(ApiClient(tokenProvider: () async => null));

  factory _FakeFinanceApi.noBudget() => _FakeFinanceApi._(const []);

  factory _FakeFinanceApi.withCosts() => _FakeFinanceApi._([
    for (var index = 1; index <= 4; index++)
      WeddingCost(
        id: 'cost-$index',
        weddingPlanId: 'plan-money-cleanup',
        budgetCategoryId: 'category-1',
        title: 'تكلفة $index',
        totalAmount: '2000',
        paidAmount: '0',
        remainingAmount: '2000',
        status: 'OPEN',
        createdAt: DateTime.utc(2026, 7, index),
        updatedAt: DateTime.utc(2026, 7, index),
      ),
  ]);

  final List<WeddingCost> _costs;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    if (_costs.isEmpty) return MoneySummary.empty(planId);
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '20000',
        allocated: '10000',
        unallocated: '10000',
        confirmedCost: '8000',
        remaining: '12000',
      ),
      costs: const MoneyCostsSummary(
        total: '8000',
        outstanding: '8000',
        count: 4,
      ),
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'الصالة',
          allocatedAmount: '10000',
          confirmedCost: '8000',
          outstanding: '8000',
          remainingAllocation: '2000',
          costsCount: 4,
        ),
      ],
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
  }) async => FinancePage(
    items: _costs,
    page: page,
    pageSize: limit,
    total: _costs.length,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => FinancePage(
    items: const [],
    page: page,
    pageSize: limit,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];
}

SharedMember _deniedMember() {
  final now = DateTime.utc(2026, 7, 11);
  return SharedMember(
    id: 'member-denied',
    weddingPlanId: 'plan-money-cleanup',
    userId: 'user-denied',
    role: 'VIEWER',
    canViewMoney: false,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: now,
    updatedAt: now,
  );
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

void _setPhoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1200);
  addTearDown(tester.view.reset);
}
