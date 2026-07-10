import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_expense_screen.dart';
import 'package:aarast_mobile/features/finance/screens/financial_payables_screen.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/budget_pulse_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('finance duplication cleanup', () {
    testWidgets('first money visit shows one budget setup action', (
      tester,
    ) async {
      _setTallView(tester);

      await tester.pumpWidget(_wrap(_FakeFinanceApi.noBudget()));
      await tester.pumpAndSettle();

      expect(find.text('إعداد الميزانية'), findsOneWidget);
    });

    testWidgets('money root previews one payable while full screen keeps all', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeFinanceApi.withCommitments();

      await tester.pumpWidget(_wrap(api));
      await tester.pumpAndSettle();

      expect(find.text('المستحق الأول'), findsOneWidget);
      expect(find.text('المستحق الثاني'), findsNothing);
      expect(find.text('المستحق الثالث'), findsNothing);

      await tester.pumpWidget(_wrap(api, payables: true));
      await tester.pumpAndSettle();

      expect(find.text('المستحق الأول'), findsOneWidget);
      expect(find.text('المستحق الثاني'), findsOneWidget);
      expect(find.text('المستحق الثالث'), findsOneWidget);
    });

    testWidgets('payables screen does not repeat the global budget hero', (
      tester,
    ) async {
      _setTallView(tester);

      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCommitments(), payables: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BudgetPulseHero), findsNothing);
    });

    test('budget category screen keeps one primary payable action', () {
      final source = File(
        'lib/features/finance/screens/budget_category_details_screen.dart',
      ).readAsStringSync();

      expect(_occurrences(source, "actionLabel: 'إضافة مستحق'"), 1);
    });
  });
}

Widget _wrap(_FakeFinanceApi api, {bool payables = false}) {
  const planId = 'plan-finance-cleanup';
  return ChangeNotifierProvider<FinanceProvider>(
    create: (_) => FinanceProvider(api),
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: payables
            ? const FinancialPayablesScreen(weddingPlanId: planId)
            : const BudgetExpenseScreen(weddingPlanId: planId),
      ),
    ),
  );
}

class _FakeFinanceApi extends BudgetExpenseApi {
  _FakeFinanceApi._(this._commitments)
    : super(ApiClient(tokenProvider: () async => null));

  factory _FakeFinanceApi.noBudget() => _FakeFinanceApi._(const []);

  factory _FakeFinanceApi.withCommitments() => _FakeFinanceApi._([
    _commitment('commitment-1', 'المستحق الأول', DateTime.utc(2026, 7, 11)),
    _commitment('commitment-2', 'المستحق الثاني', DateTime.utc(2026, 7, 12)),
    _commitment('commitment-3', 'المستحق الثالث', DateTime.utc(2026, 7, 13)),
  ]);

  final List<FinancialCommitment> _commitments;

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    return const [];
  }

  @override
  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    return const [];
  }

  @override
  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    return ExpenseSummary.empty();
  }

  @override
  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    return MoneySummary(
      weddingPlanId: weddingPlanId,
      commitmentsCount: _commitments.length,
      outstandingTotal: _commitments.isEmpty ? '0' : '6000',
    );
  }

  @override
  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    return _commitments;
  }

  @override
  Future<List<FinancialPaymentRecord>> getFinancialPaymentRecords(
    String weddingPlanId,
  ) async {
    return const [];
  }

  @override
  Future<List<FinancialInstallment>> getDueFinancialInstallments(
    String weddingPlanId,
  ) async {
    return const [];
  }
}

FinancialCommitment _commitment(String id, String title, DateTime dueDate) {
  return FinancialCommitment(
    id: id,
    weddingPlanId: 'plan-finance-cleanup',
    budgetCategoryId: 'category-1',
    title: title,
    totalAmount: '2000',
    paidAmount: '0',
    remainingAmount: '2000',
    sourceType: 'MANUAL_COMMITMENT',
    status: 'OPEN',
    dueDate: dueDate,
  );
}

int _occurrences(String source, String value) {
  return RegExp(RegExp.escape(value)).allMatches(source).length;
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(520, 1800);
  addTearDown(tester.view.reset);
}
