class PlanAccessPermissions {
  const PlanAccessPermissions({
    required this.weddingPlanId,
    required this.isOwner,
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewFinancialRecords,
    required this.canManageFinancialRecords,
  });

  const PlanAccessPermissions.owner({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: true,
        canViewBudget: true,
        canViewExpenses: true,
        canViewFinancialRecords: true,
        canManageFinancialRecords: true,
      );

  const PlanAccessPermissions.denied({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: false,
        canViewBudget: false,
        canViewExpenses: false,
        canViewFinancialRecords: false,
        canManageFinancialRecords: false,
      );

  factory PlanAccessPermissions.fromJson(Map<String, dynamic> json) {
    return PlanAccessPermissions(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      isOwner: json['isOwner'] == true,
      canViewBudget: json['canViewBudget'] == true,
      canViewExpenses: json['canViewExpenses'] == true,
      canViewFinancialRecords: json['canViewFinancialRecords'] == true,
      canManageFinancialRecords: json['canManageFinancialRecords'] == true,
    );
  }

  final String weddingPlanId;
  final bool isOwner;
  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewFinancialRecords;
  final bool canManageFinancialRecords;

  bool get canReadBudget => canViewBudget || canManageFinancialRecords;
  bool get canReadExpenses => canViewExpenses || canManageFinancialRecords;
  bool get canReadFinancialRecords =>
      canViewFinancialRecords || canManageFinancialRecords;
  bool get hasAnyFinanceAccess =>
      canReadBudget || canReadExpenses || canReadFinancialRecords;
}
