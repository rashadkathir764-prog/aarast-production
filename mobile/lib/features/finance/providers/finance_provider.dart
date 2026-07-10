import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/budget_expense_api.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';
import '../models/financial_commitment.dart';
import '../models/money_summary.dart';

class FinanceProvider extends ChangeNotifier with SessionScopedNotifier {
  FinanceProvider(this._api);

  final BudgetExpenseApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<BudgetCategory> _budgetCategories = const [];
  List<Expense> _expenses = const [];
  List<FinancialCommitment> _financialCommitments = const [];
  List<FinancialPaymentRecord> _financialPaymentRecords = const [];
  List<FinancialInstallment> _dueFinancialInstallments = const [];
  ExpenseSummary _summary = ExpenseSummary.empty();
  MoneySummary _moneySummary = MoneySummary.empty('');

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<BudgetCategory> get budgetCategories => _budgetCategories;
  List<Expense> get expenses => _expenses;
  List<FinancialCommitment> get financialCommitments => _financialCommitments;
  List<FinancialPaymentRecord> get financialPaymentRecords =>
      _financialPaymentRecords;
  List<FinancialInstallment> get dueFinancialInstallments =>
      _dueFinancialInstallments;
  ExpenseSummary get summary => _summary;
  MoneySummary get moneySummary => _moneySummary;

