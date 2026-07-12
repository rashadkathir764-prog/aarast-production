import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/expense.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'local guest finance keeps CRUD balances summaries and due installments',
    () async {
      final harness = await _createHarness();
      const planId = 'guest-plan-finance-characterization';

      final createdCategory = await harness.api.createBudgetCategory(
        weddingPlanId: planId,
        name: ' القاعة ',
        targetAmount: '1000',
      );
      final category = await harness.api.updateBudgetCategory(
        category: createdCategory,
        name: 'قاعة الأفراح',
        targetAmount: '1200',
      );
      expect(category.name, 'قاعة الأفراح');
      expect(category.targetAmount, '1200');

      final createdExpense = await harness.api.createExpense(
        weddingPlanId: planId,
        title: ' دفعة الحجز ',
        amount: '200',
        budgetCategoryId: category.id,
      );
      final expense = await harness.api.updateExpense(
        id: createdExpense.id,
        weddingPlanId: planId,
        title: 'دفعة الحجز المعدلة',
        amount: '250',
        budgetCategoryId: category.id,
        note: 'تم السداد',
      );
      expect(expense.title, 'دفعة الحجز المعدلة');
      expect(expense.amount, '250');
      expect(expense.note, 'تم السداد');

      final createdCommitment = await harness.api.createFinancialCommitment(
        weddingPlanId: planId,
        budgetCategoryId: category.id,
        title: ' باقي القاعة ',
        totalAmount: '600',
        paidAmount: '100',
        sourceType: 'MANUAL_PAYABLE',
      );
      expect(createdCommitment.paidAmount, '100.00');
      expect(createdCommitment.remainingAmount, '500.00');
      expect(createdCommitment.status, 'PARTIALLY_PAID');

      await harness.api.createFinancialPaymentRecord(
        commitmentId: createdCommitment.id,
        amount: '150',
        title: 'دفعة ثانية',
      );
      final pendingInstallment = await harness.api
          .createFinancialInstallment(
            commitmentId: createdCommitment.id,
            amount: '100',
            dueDate: DateTime.now().add(const Duration(days: 2)),
          );
      await harness.api.createFinancialInstallment(
        commitmentId: createdCommitment.id,
        amount: '50',
        dueDate: DateTime.now(),
        paidAt: DateTime.now(),
        status: 'PAID',
      );

      final commitments = await harness.api.getFinancialCommitments(planId);
      expect(commitments.single.paidAmount, '300.00');
      expect(commitments.single.remainingAmount, '300.00');
      expect(commitments.single.status, 'PARTIALLY_PAID');

      final payments = await harness.api.getFinancialPaymentRecords(planId);
      expect(payments, hasLength(3));
      expect(
        payments.map((payment) => payment.amount),
        containsAll(<String>['100.00', '150.00', '50.00']),
      );
      final dueInstallments = await harness.api.getDueFinancialInstallments(
        planId,
      );
      expect(dueInstallments, hasLength(1));
      expect(dueInstallments.single.id, pendingInstallment.id);

      final expenseSummary = await harness.api.getExpenseSummary(planId);
      expect(expenseSummary.totalPaid, '250.00');
      expect(expenseSummary.countPaid, 1);
      expect(expenseSummary.countPlanned, 0);
      expect(expenseSummary.countCancelled, 0);

      final moneySummary = await harness.api.getMoneySummary(planId);
      expect(moneySummary.totalBudget, '1200.00');
      expect(moneySummary.totalSpent, '250.00');
      expect(moneySummary.confirmedCostTotal, '850.00');
      expect(moneySummary.remainingBudget, '350.00');
      expect(moneySummary.paidTotal, '550.00');
      expect(moneySummary.outstandingTotal, '300.00');
      expect(moneySummary.commitmentPaidTotal, '300.00');
      expect(moneySummary.commitmentRemainingTotal, '300.00');
      expect(moneySummary.paidInstallmentsCount, 1);
      expect(moneySummary.remainingInstallmentsCount, 1);
      expect(moneySummary.nextInstallment?.id, pendingInstallment.id);
      expect(moneySummary.categorySummaries.single.expensesCount, 1);
      expect(moneySummary.categorySummaries.single.commitmentsCount, 1);
      expect(moneySummary.categorySummaries.single.installmentsCount, 2);

      final updatedCommitment = await harness.api.updateFinancialCommitment(
        commitment: commitments.single,
        budgetCategoryId: category.id,
        title: 'باقي القاعة المعدل',
        totalAmount: '700',
        sourceType: 'MANUAL_PAYABLE',
      );
      expect(updatedCommitment.paidAmount, '300.00');
      expect(updatedCommitment.remainingAmount, '400.00');
      expect(updatedCommitment.status, 'PARTIALLY_PAID');

      expect(await harness.database.pendingSyncItems(), isEmpty);

      await harness.api.deleteExpense(expense.id);
      await harness.api.deleteBudgetCategory(category.id);
      await harness.api.deleteFinancialCommitment(updatedCommitment.id);

      expect(await harness.api.getExpenses(planId), isEmpty);
      expect(await harness.api.getBudgetCategories(planId), isEmpty);
      expect(await harness.api.getFinancialCommitments(planId), isEmpty);

      final queued = await harness.database.pendingSyncItems();
      expect(queued, hasLength(3));
      _expectQueued(
        queued,
        entityType: 'expense',
        operation: 'delete',
        endpoint: '/api/v1/expenses/${expense.id}',
        method: 'DELETE',
      );
      _expectQueued(
        queued,
        entityType: 'budget_category',
        operation: 'delete',
        endpoint: '/api/v1/budget-categories/${category.id}',
        method: 'DELETE',
      );
      _expectQueued(
        queued,
        entityType: 'financial_commitment',
        operation: 'delete',
        endpoint: '/api/v1/financial-commitments/${updatedCommitment.id}',
        method: 'DELETE',
      );
    },
  );

  test('network read failures return every cached finance projection', () async {
    final harness = await _createHarness();
    const planId = 'remote-plan-finance-cache';
    await _seedRemoteFinance(harness.database, planId);

    final categories = await harness.api.getBudgetCategories(planId);
    final expenses = await harness.api.getExpenses(planId);
    final expenseSummary = await harness.api.getExpenseSummary(planId);
    final moneySummary = await harness.api.getMoneySummary(planId);
    final commitments = await harness.api.getFinancialCommitments(planId);
    final payments = await harness.api.getFinancialPaymentRecords(planId);
    final dueInstallments = await harness.api.getDueFinancialInstallments(
      planId,
    );

    expect(categories.single.id, 'remote-category');
    expect(expenses.single.id, 'remote-expense');
    expect(expenseSummary.totalPaid, '100.00');
    expect(moneySummary.totalBudget, '1000.00');
    expect(moneySummary.confirmedCostTotal, '600.00');
    expect(moneySummary.remainingBudget, '400.00');
    expect(commitments.single.id, 'remote-commitment');
    expect(payments.single.id, 'remote-payment');
    expect(dueInstallments, hasLength(1));
    expect(dueInstallments.single.id, 'remote-installment-pending');
    expect(harness.offline.snapshot.lastError, _NetworkFailureApiClient.message);

    expect(
      harness.client.getListPaths,
      containsAll(<String>[
        '/api/v1/wedding-plans/$planId/budget-categories',
        '/api/v1/wedding-plans/$planId/expenses',
        '/api/v1/wedding-plans/$planId/financial-commitments',
        '/api/v1/wedding-plans/$planId/financial-payment-records',
        '/api/v1/wedding-plans/$planId/financial-installments/due',
      ]),
    );
    expect(
      harness.client.getPaths,
      containsAll(<String>[
        '/api/v1/wedding-plans/$planId/expenses/summary',
        '/api/v1/wedding-plans/$planId/money-summary',
      ]),
    );
  });

  test('network write failures preserve exact queue contracts', () async {
    final harness = await _createHarness();
    const planId = 'remote-plan-finance-queue';
    await _seedRemoteFinance(harness.database, planId);

    final cachedCategory = BudgetCategory.fromJson(
      (await harness.database.readCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        id: 'remote-category',
      ))!,
    );
    final cachedExpense = Expense.fromJson(
      (await harness.database.readCachedItem(
        table: OfflineTables.cachedBudgetItems,
        id: 'remote-expense',
      ))!,
    );
    final cachedCommitment = FinancialCommitment.fromJson(
      (await harness.database.readCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        id: 'remote-commitment',
      ))!,
    );

    final createdCategory = await harness.api.createBudgetCategory(
      weddingPlanId: planId,
      name: 'الزينة',
      targetAmount: '300',
    );
    final createdExpense = await harness.api.createExpense(
      weddingPlanId: planId,
      title: 'ورد',
      amount: '25',
      budgetCategoryId: 'remote-category',
    );
    final createdCommitment = await harness.api.createFinancialCommitment(
      weddingPlanId: planId,
      budgetCategoryId: 'remote-category',
      title: 'تصوير',
      totalAmount: '400',
    );
    final createdPayment = await harness.api.createFinancialPaymentRecord(
      commitmentId: cachedCommitment.id,
      amount: '50',
    );
    final createdInstallment = await harness.api.createFinancialInstallment(
      commitmentId: cachedCommitment.id,
      amount: '25',
      dueDate: DateTime(2026, 8, 1),
    );
    await harness.api.updateBudgetCategory(
      category: cachedCategory,
      name: 'القاعة المعدلة',
      targetAmount: '1100',
    );
    await harness.api.updateExpense(
      id: cachedExpense.id,
      weddingPlanId: planId,
      title: 'مصروف معدل',
      amount: '125',
      budgetCategoryId: 'remote-category',
    );
    await harness.api.updateFinancialCommitment(
      commitment: cachedCommitment,
      budgetCategoryId: 'remote-category',
      title: 'التزام معدل',
      totalAmount: '650',
      sourceType: 'MANUAL_COMMITMENT',
    );
    await harness.api.deleteBudgetCategory(cachedCategory.id);
    await harness.api.deleteExpense(cachedExpense.id);
    await harness.api.deleteFinancialCommitment(cachedCommitment.id);

    expect(createdCategory.id, startsWith('local-budget-category-'));
    expect(createdExpense.id, startsWith('local-expense-'));
    expect(createdCommitment.id, startsWith('local-financial-commitment-'));
    expect(createdPayment.id, startsWith('local-financial-payment-'));
    expect(createdInstallment.id, startsWith('local-financial-installment-'));

    final queued = await harness.database.pendingSyncItems();
    expect(queued, hasLength(11));
    _expectQueued(
      queued,
      entityType: 'budget_category',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/$planId/budget-categories',
      method: 'POST',
    );
    _expectQueued(
      queued,
      entityType: 'expense',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/$planId/expenses',
      method: 'POST',
    );
    _expectQueued(
      queued,
      entityType: 'financial_commitment',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/$planId/financial-commitments',
      method: 'POST',
    );
    _expectQueued(
      queued,
      entityType: 'financial_payment_record',
      operation: 'create',
      endpoint:
          '/api/v1/financial-commitments/${cachedCommitment.id}/payment-records',
      method: 'POST',
    );
    _expectQueued(
      queued,
      entityType: 'financial_installment',
      operation: 'create',
      endpoint:
          '/api/v1/financial-commitments/${cachedCommitment.id}/installments',
      method: 'POST',
    );
    _expectQueued(
      queued,
      entityType: 'budget_category',
      operation: 'update',
      endpoint: '/api/v1/budget-categories/${cachedCategory.id}',
      method: 'PATCH',
    );
    _expectQueued(
      queued,
      entityType: 'expense',
      operation: 'update',
      endpoint: '/api/v1/expenses/${cachedExpense.id}',
      method: 'PATCH',
    );
    _expectQueued(
      queued,
      entityType: 'financial_commitment',
      operation: 'update',
      endpoint: '/api/v1/financial-commitments/${cachedCommitment.id}',
      method: 'PATCH',
    );
    _expectQueued(
      queued,
      entityType: 'budget_category',
      operation: 'delete',
      endpoint: '/api/v1/budget-categories/${cachedCategory.id}',
      method: 'DELETE',
    );
    _expectQueued(
      queued,
      entityType: 'expense',
      operation: 'delete',
      endpoint: '/api/v1/expenses/${cachedExpense.id}',
      method: 'DELETE',
    );
    _expectQueued(
      queued,
      entityType: 'financial_commitment',
      operation: 'delete',
      endpoint: '/api/v1/financial-commitments/${cachedCommitment.id}',
      method: 'DELETE',
    );

    await expectLater(
      harness.api.reverseFinancialPaymentRecord('remote-payment'),
      throwsA(isA<ApiException>()),
    );
    expect(await harness.database.pendingSyncItems(), hasLength(11));
  });
}

