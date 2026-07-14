class PlanAccessPermissions {
  const PlanAccessPermissions({
    required this.weddingPlanId,
    required this.isOwner,
    required this.canViewMoney,
    required this.canManageMoney,
  });

  const PlanAccessPermissions.owner({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: true,
        canViewMoney: true,
        canManageMoney: true,
      );

  const PlanAccessPermissions.denied({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: false,
        canViewMoney: false,
        canManageMoney: false,
      );

  factory PlanAccessPermissions.fromJson(Map<String, dynamic> json) {
    final canManage = json['canManageMoney'] == true;
    return PlanAccessPermissions(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      isOwner: json['isOwner'] == true,
      canViewMoney: json['canViewMoney'] == true || canManage,
      canManageMoney: canManage,
    );
  }

  final String weddingPlanId;
  final bool isOwner;
  final bool canViewMoney;
  final bool canManageMoney;

  bool get hasAnyFinanceAccess => canViewMoney;
}
