import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../debts/data/debt_installment_api.dart';
import '../../debts/models/debt_summary.dart';
import '../../debts/models/installment.dart';
import '../../finance/data/budget_expense_api.dart';
import '../../finance/models/expense_summary.dart';
import '../../sharing/data/sharing_api.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/data/task_timeline_api.dart';
import '../../tasks/models/wedding_task.dart';
import '../data/wedding_plans_api.dart';
import '../models/wedding_plan.dart';

class DashboardSummaryProvider extends ChangeNotifier {
  DashboardSummaryProvider({
    required this.weddingPlansApi,
    required this.budgetExpenseApi,
    required this.debtInstallmentApi,
    required this.taskTimelineApi,
    required this.sharingApi,
  });

  final WeddingPlansApi weddingPlansApi;
  final BudgetExpenseApi budgetExpenseApi;
  final DebtInstallmentApi debtInstallmentApi;
  final TaskTimelineApi taskTimelineApi;
  final SharingApi sharingApi;

  bool _isLoading = false;
  String? _errorMessage;

  WeddingPlan? _plan;
  ExpenseSummary? _expenseSummary;
  DebtSummary? _debtSummary;
  List<Installment>? _dueInstallments;
  List<WeddingTask>? _tasks;
  List<SharedMember>? _sharedMembers;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WeddingPlan? get plan => _plan;
  ExpenseSummary? get expenseSummary => _expenseSummary;
  DebtSummary? get debtSummary => _debtSummary;
  List<Installment>? get dueInstallments => _dueInstallments;
  List<WeddingTask>? get tasks => _tasks;
  List<SharedMember>? get sharedMembers => _sharedMembers;

  Future<void> loadDashboard(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch plan first. If it fails, the whole dashboard fails.
      _plan = await weddingPlansApi.getWeddingPlan(weddingPlanId);
      
      // Fetch the rest concurrently to speed up loading
      final results = await Future.wait([
        _fetchExpenseSummary(weddingPlanId),
        _fetchDebtSummary(weddingPlanId),
        _fetchDueInstallments(weddingPlanId),
        _fetchTasks(weddingPlanId),
        _fetchSharedMembers(weddingPlanId),
      ]);

      _expenseSummary = results[0] as ExpenseSummary?;
      _debtSummary = results[1] as DebtSummary?;
      _dueInstallments = results[2] as List<Installment>?;
      _tasks = results[3] as List<WeddingTask>?;
      _sharedMembers = results[4] as List<SharedMember>?;

    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات اللوحة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExpenseSummary?> _fetchExpenseSummary(String planId) async {
    try {
      return await budgetExpenseApi.getExpenseSummary(planId);
    } catch (_) {
      return null; // Graceful degradation
    }
  }

  Future<DebtSummary?> _fetchDebtSummary(String planId) async {
    try {
      return await debtInstallmentApi.getDebtSummary(planId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Installment>?> _fetchDueInstallments(String planId) async {
    try {
      return await debtInstallmentApi.getDueInstallments(planId);
    } catch (_) {
      return null;
    }
  }

  Future<List<WeddingTask>?> _fetchTasks(String planId) async {
    try {
      return await taskTimelineApi.getTasks(planId);
    } catch (_) {
      return null;
    }
  }

  Future<List<SharedMember>?> _fetchSharedMembers(String planId) async {
    try {
      return await sharingApi.getSharedMembers(planId);
    } catch (_) {
      return null;
    }
  }
}