Future<_Harness> _createHarness() async {
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final client = _NetworkFailureApiClient();
  final offline = OfflineSyncService(database: database, apiClient: client);
  await offline.refreshStatus();
  return _Harness(
    client: client,
    database: database,
    offline: offline,
    api: BudgetExpenseApi(client, offline: offline),
  );
}

Future<void> _seedRemoteFinance(
  JsonLocalDatabase database,
  String planId,
) async {
  const createdAt = '2026-07-01T00:00:00.000Z';
  await database.saveCachedItem(
    table: OfflineTables.cachedBudgetCategories,
    json: {
      'id': 'remote-category',
      'weddingPlanId': planId,
      'name': 'القاعة',
      'targetAmount': '1000',
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
  await database.saveCachedItem(
    table: OfflineTables.cachedBudgetItems,
    json: {
      'id': 'remote-expense',
      'weddingPlanId': planId,
      'budgetCategoryId': 'remote-category',
      'title': 'دفعة القاعة',
      'amount': '100',
      'status': 'PAID',
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
  await database.saveCachedItem(
    table: OfflineTables.cachedFinancialCommitments,
    json: {
      'id': 'remote-commitment',
      'weddingPlanId': planId,
      'budgetCategoryId': 'remote-category',
      'title': 'باقي القاعة',
      'totalAmount': '500',
      'paidAmount': '100',
      'remainingAmount': '400',
      'sourceType': 'MANUAL_COMMITMENT',
      'status': 'PARTIALLY_PAID',
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
  await database.saveCachedItem(
    table: OfflineTables.cachedFinancialPaymentRecords,
    json: {
      'id': 'remote-payment',
      'weddingPlanId': planId,
      'financialCommitmentId': 'remote-commitment',
      'budgetCategoryId': 'remote-category',
      'title': 'دفعة أولى',
      'amount': '100',
      'paidAt': createdAt,
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
  await database.saveCachedItem(
    table: OfflineTables.cachedFinancialInstallments,
    json: {
      'id': 'remote-installment-pending',
      'weddingPlanId': planId,
      'financialCommitmentId': 'remote-commitment',
      'budgetCategoryId': 'remote-category',
      'amount': '100',
      'status': 'PENDING',
      'dueDate': '2026-08-01T00:00:00.000Z',
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
  await database.saveCachedItem(
    table: OfflineTables.cachedFinancialInstallments,
    json: {
      'id': 'remote-installment-paid',
      'weddingPlanId': planId,
      'financialCommitmentId': 'remote-commitment',
      'budgetCategoryId': 'remote-category',
      'amount': '50',
      'status': 'PAID',
      'dueDate': '2026-07-01T00:00:00.000Z',
      'paidAt': createdAt,
      'createdAt': createdAt,
      'updatedAt': createdAt,
    },
  );
}

void _expectQueued(
  List<dynamic> queued, {
  required String entityType,
  required String operation,
  required String endpoint,
  required String method,
}) {
  expect(
    queued.where(
      (item) =>
          item.entityType == entityType &&
          item.operation == operation &&
          item.endpoint == endpoint &&
          item.method == method,
    ),
    hasLength(1),
    reason: '$method $endpoint must keep its $entityType/$operation contract',
  );
}

class _NetworkFailureApiClient extends ApiClient {
  _NetworkFailureApiClient() : super(tokenProvider: () async => null);

  static const message = 'network unavailable';
  static const failure = ApiException(message, isNetworkFailure: true);

  final List<String> getPaths = <String>[];
  final List<String> getListPaths = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    getPaths.add(path);
    throw failure;
  }

  @override
  Future<List<dynamic>> getJsonList(String path) async {
    getListPaths.add(path);
    throw failure;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    throw failure;
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    throw failure;
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    throw failure;
  }
}

class _Harness {
  const _Harness({
    required this.client,
    required this.database,
    required this.offline,
    required this.api,
  });

  final _NetworkFailureApiClient client;
  final JsonLocalDatabase database;
  final OfflineSyncService offline;
  final BudgetExpenseApi api;
}
