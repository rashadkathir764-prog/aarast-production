import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';
import '../models/financial_commitment.dart';
import '../models/money_summary.dart';
import 'finance_money_rules.dart';

/// Owns finance persistence and aggregation that run entirely on the mobile
/// SQLite cache. Network requests and sync-queue orchestration stay in
/// [BudgetExpenseApi].
class FinanceLocalDataSource {
  const FinanceLocalDataSource(this._offline);

  final OfflineSyncService? _offline;

  static bool isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }

  static bool isDueFinancialInstallment(Map<String, dynamic> installment) {
    final status = installment['status']?.toString().toUpperCase() ?? '';
    return status != 'PAID' &&
        status != 'CANCELLED' &&
        installment['dueDate'] != null;
  }

  Future<void> markExpenseDeleted(String id, {required bool dirty}) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetItems,
      id: id,
    );
    if (cached == null) return;
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: cached,
      dirty: dirty,
      deletedLocally: true,
    );
  }

  ExpenseSummary expenseSummaryFrom(List<Map<String, dynamic>> expenses) {
    num totalPaid = 0;
    num totalPlanned = 0;
    num totalCancelled = 0;
    var countPaid = 0;
    var countPlanned = 0;
    var countCancelled = 0;
    for (final expense in expenses) {
      final amount = num.tryParse(expense['amount']?.toString() ?? '') ?? 0;
      switch (expense['status']?.toString()) {
        case 'PAID':
          totalPaid += amount;
          countPaid++;
        case 'CANCELLED':
          totalCancelled += amount;
          countCancelled++;
        default:
          totalPlanned += amount;
          countPlanned++;
      }
    }
    return ExpenseSummary(
      totalPaid: totalPaid.toStringAsFixed(2),
      totalPlanned: totalPlanned.toStringAsFixed(2),
      totalCancelled: totalCancelled.toStringAsFixed(2),
      countPaid: countPaid,
      countPlanned: countPlanned,
      countCancelled: countCancelled,
    );
  }

  Future<MoneySummary> moneySummary(
    String weddingPlanId, {
    String? estimatedBudget,
    String? currency,
  }) async {
    final categories =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedBudgetCategories,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final expenses =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedBudgetItems,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final commitments =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedFinancialCommitments,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];
    final financialInstallments =
        await _offline?.database.readCachedList(
          table: OfflineTables.cachedFinancialInstallments,
          parentColumn: 'planId',
          parentId: weddingPlanId,
        ) ??
        const <Map<String, dynamic>>[];

    final categoryTargetTotal = categories.fold<num>(
      0,
      (sum, category) =>
          sum + FinanceMoneyRules.value(category['targetAmount']),
    );
    final normalizedPlanBudget = estimatedBudget?.replaceAll(',', '').trim();
    final totalBudget = normalizedPlanBudget?.isNotEmpty == true
        ? FinanceMoneyRules.value(normalizedPlanBudget)
        : categoryTargetTotal;
    final totalSpent = expenses.fold<num>(0, (sum, expense) {
      if (expense['status']?.toString() != 'PAID') return sum;
      return sum + FinanceMoneyRules.value(expense['amount']);
    });
    final activeCommitments = commitments
        .where((commitment) => commitment['status']?.toString() != 'CANCELLED')
        .toList();
    final commitmentTotal = activeCommitments.fold<num>(
      0,
      (sum, commitment) =>
          sum + FinanceMoneyRules.value(commitment['totalAmount']),
    );
    final commitmentPaid = activeCommitments.fold<num>(
      0,
      (sum, commitment) =>
          sum + FinanceMoneyRules.value(commitment['paidAmount']),
    );
    final commitmentRemaining = (commitmentTotal - commitmentPaid).clamp(
      0,
      commitmentTotal,
    );
    final confirmedCostTotal = totalSpent + commitmentTotal;
    final remainingBudget = totalBudget - confirmedCostTotal;
    final paidTotal = commitmentPaid + totalSpent;
    final outstandingTotal = commitmentRemaining;
    final deficitOrSurplus = totalBudget - confirmedCostTotal;
    final categorySummaries = categories.map((category) {
      final id = category['id']?.toString() ?? '';
      final allocated = FinanceMoneyRules.value(category['targetAmount']);
      final categoryExpenses = expenses.where(
        (expense) => expense['budgetCategoryId']?.toString() == id,
      );
      final categoryCommitments = activeCommitments.where(
        (commitment) => commitment['budgetCategoryId']?.toString() == id,
      );
      final spent = categoryExpenses.fold<num>(0, (sum, expense) {
        if (expense['status']?.toString() != 'PAID') return sum;
        return sum + FinanceMoneyRules.value(expense['amount']);
      });
      final commitmentCost = categoryCommitments.fold<num>(
        0,
        (sum, commitment) =>
            sum + FinanceMoneyRules.value(commitment['totalAmount']),
      );
      final confirmedCost = spent + commitmentCost;
      final commitmentPaidForCategory = categoryCommitments.fold<num>(
        0,
        (sum, commitment) =>
            sum + FinanceMoneyRules.value(commitment['paidAmount']),
      );
      final categoryInstallments = financialInstallments.where(
        (installment) => installment['budgetCategoryId']?.toString() == id,
      );
      final paid = spent + commitmentPaidForCategory;
      final outstanding = (commitmentCost - commitmentPaidForCategory).clamp(
        0,
        commitmentCost,
      );
      final budgetRemaining = allocated - confirmedCost;
      return MoneyCategorySummary(
        categoryId: id,
        name: category['name']?.toString() ?? '',
        allocated: FinanceMoneyRules.asMoney(allocated),
        spent: FinanceMoneyRules.asMoney(spent),
        confirmedCost: FinanceMoneyRules.asMoney(confirmedCost),
        paid: FinanceMoneyRules.asMoney(paid),
        outstanding: FinanceMoneyRules.asMoney(outstanding),
        budgetRemaining: FinanceMoneyRules.asMoney(budgetRemaining),
        remaining: FinanceMoneyRules.asMoney(allocated - spent),
        expensesCount: categoryExpenses.length,
        commitmentsCount: categoryCommitments.length,
        installmentsCount: categoryInstallments.length,
        overBudget: allocated > 0 && confirmedCost > allocated,
      );
    }).toList();

    final now = DateTime.now();
    final unpaidFinancialInstallments =
        financialInstallments.where((installment) {
          final status = installment['status']?.toString();
          return status != 'PAID' && status != 'CANCELLED';
        }).toList()..sort((a, b) {
          final aDate = DateTime.tryParse(a['dueDate']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['dueDate']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
    final financialOverdueCount = unpaidFinancialInstallments.where((item) {
      final dueDate = DateTime.tryParse(item['dueDate']?.toString() ?? '');
      return dueDate != null &&
          dueDate.isBefore(DateTime(now.year, now.month, now.day));
    }).length;
    final financialDueSoonCount = unpaidFinancialInstallments.where((item) {
      final dueDate = DateTime.tryParse(item['dueDate']?.toString() ?? '');
      if (dueDate == null) return false;
      final days = dueDate.difference(now).inDays;
      return days >= 0 && days <= 7;
    }).length;
    final warnings = <MoneyFinancialWarning>[
      if (deficitOrSurplus < 0)
        MoneyFinancialWarning(
          type: 'BUDGET_EXCEEDED',
          severity: 'DANGER',
          message: 'ميزانيتك تجاوزت الحد',
          amount: FinanceMoneyRules.asMoney(deficitOrSurplus.abs()),
        ),
      if (categorySummaries.any((category) => category.overBudget == true))
        MoneyFinancialWarning(
          type: 'CATEGORY_EXCEEDED',
          severity: 'WARNING',
          message: 'تصنيف في الميزانية تجاوز المخصص',
          count: categorySummaries
              .where((category) => category.overBudget == true)
              .length,
        ),
      if (financialOverdueCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_OVERDUE',
          severity: 'DANGER',
          message: 'قسط متأخر يحتاج متابعة',
          count: financialOverdueCount,
        ),
      if (financialDueSoonCount > 0)
        MoneyFinancialWarning(
          type: 'INSTALLMENT_DUE_SOON',
          severity: 'WARNING',
          message: 'قسط قريب يحتاج متابعة',
          count: financialDueSoonCount,
        ),
    ];

    return MoneySummary(
      weddingPlanId: weddingPlanId,
      currency: currency?.trim().isNotEmpty == true
          ? currency!.trim().toUpperCase()
          : 'YER',
      totalBudget: FinanceMoneyRules.asMoney(totalBudget),
      totalSpent: FinanceMoneyRules.asMoney(totalSpent),
      remainingBudget: FinanceMoneyRules.asMoney(remainingBudget),
      confirmedCostTotal: FinanceMoneyRules.asMoney(confirmedCostTotal),
      paidTotal: FinanceMoneyRules.asMoney(paidTotal),
      outstandingTotal: FinanceMoneyRules.asMoney(outstandingTotal),
      commitmentTotal: FinanceMoneyRules.asMoney(commitmentTotal),
      commitmentPaidTotal: FinanceMoneyRules.asMoney(commitmentPaid),
      commitmentRemainingTotal: FinanceMoneyRules.asMoney(commitmentRemaining),
      deficitOrSurplus: FinanceMoneyRules.asMoney(deficitOrSurplus),
      paidInstallmentsCount: financialInstallments
          .where((installment) => installment['status']?.toString() == 'PAID')
          .length,
      remainingInstallmentsCount: unpaidFinancialInstallments.length,
      overdueInstallmentsCount: financialOverdueCount,
      dueInstallmentsCount: financialDueSoonCount,
      nextInstallment: unpaidFinancialInstallments.isEmpty
          ? null
          : MoneyNextInstallment.fromJson(unpaidFinancialInstallments.first),
      categorySummaries: categorySummaries,
      financialWarnings: warnings,
      categoriesCount: categories.length,
      expensesCount: expenses.length,
      commitmentsCount: activeCommitments.length,
      installmentsCount: financialInstallments.length,
    );
  }

  Future<Expense> createExpense({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localJson = {
      'id': 'local-expense-${now.microsecondsSinceEpoch}',
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Expense.fromJson(localJson);
  }

  Future<BudgetCategory> createBudgetCategory({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localJson = {
      'id': 'local-budget-category-${now.microsecondsSinceEpoch}',
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return BudgetCategory.fromJson(localJson);
  }

  Future<BudgetCategory> updateBudgetCategory({
    required BudgetCategory category,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      id: category.id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...payload,
      'id': category.id,
      'weddingPlanId': cached?['weddingPlanId'] ?? category.weddingPlanId,
      'createdAt': cached?['createdAt'] ?? category.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return BudgetCategory.fromJson(localJson);
  }

  Future<Expense> updateExpense({
    required String id,
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedBudgetItems,
      id: id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...payload,
      'id': id,
      'weddingPlanId': cached?['weddingPlanId'] ?? weddingPlanId,
      'createdAt': cached?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Expense.fromJson(localJson);
  }

  Future<FinancialCommitment> createFinancialCommitment({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final total = FinanceMoneyRules.assertPositive(
      payload['totalAmount'],
      'totalAmount',
    );
    final paid = FinanceMoneyRules.assertOptionalNonNegative(
      payload['paidAmount'],
      'paidAmount',
    );
    if (paid > total) {
      throw const ApiException(
        'المدفوع لا يمكن أن يتجاوز التكلفة المتفق عليها.',
      );
    }
    final remaining = (total - paid).clamp(0, total);
    final localJson = {
      ...payload,
      'id': 'local-financial-commitment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': weddingPlanId,
      'paidAmount': paid.toStringAsFixed(2),
      'remainingAmount': remaining.toStringAsFixed(2),
      'status': FinanceMoneyRules.commitmentStatus(total, paid),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      json: localJson,
      dirty: true,
    );
    if (paid > 0) {
      await createFinancialPaymentRecord(
        commitmentId: localJson['id']!.toString(),
        payload: {
          'title': 'دفعة أولى: ${payload['title'] ?? ''}',
          'amount': paid.toStringAsFixed(2),
          'paidAt': payload['agreementDate'] ?? now.toIso8601String(),
        },
        updateCommitmentBalance: false,
      );
    }
    await _offline?.refreshStatus();
    return FinancialCommitment.fromJson(localJson);
  }

  Future<FinancialPaymentRecord> createFinancialPaymentRecord({
    required String commitmentId,
    required Map<String, dynamic> payload,
    bool updateCommitmentBalance = true,
  }) async {
    final commitment = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      id: commitmentId,
    );
    if (commitment == null) {
      throw const ApiException('تعذر العثور على المستحق المالي.');
    }
    final now = DateTime.now();
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'amount',
    );
    if (updateCommitmentBalance) {
      FinanceMoneyRules.assertPaymentWithinRemaining(
        commitment: commitment,
        amount: amount,
      );
    }
    final localJson = {
      'id': 'local-financial-payment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': commitment['weddingPlanId'],
      'financialCommitmentId': commitmentId,
      'budgetCategoryId': commitment['budgetCategoryId'],
      'title': payload['title'] ?? 'دفعة: ${commitment['title'] ?? ''}',
      'amount': amount.toStringAsFixed(2),
      'paidAt': payload['paidAt'] ?? now.toIso8601String(),
      if (payload['method'] != null) 'method': payload['method'],
      if (payload['note'] != null) 'note': payload['note'],
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialPaymentRecords,
      json: localJson,
      dirty: true,
    );
    if (updateCommitmentBalance) {
      final total = FinanceMoneyRules.value(commitment['totalAmount']);
      final paid = FinanceMoneyRules.value(commitment['paidAmount']) + amount;
      final remaining = (total - paid).clamp(0, total);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedFinancialCommitments,
        json: {
          ...commitment,
          'paidAmount': paid.toStringAsFixed(2),
          'remainingAmount': remaining.toStringAsFixed(2),
          'status': FinanceMoneyRules.commitmentStatus(total, paid),
          'updatedAt': now.toIso8601String(),
        },
        dirty: true,
      );
    }
    await _offline?.refreshStatus();
    return FinancialPaymentRecord.fromJson(localJson);
  }

  Future<FinancialCommitment> updateFinancialCommitment({
    required FinancialCommitment commitment,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      id: commitment.id,
    );
    final now = DateTime.now();
    final total = FinanceMoneyRules.assertPositive(
      payload['totalAmount'],
      'totalAmount',
    );
    final paid = FinanceMoneyRules.value(
      cached?['paidAmount'] ?? commitment.paidAmount,
    );
    if (paid > total) {
      throw const ApiException(
        'المدفوع لا يمكن أن يتجاوز التكلفة المتفق عليها.',
      );
    }
    final remaining = (total - paid).clamp(0, total);
    final localJson = {
      ...?cached,
      ...payload,
      'id': commitment.id,
      'weddingPlanId': cached?['weddingPlanId'] ?? commitment.weddingPlanId,
      'paidAmount': paid.toStringAsFixed(2),
      'remainingAmount': remaining.toStringAsFixed(2),
      'status': FinanceMoneyRules.commitmentStatus(total, paid),
      'createdAt':
          cached?['createdAt'] ?? commitment.createdAt?.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return FinancialCommitment.fromJson(localJson);
  }

  Future<FinancialInstallment> createFinancialInstallment({
    required String commitmentId,
    required Map<String, dynamic> payload,
  }) async {
    final commitment = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedFinancialCommitments,
      id: commitmentId,
    );
    if (commitment == null) {
      throw const ApiException('تعذر العثور على المستحق المالي.');
    }
    final now = DateTime.now();
    final status = payload['status']?.toString() ?? 'PENDING';
    final localJson = {
      'id': 'local-financial-installment-${now.microsecondsSinceEpoch}',
      'weddingPlanId': commitment['weddingPlanId'],
      'financialCommitmentId': commitmentId,
      'budgetCategoryId': commitment['budgetCategoryId'],
      ...payload,
      'status': status,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedFinancialInstallments,
      json: localJson,
      dirty: true,
    );
    if (status == 'PAID') {
      await createFinancialPaymentRecord(
        commitmentId: commitmentId,
        payload: {
          'title': 'قسط: ${commitment['title'] ?? ''}',
          'amount': payload['amount'],
          'paidAt': payload['paidAt'] ?? now.toIso8601String(),
          if (payload['note'] != null) 'note': payload['note'],
        },
      );
    }
    await _offline?.refreshStatus();
    return FinancialInstallment.fromJson(localJson);
  }
}
