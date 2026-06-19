import '../../wedding_plans/models/plan_summary_readiness.dart';

enum MoneyFlowReadinessState {
  missingCurrentPlan,
  missingPermission,
  waitingForSources,
  ready,
  offlinePendingSync,
  loading,
  blockedByError,
}

class MoneyFlowReadiness {
  const MoneyFlowReadiness({
    this.currentPlanId,
    this.estimatedBudgetLabel,
    this.totalPaidLabel,
    this.totalPlannedLabel,
    this.remainingDebtLabel,
    this.totalDebtLabel,
    this.dueInstallmentCount,
    this.pendingSyncCount,
    this.canReadBudget = false,
    this.canReadExpenses = false,
    this.canReadDebts = false,
    this.canManageFinancialRecords = false,
    this.isLoading = false,
    this.errorMessage,
  });

  const factory MoneyFlowReadiness.empty() = MoneyFlowReadiness;

  factory MoneyFlowReadiness.fromPlanSummary(
    PlanSummaryReadiness summary, {
    bool canReadBudget = false,
    bool canReadExpenses = false,
    bool canReadDebts = false,
    bool canManageFinancialRecords = false,
  }) {
    return MoneyFlowReadiness(
      currentPlanId: summary.currentPlanId,
      estimatedBudgetLabel: _budgetLabel(
        summary.estimatedBudget,
        summary.currency,
      ),
      totalPaidLabel: summary.expenseSummary?.totalPaid,
      totalPlannedLabel: summary.expenseSummary?.totalPlanned,
      remainingDebtLabel: summary.debtSummary?.remainingDebt,
      totalDebtLabel: summary.debtSummary?.totalDebt,
      dueInstallmentCount: summary.dueInstallmentCount,
      pendingSyncCount: summary.pendingSyncCount,
      canReadBudget: canReadBudget,
      canReadExpenses: canReadExpenses,
      canReadDebts: canReadDebts,
      canManageFinancialRecords: canManageFinancialRecords,
      isLoading: summary.isLoading,
      errorMessage: summary.errorMessage,
    );
  }

  final String? currentPlanId;
  final String? estimatedBudgetLabel;
  final String? totalPaidLabel;
  final String? totalPlannedLabel;
  final String? remainingDebtLabel;
  final String? totalDebtLabel;
  final int? dueInstallmentCount;
  final int? pendingSyncCount;
  final bool canReadBudget;
  final bool canReadExpenses;
  final bool canReadDebts;
  final bool canManageFinancialRecords;
  final bool isLoading;
  final String? errorMessage;

  bool get hasCurrentPlan =>
      currentPlanId != null && currentPlanId!.trim().isNotEmpty;

  bool get hasFinancialAccess =>
      canReadBudget ||
      canReadExpenses ||
      canReadDebts ||
      canManageFinancialRecords;

  bool get hasAnyFinanceSource {
    return _hasValue(estimatedBudgetLabel) ||
        _hasValue(totalPaidLabel) ||
        _hasValue(totalPlannedLabel) ||
        _hasValue(remainingDebtLabel) ||
        _hasValue(totalDebtLabel) ||
        dueInstallmentCount != null;
  }

  bool get hasPendingSync => (pendingSyncCount ?? 0) > 0;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  MoneyFlowReadinessState get state {
    if (isLoading) {
      return MoneyFlowReadinessState.loading;
    }
    if (hasError) {
      return MoneyFlowReadinessState.blockedByError;
    }
    if (!hasCurrentPlan) {
      return MoneyFlowReadinessState.missingCurrentPlan;
    }
    if (!hasFinancialAccess) {
      return MoneyFlowReadinessState.missingPermission;
    }
    if (!hasAnyFinanceSource) {
      return MoneyFlowReadinessState.waitingForSources;
    }
    if (hasPendingSync) {
      return MoneyFlowReadinessState.offlinePendingSync;
    }
    return MoneyFlowReadinessState.ready;
  }
}

String? _budgetLabel(String? estimatedBudget, String? currency) {
  final budget = estimatedBudget?.trim();
  if (budget == null || budget.isEmpty) {
    return null;
  }

  final trimmedCurrency = currency?.trim();
  if (trimmedCurrency == null || trimmedCurrency.isEmpty) {
    return budget;
  }

  return '$budget $trimmedCurrency';
}

bool _hasValue(String? value) {
  return value != null && value.trim().isNotEmpty;
}
