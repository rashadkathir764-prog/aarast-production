import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../data/budget_expense_api.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._api);

  final BudgetExpenseApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<BudgetCategory> _budgetCategories = const [];
  List<Expense> _expenses = const [];
  ExpenseSummary _summary = ExpenseSummary.empty();

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<BudgetCategory> get budgetCategories => _budgetCategories;
  List<Expense> get expenses => _expenses;
  ExpenseSummary get summary => _summary;

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
      ]);
      _budgetCategories = results[0] as List<BudgetCategory>;
      _expenses = results[1] as List<Expense>;
      _summary = results[2] as ExpenseSummary;
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
      if (category.id.startsWith('local-')) {
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

  Future<bool> createExpense({
    required String weddingPlanId,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PLANNED',
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

  Future<bool> updateExpense({
    required String weddingPlanId,
    required Expense expense,
    required String title,
    required String amount,
    String? budgetCategoryId,
    String status = 'PLANNED',
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
