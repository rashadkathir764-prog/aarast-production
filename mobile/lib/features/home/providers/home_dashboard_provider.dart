import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../debts/data/debt_installment_api.dart';
import '../../debts/models/debt_summary.dart';
import '../../debts/models/installment.dart';
import '../../finance/data/budget_expense_api.dart';
import '../../finance/models/expense_summary.dart';
import '../../sharing/data/sharing_api.dart';
import '../../sharing/models/shared_member.dart';
import '../../sharing/models/shared_wedding_plan.dart';
import '../../tasks/data/task_timeline_api.dart';
import '../../tasks/models/wedding_task.dart';
import '../../wedding_plans/data/wedding_plans_api.dart';
import '../../wedding_plans/models/wedding_plan.dart';

class HomeDashboardProvider extends ChangeNotifier with SessionScopedNotifier {
  HomeDashboardProvider({
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

  List<WeddingPlan> _myPlans = [];
  List<SharedWeddingPlan> _sharedPlans = [];

  WeddingPlan? _primaryPlan;
  ExpenseSummary? _expenseSummary;
  DebtSummary? _debtSummary;
  List<Installment>? _dueInstallments;
  List<WeddingTask>? _tasks;
  List<SharedMember>? _sharedMembers;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<WeddingPlan> get myPlans => _myPlans;
  List<SharedWeddingPlan> get sharedPlans => _sharedPlans;

  WeddingPlan? get primaryPlan => _primaryPlan;
  ExpenseSummary? get expenseSummary => _expenseSummary;
  DebtSummary? get debtSummary => _debtSummary;
  List<Installment>? get dueInstallments => _dueInstallments;
  List<WeddingTask>? get tasks => _tasks;
  List<SharedMember>? get sharedMembers => _sharedMembers;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch plans
      final plansResult = await Future.wait([
        weddingPlansApi.getMyWeddingPlans(),
        sharingApi.getSharedWeddingPlans(),
      ]);

      _myPlans = plansResult[0] as List<WeddingPlan>;
      _sharedPlans = plansResult[1] as List<SharedWeddingPlan>;

      // 2. Identify primary plan
      if (_myPlans.isNotEmpty) {
        // We'll use the first one or we could find the latest
        _primaryPlan = _myPlans.first;
        final planId = _primaryPlan!.id;

        // 3. Concurrently fetch data for primary plan
        final results = await Future.wait([
          _fetchExpenseSummary(planId),
          _fetchDebtSummary(planId),
          _fetchDueInstallments(planId),
          _fetchTasks(planId),
          _fetchSharedMembers(planId),
        ]);

        _expenseSummary = results[0] as ExpenseSummary?;
        _debtSummary = results[1] as DebtSummary?;
        _dueInstallments = results[2] as List<Installment>?;
        _tasks = results[3] as List<WeddingTask>?;
        _sharedMembers = results[4] as List<SharedMember>?;
      } else {
        _primaryPlan = null;
        _expenseSummary = null;
        _debtSummary = null;
        _dueInstallments = null;
        _tasks = null;
        _sharedMembers = null;
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل لوحة التحكم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExpenseSummary?> _fetchExpenseSummary(String planId) async {
    try {
      return await budgetExpenseApi.getExpenseSummary(planId);
    } catch (_) {
      return null;
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
