import '../../../core/offline/sync_status.dart';
import '../../debts/models/debt_summary.dart';
import '../../debts/models/installment.dart';
import '../../finance/models/expense_summary.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import 'wedding_plan.dart';

class PlanSummaryReadiness {
  const PlanSummaryReadiness({
    this.plan,
    this.expenseSummary,
    this.debtSummary,
    this.dueInstallments,
    this.tasks,
    this.sharedMembers,
    this.syncStatus,
    this.isLoading = false,
    this.errorMessage,
  });

  const factory PlanSummaryReadiness.empty() = PlanSummaryReadiness;

  factory PlanSummaryReadiness.fromSources({
    WeddingPlan? plan,
    ExpenseSummary? expenseSummary,
    DebtSummary? debtSummary,
    List<Installment>? dueInstallments,
    List<WeddingTask>? tasks,
    List<SharedMember>? sharedMembers,
    SyncStatusSnapshot? syncStatus,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return PlanSummaryReadiness(
      plan: plan,
      expenseSummary: expenseSummary,
      debtSummary: debtSummary,
      dueInstallments: dueInstallments,
      tasks: tasks,
      sharedMembers: sharedMembers,
      syncStatus: syncStatus,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  final WeddingPlan? plan;
  final ExpenseSummary? expenseSummary;
  final DebtSummary? debtSummary;
  final List<Installment>? dueInstallments;
  final List<WeddingTask>? tasks;
  final List<SharedMember>? sharedMembers;
  final SyncStatusSnapshot? syncStatus;
  final bool isLoading;
  final String? errorMessage;

  String? get currentPlanId {
    final id = plan?.id.trim();
    return id == null || id.isEmpty ? null : id;
  }

  bool get hasCurrentPlan => currentPlanId != null;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get isReadyForDashboardAdapter =>
      hasCurrentPlan && !isLoading && !hasError;

  String? get planTitle => plan?.title;

  String? get currency => plan?.currency;

  String? get estimatedBudget => plan?.estimatedBudget;

  DateTime? get weddingDate => plan?.weddingDate;

  int? get daysRemaining => plan?.daysRemaining;

  int? get taskCount => tasks?.length;

  int? get openTaskCount {
    final sourceTasks = tasks;
    if (sourceTasks == null) {
      return null;
    }
    return sourceTasks.where((task) => !task.isDone).length;
  }

  int? get dueInstallmentCount => dueInstallments?.length;

  int? get sharedMemberCount => sharedMembers?.length;

  SyncState? get syncState => syncStatus?.state;

  int? get pendingSyncCount => syncStatus?.pendingCount;
}
