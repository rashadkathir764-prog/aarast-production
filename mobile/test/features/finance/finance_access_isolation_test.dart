import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/financial_commitment_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/financial_payables_screen.dart';
import 'package:aarast_mobile/features/finance/screens/create_financial_commitment_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('financial-record access loads only commitment-backed resources', () async {
    final financeApi = _CountingFinanceApi();
    final permissionsApi = _FakeSharingApi(
      const PlanAccessPermissions(
        weddingPlanId: 'plan-financial-records',
        isOwner: false,
        canViewBudget: false,
        canViewExpenses: false,
        canViewFinancialRecords: true,
        canManageFinancialRecords: false,
      ),
    );
    final provider = FinanceProvider(
      financeApi,
      permissionsApi: permissionsApi,
    );

    await provider.loadFinance('plan-financial-records');

    expect(financeApi.budgetCalls, 0);
    expect(financeApi.expenseCalls, 0);
    expect(financeApi.expenseSummaryCalls, 0);
    expect(financeApi.commitmentCalls, 1);
    expect(financeApi.paymentCalls, 1);
    expect(financeApi.installmentCalls, 1);
    expect(provider.canManageFinancialRecords, isFalse);
    expect(provider.access.canReadFinancialRecords, isTrue);
  });

  test(
    'failed plan switch cannot leave the previous plan data visible',
    () async {
      final financeApi = _CountingFinanceApi(failMoneySummaryFor: 'plan-b');
      final permissionsApi = _FakeSharingApi(
        const PlanAccessPermissions.owner(weddingPlanId: 'plan-a'),
      );
      final provider = FinanceProvider(
        financeApi,
        permissionsApi: permissionsApi,
      );

      await provider.loadFinance('plan-a');
      expect(provider.budgetCategories, isNotEmpty);

      permissionsApi.permissions = const PlanAccessPermissions.owner(
        weddingPlanId: 'plan-b',
      );
      await provider.loadFinance('plan-b');

      expect(provider.loadedWeddingPlanId, 'plan-b');
      expect(provider.budgetCategories, isEmpty);
      expect(provider.expenses, isEmpty);
      expect(provider.financialCommitments, isEmpty);
      expect(provider.moneySummary.weddingPlanId, 'plan-b');
      expect(provider.errorMessage, isNotNull);
    },
  );

  test(
    'revoked finance access clears previously loaded data for the same plan',
    () async {
      final financeApi = _CountingFinanceApi(withCommitment: true);
      final permissionsApi = _FakeSharingApi(
        const PlanAccessPermissions.owner(weddingPlanId: 'plan-a'),
      );
      final provider = FinanceProvider(
        financeApi,
        permissionsApi: permissionsApi,
      );

      await provider.loadFinance('plan-a');
      expect(provider.budgetCategories, isNotEmpty);
      expect(provider.financialCommitments, isNotEmpty);

      permissionsApi.failure = const ApiException(
        'لم تعد عضوًا في هذه الخطة.',
        statusCode: 404,
      );
      await provider.loadFinance('plan-a');

      expect(provider.access.hasAnyFinanceAccess, isFalse);
      expect(provider.budgetCategories, isEmpty);
      expect(provider.expenses, isEmpty);
      expect(provider.financialCommitments, isEmpty);
      expect(provider.financialPaymentRecords, isEmpty);
      expect(provider.dueFinancialInstallments, isEmpty);
      expect(provider.moneySummary.hasAnyData, isFalse);
      expect(provider.errorMessage, isNotNull);
    },
  );

  testWidgets('view-only member never sees payable write actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _financeScreen(
        const FinancialPayablesScreen(weddingPlanId: 'plan-viewer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المستحق الأول'), findsOneWidget);
    expect(find.text('إضافة مستحق'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);
  });

  testWidgets('view-only member sees details without edit actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _financeScreen(
        const FinancialCommitmentDetailsScreen(
          weddingPlanId: 'plan-viewer',
          commitmentId: 'commitment-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المستحق الأول'), findsWidgets);
    expect(find.text('تعديل'), findsNothing);
    expect(find.text('حذف'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);
  });

  testWidgets('direct finance write route fails closed for a viewer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _financeScreen(
        const CreateFinancialCommitmentScreen(weddingPlanId: 'plan-viewer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('العرض فقط'), findsOneWidget);
    expect(find.text('حفظ المستحق'), findsNothing);
  });
}

Widget _financeScreen(Widget child) {
  return ChangeNotifierProvider<FinanceProvider>(
    create: (_) => FinanceProvider(
      _CountingFinanceApi(withCommitment: true),
      permissionsApi: _FakeSharingApi(
        const PlanAccessPermissions(
          weddingPlanId: 'plan-viewer',
          isOwner: false,
          canViewBudget: false,
          canViewExpenses: false,
          canViewFinancialRecords: true,
          canManageFinancialRecords: false,
        ),
      ),
    ),
    child: MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi(this.permissions)
    : super(ApiClient(tokenProvider: () async => null));

  PlanAccessPermissions permissions;
  ApiException? failure;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    final error = failure;
    if (error != null) throw error;
    return permissions;
  }
}

class _CountingFinanceApi extends BudgetExpenseApi {
  _CountingFinanceApi({this.failMoneySummaryFor, this.withCommitment = false})
    : super(ApiClient(tokenProvider: () async => null));

  final String? failMoneySummaryFor;
  final bool withCommitment;
  int budgetCalls = 0;
  int expenseCalls = 0;
  int expenseSummaryCalls = 0;
  int commitmentCalls = 0;
  int paymentCalls = 0;
  int installmentCalls = 0;

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String weddingPlanId) async {
    budgetCalls++;
    return [
      BudgetCategory(
        id: 'category-$weddingPlanId',
        weddingPlanId: weddingPlanId,
        name: 'الصالة',
        createdAt: DateTime.utc(2026, 7, 11),
        updatedAt: DateTime.utc(2026, 7, 11),
      ),
    ];
  }

  @override
  Future<List<Expense>> getExpenses(String weddingPlanId) async {
    expenseCalls++;
    return const [];
  }

  @override
  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    expenseSummaryCalls++;
    return ExpenseSummary.empty();
  }

  @override
  Future<MoneySummary> getMoneySummary(String weddingPlanId) async {
    if (weddingPlanId == failMoneySummaryFor) throw Exception('failed');
    return MoneySummary(weddingPlanId: weddingPlanId);
  }

  @override
  Future<List<FinancialCommitment>> getFinancialCommitments(
    String weddingPlanId,
  ) async {
    commitmentCalls++;
    if (!withCommitment) return const [];
    return [
      FinancialCommitment(
        id: 'commitment-1',
        weddingPlanId: weddingPlanId,
        budgetCategoryId: 'category-1',
        title: 'المستحق الأول',
        totalAmount: '1000',
        paidAmount: '0',
        remainingAmount: '1000',
        sourceType: 'MANUAL_COMMITMENT',
        status: 'OPEN',
      ),
    ];
  }

  @override
  Future<List<FinancialPaymentRecord>> getFinancialPaymentRecords(
    String weddingPlanId,
  ) async {
    paymentCalls++;
    return const [];
  }

  @override
  Future<List<FinancialInstallment>> getDueFinancialInstallments(
    String weddingPlanId,
  ) async {
    installmentCalls++;
    return const [];
  }
}
