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

  Future<void> loadFinance(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _api.getBudgetCategories(weddingPlanId),
        _api.getExpenses(weddingPlanId),
        _api.getExpenseSummary(weddingPlanId),
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
      if (expense.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
        _summary = _localSummaryWith(expense);
      } else {
        _summary = await _api.getExpenseSummary(weddingPlanId);
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

  void clearError() {
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  ExpenseSummary _localSummaryWith(Expense expense) {
    final amount = num.tryParse(expense.amount) ?? 0;
    switch (expense.status) {
      case 'PAID':
        return ExpenseSummary(
          totalPaid: _sum(_summary.totalPaid, amount),
          totalPlanned: _summary.totalPlanned,
          totalCancelled: _summary.totalCancelled,
          countPaid: _summary.countPaid + 1,
          countPlanned: _summary.countPlanned,
          countCancelled: _summary.countCancelled,
        );
      case 'CANCELLED':
        return ExpenseSummary(
          totalPaid: _summary.totalPaid,
          totalPlanned: _summary.totalPlanned,
          totalCancelled: _sum(_summary.totalCancelled, amount),
          countPaid: _summary.countPaid,
          countPlanned: _summary.countPlanned,
          countCancelled: _summary.countCancelled + 1,
        );
      default:
        return ExpenseSummary(
          totalPaid: _summary.totalPaid,
          totalPlanned: _sum(_summary.totalPlanned, amount),
          totalCancelled: _summary.totalCancelled,
          countPaid: _summary.countPaid,
          countPlanned: _summary.countPlanned + 1,
          countCancelled: _summary.countCancelled,
        );
    }
  }

  String _sum(String current, num amount) {
    final value = (num.tryParse(current) ?? 0) + amount;
    return value.toStringAsFixed(2);
  }
}
