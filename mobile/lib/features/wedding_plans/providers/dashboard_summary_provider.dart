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
import '../models/dashboard_summary.dart';
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
  DashboardSummary? _summary;
  WeddingPlan? _plan;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardSummary? get summary => _summary;
  WeddingPlan? get plan => _plan;

  // Compatibility getters for older plan-center widgets. The visible Phase 1
  // dashboard reads [summary] from the backend aggregate endpoint.
  ExpenseSummary? get expenseSummary => null;
  DebtSummary? get debtSummary => null;
  List<Installment>? get dueInstallments => null;
  List<WeddingTask>? get tasks => null;
  List<SharedMember>? get sharedMembers => null;

  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextSummary = await weddingPlansApi.getDashboardSummary(
        weddingPlanId,
      );
      _summary = nextSummary;
      _plan = nextSummary.toWeddingPlan();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات اللوحة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