  Future<void> loadFinance(
    String weddingPlanId, {
    bool canReadBudget = true,
    bool canReadExpenses = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object?>([
        canReadBudget
            ? _api.getBudgetCategories(weddingPlanId)
            : Future<List<BudgetCategory>>.value(const []),
        canReadExpenses
            ? _api.getExpenses(weddingPlanId)
            : Future<List<Expense>>.value(const []),
        canReadExpenses
            ? _api.getExpenseSummary(weddingPlanId)
            : Future<ExpenseSummary>.value(ExpenseSummary.empty()),
        _api.getMoneySummary(weddingPlanId),
        _api.getFinancialCommitments(weddingPlanId),
        canReadExpenses
            ? _api.getFinancialPaymentRecords(weddingPlanId)
            : Future<List<FinancialPaymentRecord>>.value(const []),
        _api.getDueFinancialInstallments(weddingPlanId),
      ]);
      _budgetCategories = results[0] as List<BudgetCategory>;
      _expenses = results[1] as List<Expense>;
      _summary = results[2] as ExpenseSummary;
      _moneySummary = results[3] as MoneySummary;
      _financialCommitments = results[4] as List<FinancialCommitment>;
      _financialPaymentRecords = results[5] as List<FinancialPaymentRecord>;
      _dueFinancialInstallments = results[6] as List<FinancialInstallment>;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل الميزانية والمصاريف.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createBudgetCategory({
    required String weddingPlanId,
    required String name,
    String? targetAmount,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final category = await _api.createBudgetCategory(
        weddingPlanId: weddingPlanId,
        name: name,
        targetAmount: targetAmount,
      );
      _budgetCategories = [category, ..._budgetCategories];
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (category.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء تصنيف الميزانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createBudgetCategoryBatch({
    required String weddingPlanId,
    required List<({String name, String? targetAmount})> categories,
  }) async {
    final cleanCategories = categories
        .map(
          (category) => (
            name: category.name.trim(),
            targetAmount: category.targetAmount?.trim(),
          ),
        )
        .where((category) => category.name.isNotEmpty)
        .toList();
    if (cleanCategories.isEmpty) {
      _errorMessage = 'اختر بنداً واحداً على الأقل لإعداد الميزانية.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final existingNames = _budgetCategories
          .map((category) => category.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet();
      final created = <BudgetCategory>[];

      for (final category in cleanCategories) {
        if (existingNames.contains(category.name)) continue;
        final createdCategory = await _api.createBudgetCategory(
          weddingPlanId: weddingPlanId,
          name: category.name,
          targetAmount: category.targetAmount?.isEmpty == true
              ? null
              : category.targetAmount,
        );
        existingNames.add(createdCategory.name.trim());
        created.add(createdCategory);
      }

      if (created.isEmpty) {
        _errorMessage = 'كل البنود المختارة موجودة مسبقاً.';
        return false;
      }

      _budgetCategories = [...created, ..._budgetCategories];
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (created.any((category) => category.id.startsWith('local-'))) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      } else {
        _noticeMessage = 'تم إعداد ${created.length} بند في الميزانية.';
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إعداد بنود الميزانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createExpense({
    required String weddingPlanId,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PAID',
    DateTime? expenseDate,
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final expense = await _api.createExpense(
        weddingPlanId: weddingPlanId,
        title: title,
        amount: amount,
        budgetCategoryId: budgetCategoryId,
        status: status,
        expenseDate: expenseDate,
        note: note,
      );
      _expenses = [expense, ..._expenses];
      _summary = _summaryFromExpenses(_expenses);
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (expense.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء المصروف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createFinancialCommitment({
    required String weddingPlanId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String sourceType = 'MANUAL_COMMITMENT',
    String? providerId,
    String? planProviderLinkId,
    String? quoteRequestId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? paidAmount,
    DateTime? dueDate,
    DateTime? agreementDate,
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final commitment = await _api.createFinancialCommitment(
        weddingPlanId: weddingPlanId,
        budgetCategoryId: budgetCategoryId,
        title: title,
        totalAmount: totalAmount,
        sourceType: sourceType,
        providerId: providerId,
        planProviderLinkId: planProviderLinkId,
        quoteRequestId: quoteRequestId,
        quoteOfferId: quoteOfferId,
        partyName: partyName,
        partyPhone: partyPhone,
        paidAmount: paidAmount,
        dueDate: dueDate,
        agreementDate: agreementDate,
        note: note,
      );
      _financialCommitments = [
        commitment,
        ..._financialCommitments.where((item) => item.id != commitment.id),
      ];
      await _refreshFinancialState(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (commitment.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء المستحق المالي.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createFinancialPaymentRecord({
    required String weddingPlanId,
    required String commitmentId,
    required String amount,
    String? title,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final payment = await _api.createFinancialPaymentRecord(
        commitmentId: commitmentId,
        amount: amount,
        title: title,
        paidAt: paidAt,
        method: method,
        note: note,
      );
      _financialPaymentRecords = [
        payment,
        ..._financialPaymentRecords.where((item) => item.id != payment.id),
      ];
      await _refreshFinancialState(weddingPlanId);
      if (payment.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تسجيل الدفعة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateFinancialCommitment({
    required String weddingPlanId,
    required FinancialCommitment commitment,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    required String sourceType,
    String? partyName,
    String? partyPhone,
    DateTime? dueDate,
    DateTime? agreementDate,
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateFinancialCommitment(
        commitment: commitment,
        budgetCategoryId: budgetCategoryId,
        title: title,
        totalAmount: totalAmount,
        sourceType: sourceType,
        partyName: partyName,
        partyPhone: partyPhone,
        dueDate: dueDate,
        agreementDate: agreementDate,
        note: note,
      );
      _financialCommitments = [
        for (final item in _financialCommitments)
          item.id == updated.id ? updated : item,
      ];
      await _refreshFinancialState(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId) ||
          updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث المستحق المالي.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFinancialCommitment({
    required String weddingPlanId,
    required FinancialCommitment commitment,
  }) async {
    if (commitment.id.startsWith('local-')) {
      _errorMessage =
          'لا يمكن حذف مستحق قيد المزامنة قبل عودة الاتصال واكتمال الحفظ.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.deleteFinancialCommitment(commitment.id);
      _financialCommitments = _financialCommitments
          .where((item) => item.id != commitment.id)
          .toList();
      await _refreshFinancialState(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف المستحق المالي.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> reverseFinancialPaymentRecord({
    required String weddingPlanId,
    required FinancialPaymentRecord payment,
  }) async {
    if (payment.id.startsWith('local-')) {
      _errorMessage =
          'لا يمكن عكس دفعة قيد المزامنة قبل عودة الاتصال واكتمال الحفظ.';
      notifyListeners();
      return false;
    }
    if (!payment.reversible) {
      _errorMessage = payment.isReversal
          ? 'قيد العكس لا يمكن عكسه مرة أخرى.'
          : payment.isReversed
          ? 'تم عكس هذه الدفعة سابقًا.'
          : 'هذا القيد يُدار من المستحق أو القسط الأصلي.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.reverseFinancialPaymentRecord(payment.id);
      await _refreshFinancialState(weddingPlanId);
      _noticeMessage = 'تم تسجيل قيد عكس مع الاحتفاظ بالدفعة الأصلية.';
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر عكس سجل الدفعة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateBudgetCategory({
    required String weddingPlanId,
    required BudgetCategory category,
    required String name,
    String? targetAmount,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateBudgetCategory(
        category: category,
        name: name,
        targetAmount: targetAmount,
      );
      _budgetCategories = [
        for (final item in _budgetCategories)
          item.id == updated.id ? updated : item,
      ];
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث بند الميزانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBudgetCategory({
    required String weddingPlanId,
    required BudgetCategory category,
  }) async {
    if (category.id.startsWith('local-')) {
      _errorMessage =
          'لا يمكن حذف بند قيد المزامنة قبل عودة الاتصال واكتمال الحفظ.';
      notifyListeners();
      return false;
    }

    final hasExpenses = _expenses.any(
      (expense) => expense.budgetCategoryId == category.id,
    );
    if (hasExpenses) {
      _errorMessage = 'لا يمكن حذف بند مرتبط بمصاريف. انقل المصاريف أولاً.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.deleteBudgetCategory(category.id);
      _budgetCategories = _budgetCategories
          .where((item) => item.id != category.id)
          .toList();
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف بند الميزانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateExpense({
    required String weddingPlanId,
    required Expense expense,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PAID',
    DateTime? expenseDate,
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateExpense(
        id: expense.id,
        weddingPlanId: weddingPlanId,
        title: title,
        amount: amount,
        budgetCategoryId: budgetCategoryId,
        status: status,
        expenseDate: expenseDate,
        note: note,
      );
      _replaceExpense(updated);
      _summary = _summaryFromExpenses(_expenses);
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث المصروف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExpense({
    required String weddingPlanId,
    required Expense expense,
  }) async {
    if (expense.id.startsWith('local-')) {
      _errorMessage =
          'لا يمكن حذف مصروف قيد المزامنة قبل عودة الاتصال واكتمال الحفظ.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.deleteExpense(expense.id);
      _expenses = _expenses.where((item) => item.id != expense.id).toList();
      _summary = _summaryFromExpenses(_expenses);
      _moneySummary = await _api.getMoneySummary(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف المصروف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _refreshFinancialState(String weddingPlanId) async {
    final results = await Future.wait<Object>([
      _api.getMoneySummary(weddingPlanId),
      _api.getFinancialCommitments(weddingPlanId),
      _api.getFinancialPaymentRecords(weddingPlanId),
      _api.getDueFinancialInstallments(weddingPlanId),
    ]);
    _moneySummary = results[0] as MoneySummary;
    _financialCommitments = results[1] as List<FinancialCommitment>;
    _financialPaymentRecords = results[2] as List<FinancialPaymentRecord>;
    _dueFinancialInstallments = results[3] as List<FinancialInstallment>;
  }

  void clearError() {
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  void _replaceExpense(Expense updated) {
    _expenses = [
      for (final item in _expenses) item.id == updated.id ? updated : item,
    ];
  }

  ExpenseSummary _summaryFromExpenses(List<Expense> expenses) {
    num totalPaid = 0;
    num totalPlanned = 0;
    num totalCancelled = 0;
    var countPaid = 0;
    var countPlanned = 0;
    var countCancelled = 0;

    for (final expense in expenses) {
      final amount = num.tryParse(expense.amount) ?? 0;
      switch (expense.status) {
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
}

bool _isLocalGuestPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}
